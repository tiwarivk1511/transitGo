import 'dart:convert';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// SQLite-backed persistent cache for TransitGo.
///
/// Handles:
///   • API response caching (with TTL)
///   • User search history (per feature)
///   • Recently tracked trains
///   • Favourite / saved stations
class OfflineCache {
  static Database? _db;
  static const String _dbName = 'transitgo_v2.db';
  static const int _dbVersion = 2;

  // ───────────────────────────────────────────────────────────────────
  // SINGLETON
  // ───────────────────────────────────────────────────────────────────
  static Future<Database> get instance async {
    if (_db != null) return _db!;

    final path = join(await getDatabasesPath(), _dbName);
    _db = await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onConfigure: (db) async {
        // Enable foreign keys (future-proofing)
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
    return _db!;
  }

  // ───────────────────────────────────────────────────────────────────
  // SCHEMA
  // ───────────────────────────────────────────────────────────────────
  static Future<void> _onCreate(Database db, int version) async {
    // ── 1. Response cache ──────────────────────────────────────────
    await db.execute('''
      CREATE TABLE cache(
        key       TEXT PRIMARY KEY,
        json      TEXT NOT NULL,
        expires   INTEGER NOT NULL,
        created   INTEGER NOT NULL
      )
    ''');
    await db.execute(
        'CREATE INDEX idx_cache_expires ON cache(expires)');
    await db.execute(
        'CREATE INDEX idx_cache_created ON cache(created)');

    // ── 2. Search history ──────────────────────────────────────────
    // kind: 'station' | 'train' | 'pnr' | 'route' | 'fare'
    await db.execute('''
      CREATE TABLE search_history(
        id      INTEGER PRIMARY KEY AUTOINCREMENT,
        kind    TEXT NOT NULL,
        query   TEXT NOT NULL,
        label   TEXT,
        data    TEXT,
        created INTEGER NOT NULL
      )
    ''');
    await db.execute(
        'CREATE INDEX idx_history_kind ON search_history(kind, created DESC)');
    await db.execute(
        'CREATE INDEX idx_history_query ON search_history(kind, query)');

    // ── 3. Tracked trains ──────────────────────────────────────────
    await db.execute('''
      CREATE TABLE tracked_trains(
        train_number  TEXT PRIMARY KEY,
        train_name    TEXT NOT NULL,
        route_json    TEXT,
        last_seen     INTEGER NOT NULL,
        track_count   INTEGER NOT NULL DEFAULT 1
      )
    ''');
    await db.execute(
        'CREATE INDEX idx_tracked_last_seen ON tracked_trains(last_seen DESC)');

    // ── 4. Favourite stations ──────────────────────────────────────
    await db.execute('''
      CREATE TABLE favourite_stations(
        code      TEXT PRIMARY KEY,
        name      TEXT NOT NULL,
        city      TEXT,
        state     TEXT,
        added     INTEGER NOT NULL
      )
    ''');
    await db.execute(
        'CREATE INDEX idx_fav_added ON favourite_stations(added DESC)');
  }

  static Future<void> _onUpgrade(
      Database db, int oldVersion, int newVersion) async {
    // Future migrations here. For now v2 covers everything.
  }

  // ═══════════════════════════════════════════════════════════════════
  // 1. RESPONSE CACHE
  // ═══════════════════════════════════════════════════════════════════

  /// Store any JSON-serializable value with a TTL.
  static Future<void> put(
      String key,
      dynamic value, {
        Duration ttl = const Duration(hours: 1),
      }) async {
    try {
      final db = await instance;
      final now = DateTime.now().millisecondsSinceEpoch;
      await db.insert(
        'cache',
        {
          'key': key,
          'json': jsonEncode(value),
          'expires': now + ttl.inMilliseconds,
          'created': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      // Silent — cache is best-effort
    }
  }

  /// Retrieve a cached value. Returns null if missing or expired.
  static Future<dynamic> get(String key) async {
    try {
      final db = await instance;
      final rows = await db.query(
        'cache',
        columns: ['json', 'expires'],
        where: 'key = ?',
        whereArgs: [key],
        limit: 1,
      );
      if (rows.isEmpty) return null;

      final expires = rows.first['expires'] as int;
      if (DateTime.now().millisecondsSinceEpoch > expires) {
        await db.delete('cache', where: 'key = ?', whereArgs: [key]);
        return null;
      }
      return jsonDecode(rows.first['json'] as String);
    } catch (_) {
      return null;
    }
  }

  /// Check if a key exists and is not expired.
  static Future<bool> has(String key) async => (await get(key)) != null;

  /// Remove a single cached key.
  static Future<void> remove(String key) async {
    try {
      final db = await instance;
      await db.delete('cache', where: 'key = ?', whereArgs: [key]);
    } catch (_) {}
  }

  /// Remove all cached entries whose key starts with the given prefix.
  static Future<void> removeByPrefix(String prefix) async {
    try {
      final db = await instance;
      await db.delete('cache',
          where: 'key LIKE ?', whereArgs: ['$prefix%']);
    } catch (_) {}
  }

  /// Clear only expired entries — call this on app startup.
  static Future<void> clearExpired() async {
    try {
      final db = await instance;
      final now = DateTime.now().millisecondsSinceEpoch;
      await db.delete('cache', where: 'expires < ?', whereArgs: [now]);
    } catch (_) {}
  }

  /// Nuke the entire cache table.
  static Future<void> clearAllCache() async {
    try {
      final db = await instance;
      await db.delete('cache');
    } catch (_) {}
  }

  /// Stats for debugging / settings screen.
  static Future<Map<String, int>> cacheStats() async {
    try {
      final db = await instance;
      final rows =
      await db.rawQuery('SELECT COUNT(*) AS c FROM cache');
      final count = (rows.first['c'] as int?) ?? 0;

      final expiredRows = await db.rawQuery(
          'SELECT COUNT(*) AS c FROM cache WHERE expires < ?',
          [DateTime.now().millisecondsSinceEpoch]);
      final expired = (expiredRows.first['c'] as int?) ?? 0;

      return {'total': count, 'expired': expired};
    } catch (_) {
      return {'total': 0, 'expired': 0};
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // 2. SEARCH HISTORY
  // ═══════════════════════════════════════════════════════════════════

  /// Add a search-history entry.
  ///
  /// [kind]   — 'station' | 'train' | 'pnr' | 'route' | 'fare'
  /// [query]  — raw query (e.g., "NDLS" or "12952")
  /// [label]  — display-friendly (e.g., "New Delhi")
  /// [data]   — optional extra payload
  static Future<void> addHistory(
      String kind,
      String query, {
        String? label,
        Map<String, dynamic>? data,
      }) async {
    if (query.trim().isEmpty) return;
    try {
      final db = await instance;
      final now = DateTime.now().millisecondsSinceEpoch;

      // Dedup: delete old entry with same kind+query
      await db.delete(
        'search_history',
        where: 'kind = ? AND query = ?',
        whereArgs: [kind, query],
      );

      await db.insert('search_history', {
        'kind': kind,
        'query': query,
        'label': label,
        'data': data == null ? null : jsonEncode(data),
        'created': now,
      });

      // Keep only last 50 per kind
      await db.rawDelete('''
        DELETE FROM search_history
        WHERE kind = ? AND id NOT IN (
          SELECT id FROM search_history
          WHERE kind = ?
          ORDER BY created DESC
          LIMIT 50
        )
      ''', [kind, kind]);
    } catch (_) {}
  }

  /// Fetch recent history for a given kind.
  static Future<List<Map<String, dynamic>>> getHistory(
      String kind, {
        int limit = 30,
      }) async {
    try {
      final db = await instance;
      final rows = await db.query(
        'search_history',
        where: 'kind = ?',
        whereArgs: [kind],
        orderBy: 'created DESC',
        limit: limit,
      );
      return rows.map((r) {
        final m = Map<String, dynamic>.from(r);
        if (m['data'] is String) {
          try {
            m['data'] = jsonDecode(m['data'] as String);
          } catch (_) {}
        }
        return m;
      }).toList();
    } catch (_) {
      return const [];
    }
  }

  /// Clear all history for a given kind (or everything if null).
  static Future<void> clearHistory(String s, {String? kind}) async {
    try {
      final db = await instance;
      if (kind == null) {
        await db.delete('search_history');
      } else {
        await db.delete('search_history',
            where: 'kind = ?', whereArgs: [kind]);
      }
    } catch (_) {}
  }

  // ═══════════════════════════════════════════════════════════════════
  // 3. TRACKED TRAINS
  // ═══════════════════════════════════════════════════════════════════

  /// Remember that user is tracking this train.
  static Future<void> rememberTrain(
      String number,
      String name, {
        Map<String, dynamic>? route,
      }) async {
    if (number.trim().isEmpty) return;
    try {
      final db = await instance;
      final now = DateTime.now().millisecondsSinceEpoch;

      final existing = await db.query(
        'tracked_trains',
        where: 'train_number = ?',
        whereArgs: [number],
        limit: 1,
      );

      if (existing.isEmpty) {
        await db.insert('tracked_trains', {
          'train_number': number,
          'train_name': name,
          'route_json': route == null ? null : jsonEncode(route),
          'last_seen': now,
          'track_count': 1,
        });
      } else {
        await db.update(
          'tracked_trains',
          {
            'train_name': name,
            'route_json':
            route == null ? existing.first['route_json'] : jsonEncode(route),
            'last_seen': now,
            'track_count': ((existing.first['track_count'] as int?) ?? 0) + 1,
          },
          where: 'train_number = ?',
          whereArgs: [number],
        );
      }

      // Cap at 50
      await db.rawDelete('''
        DELETE FROM tracked_trains
        WHERE train_number NOT IN (
          SELECT train_number FROM tracked_trains
          ORDER BY last_seen DESC
          LIMIT 50
        )
      ''');
    } catch (_) {}
  }

  /// Retrieve recently tracked trains.
  static Future<List<Map<String, dynamic>>> getRecentTrains(
      {int limit = 20}) async {
    try {
      final db = await instance;
      final rows = await db.query(
        'tracked_trains',
        orderBy: 'last_seen DESC',
        limit: limit,
      );
      return rows.map((r) {
        final m = Map<String, dynamic>.from(r);
        if (m['route_json'] is String) {
          try {
            m['route'] = jsonDecode(m['route_json'] as String);
          } catch (_) {}
        }
        return m;
      }).toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<void> removeTrackedTrain(String number) async {
    try {
      final db = await instance;
      await db.delete('tracked_trains',
          where: 'train_number = ?', whereArgs: [number]);
    } catch (_) {}
  }

  static Future<void> clearTrackedTrains() async {
    try {
      final db = await instance;
      await db.delete('tracked_trains');
    } catch (_) {}
  }

  // ═══════════════════════════════════════════════════════════════════
  // 4. FAVOURITE STATIONS
  // ═══════════════════════════════════════════════════════════════════

  static Future<void> addFavouriteStation({
    required String code,
    required String name,
    String? city,
    String? state,
  }) async {
    if (code.trim().isEmpty) return;
    try {
      final db = await instance;
      await db.insert(
        'favourite_stations',
        {
          'code': code,
          'name': name,
          'city': city,
          'state': state,
          'added': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (_) {}
  }

  static Future<void> removeFavouriteStation(String code) async {
    try {
      final db = await instance;
      await db.delete('favourite_stations',
          where: 'code = ?', whereArgs: [code]);
    } catch (_) {}
  }

  static Future<bool> isFavouriteStation(String code) async {
    try {
      final db = await instance;
      final rows = await db.query('favourite_stations',
          where: 'code = ?', whereArgs: [code], limit: 1);
      return rows.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>> getFavouriteStations() async {
    try {
      final db = await instance;
      return await db.query('favourite_stations', orderBy: 'added DESC');
    } catch (_) {
      return const [];
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // 5. MAINTENANCE
  // ═══════════════════════════════════════════════════════════════════

  /// Nuclear option — wipe everything and close the DB.
  static Future<void> wipeAll() async {
    try {
      final db = await instance;
      await db.delete('cache');
      await db.delete('search_history');
      await db.delete('tracked_trains');
      await db.delete('favourite_stations');
      await db.execute('VACUUM');
    } catch (_) {}
  }

  /// Compact the database file.
  static Future<void> vacuum() async {
    try {
      final db = await instance;
      await db.execute('VACUUM');
    } catch (_) {}
  }

  /// Close DB — call from app dispose.
  static Future<void> dispose() async {
    await _db?.close();
    _db = null;
  }
}