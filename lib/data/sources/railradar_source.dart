import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import 'api_router.dart';
import '../../services/remote_config_service.dart';

/// RailRadar API client — https://railradar.in/docs
/// Envelope: { "success": true, "data": {...}, "meta": {...} }
class RailRadarSource {
  /// Only the base URL still comes from .env. The API key does NOT.
  static String get _base =>
      (dotenv.env['RAILRADAR_BASE_URL'] ?? 'https://api.railradar.in/v1')
          .trim();

  static const Duration _timeout = Duration(seconds: 12);

  /// Toggle to `false` once auth is confirmed working.
  static const bool _verboseAuth = true;

  // ═══════════════════════════════════════════════════════════════════
  // AUTH
  //
  // Key is now fetched asynchronously from Firebase Remote Config.
  // A synchronous getter would return '' on cold start and cause 401s.
  // ═══════════════════════════════════════════════════════════════════
  static Future<String> _resolveKey() async {
    try {
      final k = await RemoteConfigService.ensureApiKey();
      return _sanitize(k);
    } catch (e) {
      _debug('[RailRadar] key resolve failed: $e');
      return '';
    }
  }

  /// Strip an accidental "Bearer " prefix, surrounding quotes, or
  /// trailing whitespace so we never send `Bearer Bearer …`.
  static String _sanitize(String raw) {
    var k = raw.trim();
    if (k.toLowerCase().startsWith('bearer ')) {
      k = k.substring(7).trim();
    }
    if (k.length >= 2 &&
        ((k.startsWith('"') && k.endsWith('"')) ||
            (k.startsWith("'") && k.endsWith("'")))) {
      k = k.substring(1, k.length - 1);
    }
    return k;
  }

  // ═══════════════════════════════════════════════════════════════════
  // DIAGNOSTICS
  // ═══════════════════════════════════════════════════════════════════
  static int? _lastStatus;
  static String? _lastError;

  static int? get lastStatusCode => _lastStatus;
  static String? get lastErrorMessage => _lastError;

  static void clearError() {
    _lastStatus = null;
    _lastError = null;
  }

