import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/station.dart';

/// Handles BOTH formats of stations.json:
///   • { "stations": { "NDLS": "New Delhi", ... } }  ← aapka current format
///   • { "stations": [ { "code": "NDLS", "name": "New Delhi" } ] }
class StationSource {
  static List<Station> _all = [];
  static bool _loaded = false;

  static bool get isLoaded => _loaded;
  static int get count => _all.length;

  static Future<void> load() async {
    if (_loaded) return;
    try {
      final raw = await rootBundle.loadString('assets/data/stations.json');
      final decoded = json.decode(raw);

      if (decoded is! Map) {
        print('StationSource: unexpected JSON root');
        return;
      }

      final stationsRaw = decoded['stations'];
      if (stationsRaw == null) {
        print('StationSource: no "stations" key');
        return;
      }

      final loaded = <Station>[];

      if (stationsRaw is Map) {
        // Format 1: { "NDLS": "New Delhi", ... }
        stationsRaw.forEach((code, name) {
          final c = code.toString().trim().toUpperCase();
          final n = name.toString().trim();
          if (c.isEmpty || n.isEmpty) return;
          if (c.contains('-')) return; // skip technical codes
          loaded.add(Station(code: c, name: n));
        });
      } else if (stationsRaw is List) {
        // Format 2: [ { "code": "...", "name": "..." } ]
        for (final item in stationsRaw) {
          if (item is! Map) continue;
          final m = Map<String, dynamic>.from(item);
          final code = (m['code'] ?? m['stnCode'] ?? '').toString().trim().toUpperCase();
          final name = (m['name'] ?? m['stnName'] ?? '').toString().trim();
          if (code.isEmpty || name.isEmpty) continue;
          loaded.add(Station(
            code: code,
            name: name,
            city: m['city']?.toString(),
            state: m['state']?.toString(),
          ));
        }
      }

      final seen = <String>{};
      _all = loaded.where((s) => seen.add(s.code)).toList();
      _all.sort((a, b) => a.name.compareTo(b.name));
      _loaded = true;
      print('✅ StationSource loaded ${_all.length} stations');
    } catch (e) {
      print('❌ StationSource load failed: $e');
    }
  }

  static List<Station> search(String query, {int limit = 20}) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty || _all.isEmpty) return [];

    final exactCode = <Station>[];
    final codeStarts = <Station>[];
    final nameStarts = <Station>[];
    final nameContains = <Station>[];

    for (final s in _all) {
      final c = s.code.toLowerCase();
      final n = s.name.toLowerCase();
      if (c == q) {
        exactCode.add(s);
      } else if (c.startsWith(q)) {
        codeStarts.add(s);
      } else if (n.startsWith(q)) {
        nameStarts.add(s);
      } else if (n.contains(q)) {
        nameContains.add(s);
      }
      if (exactCode.length + codeStarts.length + nameStarts.length + nameContains.length >= limit * 3) break;
    }

    return [...exactCode, ...codeStarts, ...nameStarts, ...nameContains].take(limit).toList();
  }

  static Station? byCode(String code) {
    final c = code.trim().toUpperCase();
    for (final s in _all) {
      if (s.code == c) return s;
    }
    return null;
  }
}