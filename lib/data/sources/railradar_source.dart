import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'api_router.dart';

/// RailRadar API client — https://railradar.in/docs
/// Envelope: { "success": true, "data": {...}, "meta": {...} }
class RailRadarSource {
  // static const String _apiKey = 'rg_7928ff69505e4205b53e5cec49fbf90a';
  static const String _apiKey = 'rr_n1ex7lqp1pjdkin8rw3xfjta5w970q2q';
  static const String _base = 'https://api.railradar.in/v1';
  static const Duration _timeout = Duration(seconds: 12);

  static const Map<String, String> _headers = {
    'Authorization': 'Bearer $_apiKey',
    'Accept': 'application/json',
  };

  // ═══════════════════════════════════════════════════════════════════
  // DIAGNOSTICS — read from the most recent _get() call.
  //
  // UI layers call these to build specific error messages:
  //   429 → "Too many requests, wait a minute"
  //   401/403 → "API key rejected"
  //   5xx → "Server temporarily unavailable"
  //   null → generic network error
  // ═══════════════════════════════════════════════════════════════════
  static int? _lastStatus;
  static String? _lastError;

  /// HTTP status code of the most recent request.
  /// `null` when the request never produced a response (DNS failure,
  /// socket error, timeout).
  static int? get lastStatusCode => _lastStatus;

  /// Human-readable error message from the API, or a description of
  /// the local failure (timeout, socket closed, JSON parse).
  static String? get lastErrorMessage => _lastError;

  /// Forget the previous error (call before a fresh attempt).
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

    // Build URI, only pass query when it actually has entries
    final uri = Uri.parse('$_base$path').replace(
      queryParameters: (query == null || query.isEmpty) ? null : query,
    );

    try {
      final res =
      await http.get(uri, headers: _headers).timeout(_timeout);

      _lastStatus = res.statusCode;

      // ── Status-specific handling ─────────────────────────────
      if (res.statusCode == 200) {
        // ── Credit tracking ─────────────────────────────────────────
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

      if (res.statusCode == 401 || res.statusCode == 403) {
        _lastError = 'API key rejected';
        _debug('[RailRadar] auth failed ${res.statusCode} on $uri');
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

      // ── Envelope parse ──────────────────────────────────────
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

      // Success — clear error
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
  //
  // Single call — geometry is requested inline when needed, no retry.
  // RailRadar returns the geometry block directly when `geometry=true`.
  // ═══════════════════════════════════════════════════════════════════
  static Future<Map<String, dynamic>?> liveTracking(
      String trainNumber, {
        bool includeGeometry = true,
      }) async {
    final n = trainNumber.trim();
    if (n.isEmpty) return null;

    final data = await _get(
      '/trains/$n/live',
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

    final data = await _get('/trains/between/$f/$t', query: {
      if (date != null && date.isNotEmpty) 'date': date,
    });
    if (data is! Map) return null;
    return Map<String, dynamic>.from(data);
  }

  // ═══════════════════════════════════════════════════════════════════
  // 5. STATION LIVE BOARD
  //    hours must be one of 2 / 4 / 6 / 8.
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
  // 8. COACH POSITION
  // ═══════════════════════════════════════════════════════════════════
  static Future<Map<String, dynamic>?> coachPosition(
      String trainNumber,
      String stationCode,
      ) async {
    final data =
    await _get('/trains/$trainNumber/coaches/$stationCode');
    if (data is! Map) return null;
    return Map<String, dynamic>.from(data);
  }

  // ═══════════════════════════════════════════════════════════════════
  // 9. TRAIN SCHEDULE
  // ═══════════════════════════════════════════════════════════════════
  static Future<Map<String, dynamic>?> trainSchedule(
      String trainNumber,
      ) async {
    final data = await _get('/trains/$trainNumber');
    if (data is! Map) return null;
    return Map<String, dynamic>.from(data);
  }
}