  // ═══════════════════════════════════════════════════════════════════
  // CORE GET
  // ═══════════════════════════════════════════════════════════════════
  static Future<dynamic> _get(
      String path, {
        Map<String, String>? query,
      }) async {
    _lastStatus = null;
    _lastError = null;

    final uri = Uri.parse('$_base$path').replace(
      queryParameters: (query == null || query.isEmpty) ? null : query,
    );

    // ── AUTH PRE-FLIGHT (async — waits for Remote Config) ─────────
    final key = await _resolveKey();
    if (_verboseAuth) {
      final masked = key.isEmpty
          ? '<EMPTY>'
          : '${key.substring(0, key.length < 10 ? key.length : 10)}…'
          '(${key.length} chars)';
      _debug('[RailRadar] → $uri');
      _debug('[RailRadar]   base   = $_base');
      _debug('[RailRadar]   auth   = Bearer $masked');
      _debug('[RailRadar]   source = Firebase Remote Config');
    }

    if (key.isEmpty) {
      _lastError =
      'RailRadar API key not available yet. '
          'Check Firebase Remote Config → "api_key".';
      _debug('[RailRadar] ✗ aborted — empty key');
      return null;
    }
    if (!key.startsWith('rr_')) {
      _debug('[RailRadar] ⚠ key does not start with "rr_" — '
          'RailRadar keys look like rr_live_… / rr_test_…');
    }

    final headers = {
      'Authorization': 'Bearer $key',
      'Accept': 'application/json',
    };

    try {
      final res = await http.get(uri, headers: headers).timeout(_timeout);
      _lastStatus = res.statusCode;

      // ── Credit tracking on 200 ────────────────────────────────
      if (res.statusCode == 200) {
        final remaining = int.tryParse(
            res.headers['x-credits-remaining'] ??
                res.headers['x-ratelimit-remaining'] ??
                '');
        final limit = int.tryParse(
            res.headers['x-credits-limit'] ??
                res.headers['x-ratelimit-limit'] ??
                '');

        if (remaining != null || limit != null) {
          ApiRouter.reportCredits(remaining: remaining, limit: limit);
        }
      }

      // ── Status handling ───────────────────────────────────────
      if (res.statusCode == 401 || res.statusCode == 403) {
        final wwwAuth = res.headers['www-authenticate'];
        _lastError = wwwAuth != null
            ? 'API key rejected ($wwwAuth)'
            : 'API key rejected';
        _debug('[RailRadar] ✗ auth failed ${res.statusCode} on $uri');
        if (wwwAuth != null) {
          _debug('[RailRadar]   www-authenticate: $wwwAuth');
        }
        _debug('[RailRadar]   sent auth header: '
            'Bearer ${key.substring(0, key.length < 10 ? key.length : 10)}…');
        return null;
      }
      if (res.statusCode == 404) {
        _lastError = 'Not found';
        _debug('[RailRadar] 404 on $uri');
        return null;
      }
      if (res.statusCode == 429) {
        _lastError = 'Rate limit exceeded';
        _debug('[RailRadar] rate limited (429) on $uri');
        return null;
      }
      if (res.statusCode >= 500) {
        _lastError = 'Upstream server error (${res.statusCode})';
        _debug('[RailRadar] ${res.statusCode} on $uri: ${res.body}');
        return null;
      }
      if (res.statusCode != 200) {
        _lastError = 'HTTP ${res.statusCode}';
        _debug('[RailRadar] ${res.statusCode} on $uri: ${res.body}');
        return null;
      }

      // ── Envelope parse ────────────────────────────────────────
      dynamic body;
      try {
        body = json.decode(res.body);
      } catch (e) {
        _lastError = 'Malformed JSON';
        _debug('[RailRadar] json decode failed on $uri: $e');
        return null;
      }

      if (body is! Map) {
        _lastError = 'Unexpected response shape';
        _debug('[RailRadar] non-map body on $uri');
        return null;
      }

      if (body['success'] != true) {
        _lastError = body['error']?.toString() ??
            body['message']?.toString() ??
            'API returned success=false';
        _debug('[RailRadar] success!=true on $uri: $_lastError');
        return null;
      }

      _lastError = null;
      return body['data'];
    } on TimeoutException {
      _lastError = 'Request timed out';
      _debug('[RailRadar] timeout on $uri');
      return null;
    } on http.ClientException catch (e) {
      _lastError = 'Network error';
      _debug('[RailRadar] client error on $uri: ${e.message}');
      return null;
    } catch (e) {
      _lastError = e.toString();
      _debug('[RailRadar] unexpected error on $uri: $e');
      return null;
    }
  }

  static void _debug(String msg) {
    if (kDebugMode) debugPrint(msg);
  }

  // ═══════════════════════════════════════════════════════════════════
  // 1. TRAIN AUTOCOMPLETE
  // ═══════════════════════════════════════════════════════════════════
  static Future<List<Map<String, dynamic>>> searchTrains(
      String query, {
        int limit = 10,
      }) async {
    if (query.trim().isEmpty) return [];
    final data = await _get('/lookup/search/trains', query: {
      'q': query.trim(),
      'limit': '$limit',
    });
    if (data is! List) return [];
    return data
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  // ═══════════════════════════════════════════════════════════════════
  // 2. STATION AUTOCOMPLETE
  // ═══════════════════════════════════════════════════════════════════
  static Future<List<Map<String, dynamic>>> searchStations(
      String query, {
        int limit = 10,
      }) async {
    if (query.trim().isEmpty) return [];
    final data = await _get('/lookup/search/stations', query: {
      'q': query.trim(),
      'limit': '$limit',
    });
    if (data is! List) return [];
    return data
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  // ═══════════════════════════════════════════════════════════════════
  // 3. LIVE TRAIN RUNNING STATUS
  // ═══════════════════════════════════════════════════════════════════
  static Future<Map<String, dynamic>?> liveTracking(
      String trainNumber, {
        bool includeGeometry = true,
      }) async {
    final n = trainNumber.trim();
    if (n.isEmpty) return null;

    final data = await _get(
      '/trains/${n}/live',
      query: includeGeometry ? const {'geometry': 'true'} : null,
    );
    if (data is! Map) return null;
    return Map<String, dynamic>.from(data);
  }

  // ═══════════════════════════════════════════════════════════════════
  // 4. TRAINS BETWEEN STATIONS — date-aware
  // ═══════════════════════════════════════════════════════════════════
  static Future<Map<String, dynamic>?> trainsBetween(
      String from,
      String to, {
        String? date,
      }) async {
    final f = from.trim().toUpperCase();
    final t = to.trim().toUpperCase();
    if (f.isEmpty || t.isEmpty) return null;

    final data = await _get('/trains/between/${f}/${t}', query: {
      if (date != null && date.isNotEmpty) 'date': date,
    });
    if (data is! Map) return null;
    return Map<String, dynamic>.from(data);
  }

  // ═══════════════════════════════════════════════════════════════════
  // 5. STATION LIVE BOARD
  // ═══════════════════════════════════════════════════════════════════
  static Future<Map<String, dynamic>?> stationLive(
      String stationCode, {
        int hours = 8,
      }) async {
    final data = await _get('/stations/$stationCode/live', query: {
      'hours': '$hours',
    });
    if (data is! Map) return null;
    return Map<String, dynamic>.from(data);
  }

  // ═══════════════════════════════════════════════════════════════════
  // 6. STATION SCHEDULE
  // ═══════════════════════════════════════════════════════════════════
  static Future<Map<String, dynamic>?> stationSchedule(
      String stationCode,
      ) async {
    final data = await _get('/stations/$stationCode/trains');
    if (data is! Map) return null;
    return Map<String, dynamic>.from(data);
  }

  // ═══════════════════════════════════════════════════════════════════
  // 7. PNR
  // ═══════════════════════════════════════════════════════════════════
  static Future<Map<String, dynamic>?> pnr(String pnr) async {
    final data = await _get('/pnr/$pnr');
    if (data is! Map) return null;
    return Map<String, dynamic>.from(data);
  }

  // ═══════════════════════════════════════════════════════════════════
  // 8. COACH POSITION / FORMATION & COACHES
  // ═══════════════════════════════════════════════════════════════════
  static Future<Map<String, dynamic>?> coachPosition(
      String trainNumber, [
        String? stationCode,
      ]) async {
    final path = (stationCode != null && stationCode.trim().isNotEmpty)
        ? '/trains/$trainNumber/coaches/${stationCode.trim().toUpperCase()}'
        : '/trains/$trainNumber/coaches';
    final data = await _get(path);
    if (data is! Map) return null;
    return Map<String, dynamic>.from(data);
  }

  static Future<Map<String, dynamic>?> trainCoaches(
      String trainNumber,
      ) async {
    return coachPosition(trainNumber);
  }

  // ═══════════════════════════════════════════════════════════════════
  // 9. TRAIN SCHEDULE & ROUTE GEOMETRY
  // ═══════════════════════════════════════════════════════════════════
  static Future<Map<String, dynamic>?> trainSchedule(
      String trainNumber,
      ) async {
    final data = await _get('/trains/$trainNumber');
    if (data is! Map) return null;
    return Map<String, dynamic>.from(data);
  }

  static Future<Map<String, dynamic>?> trainRouteGeometry(
      String trainNumber,
      ) async {
    final n = trainNumber.trim();
    if (n.isEmpty) return null;

    final data = await _get(
      '/trains/$n/route',
      query: const {'format': 'geojson', 'stops': 'false'},
    );
    if (data is! Map) return null;
    return Map<String, dynamic>.from(data);
  }
}