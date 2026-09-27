import 'dart:async';
import 'package:flutter/foundation.dart';

import '../../core/cache/offline_cache.dart';
import '../../core/network/mntes_client.dart';
import 'api_router.dart';
import 'railradar_source.dart';
import 'station_source.dart';

/// Unified data source — RailRadar first (credits use karo),
/// MNTES fallback (jab RailRadar quota khatam ho).
///
/// Har endpoint:
///   1. ApiRouter se poocho — RailRadar allowed hai?
///   2. RailRadar try karo (status inspect karke router ko batao)
///   3. Fail → MNTES scrape karo (session-aware, normalized)
///   4. MNTES response ko normalize karo parser-friendly shape me
class NtesSource {
  static const Duration _mntesTimeout = Duration(seconds: 15);

  // ═══════════════════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════════════════
  static Map<String, dynamic>? _asMap(dynamic d) {
    if (d == null) return null;
    if (d is Map<String, dynamic>) return d;
    if (d is Map) {
      try {
        return Map<String, dynamic>.from(d);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  static bool _isRealPayload(dynamic d) {
    if (d == null) return false;
    if (d is! Map) return false;
    if (d['__html__'] is String) return false;
    if (d.isEmpty) return false;
    return true;
  }

  static int _normalizeHours(int h) {
    if (h <= 2) return 2;
    if (h <= 4) return 4;
    if (h <= 6) return 6;
    return 8;
  }

  /// Multi-key picker — MNTES ke alag-alag response shapes handle karta hai.
  static dynamic _pick(Map m, List<String> keys) {
    for (final k in keys) {
      final v = m[k];
      if (v == null) continue;
      if (v is String && v.trim().isEmpty) continue;
      return v;
    }
    return null;
  }

  static String _str(dynamic v, [String fb = '']) =>
      v == null ? fb : v.toString();

  static int _int(dynamic v, [int fb = 0]) {
    if (v == null) return fb;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? fb;
  }

  // ═══════════════════════════════════════════════════════════════════
  // MNTES CALL — with circuit breaker + rate limit + normalize
  // ═══════════════════════════════════════════════════════════════════
  static Future<dynamic> _mntes(
      String cat, String sub, Map<String, String> q) async {
    if (MntesClient.isBlocked) {
      debugPrint('[MNTES] circuit OPEN — skip $cat/$sub');
      return null;
    }
    try {
      final res = await MntesClient.post(cat, sub, query: q)
          .timeout(_mntesTimeout);
      if (res == null) {
        debugPrint('[MNTES] null response $cat/$sub');
        return null;
      }
      return res;
    } on TimeoutException {
      debugPrint('[MNTES] timeout $cat/$sub');
      return null;
    } catch (e) {
      debugPrint('[MNTES] error $cat/$sub: $e');
      return null;
    }
  }

  /// RailRadar ko call karke router ko status batao.
  /// Returns null jab router allow na kare ya call fail ho.
  static Future<T?> _tryRailRadar<T>(
      Future<T?> Function() call) async {
    if (!ApiRouter.useRailRadar) return null;

    RailRadarSource.clearError();
    try {
      final result = await call();
      ApiRouter.inspectRailRadarResult(RailRadarSource.lastStatusCode);
      return result;
    } catch (e) {
      debugPrint('[RailRadar] call threw: $e');
      ApiRouter.inspectRailRadarResult(RailRadarSource.lastStatusCode);
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // 1. LIVE TRAIN RUNNING STATUS
  // ═══════════════════════════════════════════════════════════════════
  static Future<Map<String, dynamic>?> liveTracking(
      String trainNumber) async {
    final n = trainNumber.trim();
    if (n.isEmpty) return null;

    // ── 1) RailRadar ─────────────────────────────────────────────
    final rr = await _tryRailRadar(
            () => RailRadarSource.liveTracking(n, includeGeometry: true));
    if (rr != null) return rr;

    // ── 2) MNTES scrape ──────────────────────────────────────────
    final raw = await _mntes('TrainRunning', 'ShowRunC', {
      'trainNo': n,
      'lang': 'en',
    });
    if (!_isRealPayload(raw)) return null;

    return _normalizeLive(raw as Map, n);
  }

  /// MNTES ShowRunC response → parser-friendly shape
  /// (compatible with TrainTracking.fromNtes)
  static Map<String, dynamic> _normalizeLive(Map raw, String number) {
    final m = Map<String, dynamic>.from(raw);

    // Train name / number
    final trainName = _str(_pick(m, [
      'train_name', 'trainName', 'trainNameEn',
    ]));

    // Current station
    final currentCode = _str(_pick(m, [
      'current_station_code', 'curStn', 'currentStationCode',
      'cur_stn_code',
    ]));

    final currentName = _str(_pick(m, [
      'current_station_name', 'curStnName', 'currentStationName',
    ]));

    // Route / stations
    final rawRoute = _pick(m, [
      'stations', 'stationList', 'route', 'stnList',
    ]);
    final route = <Map<String, dynamic>>[];

    if (rawRoute is List) {
      for (var i = 0; i < rawRoute.length; i++) {
        final item = rawRoute[i];
        if (item is! Map) continue;
        final s = Map<String, dynamic>.from(item);

        route.add({
          'seq': i + 1,
          'stationCode': _str(_pick(s, [
            'stnCode', 'stationCode', 'code', 'stn_code',
          ])),
          'stationName': _str(_pick(s, [
            'stnName', 'stationName', 'name', 'stn_name',
          ])),
          'arrivalTime': _str(_pick(s, [
            'sta', 'arrivalTime', 'arrival', 'schArrival',
          ])),
          'departureTime': _str(_pick(s, [
            'std', 'departureTime', 'departure', 'schDeparture',
          ])),
          'distance': _int(_pick(s, [
            'distance', 'dist', 'km',
          ])),
          'dayCount': _int(_pick(s, [
            'dayCount', 'day', 'dayNo',
          ]), 1),
          'platform': _str(_pick(s, ['platform', 'pf', 'platformNo'])),
          'halt': true,
          'delay': _int(_pick(s, [
            'delayArrival', 'delay', 'delayMin',
          ])),
        });
      }
    }

    // Delay / speed
    final delay = _int(_pick(m, [
      'delay', 'delayMinutes', 'lateBy', 'late',
    ]));
    final speed = _int(_pick(m, [
      'speed', 'avgSpeed', 'speedKmh',
    ]));

    return {
      'trainNumber': number,
      'trainName': trainName,
      'status': _str(_pick(m, ['status', 'runningStatus']), 'running'),
      'delay': delay,
      'speed': speed,
      'currentStationCode': currentCode,
      'curStn': currentCode,
      'currentStationName': currentName,
      'stationList': route,
      'route': route,
      'source': 'mntes',
    };
  }

  // ═══════════════════════════════════════════════════════════════════
  // 2. TRAINS BETWEEN STATIONS
  // ═══════════════════════════════════════════════════════════════════
  static Future<Map<String, dynamic>?> trainsBetween(
      String from, String to, String date) async {
    final f = from.trim().toUpperCase();
    final t = to.trim().toUpperCase();
    if (f.isEmpty || t.isEmpty) return null;

    // ── 1) RailRadar ─────────────────────────────────────────────
    final rr = await _tryRailRadar(
            () => RailRadarSource.trainsBetween(f, t, date: date));
    final rrMap = _asMap(rr);
    if (rrMap != null) return rrMap;

    // ── 2) MNTES scrape ──────────────────────────────────────────
    final raw = await _mntes('TrainRunning', 'TrainBetweenStations', {
      'fromStation': f,
      'toStation': t,
      'jDate': date,
    });
    if (!_isRealPayload(raw)) return null;

    return _normalizeBetween(raw as Map, f, t, date);
  }

  /// MNTES TrainBetweenStations → shape jo TrainService.trainsBetween
  /// already samajhta hai.
  static Map<String, dynamic> _normalizeBetween(
      Map raw, String from, String to, String date) {
    final m = Map<String, dynamic>.from(raw);

    final rawList = _pick(m, [
      'trains', 'trainBtwnStnsList', 'trainList', 'trainBtwnStns',
    ]);
    final trains = <Map<String, dynamic>>[];

    if (rawList is List) {
      for (final item in rawList) {
        if (item is! Map) continue;
        final x = Map<String, dynamic>.from(item);

        trains.add({
          'trainNumber': _str(_pick(x, [
            'train_no', 'trainNumber', 'trainNo', 'number',
          ])),
          'trainName': _str(_pick(x, [
            'train_name', 'trainName', 'name',
          ])),
          'trainType': _str(_pick(x, [
            'train_type', 'trainType', 'type',
          ])),
          'fromStnCode': _str(_pick(x, [
            'from_stn_code', 'fromStnCode', 'fromCode',
          ]), from),
          'fromStnName': _str(_pick(x, [
            'from_stn_name', 'fromStnName', 'fromName',
          ]), from),
          'departureTime': _str(_pick(x, [
            'from_time', 'departureTime', 'depTime', 'std',
          ]), '--'),
          'fromDay': _int(_pick(x, ['from_day', 'fromDay']), 1),
          'toStnCode': _str(_pick(x, [
            'to_stn_code', 'toStnCode', 'toCode',
          ]), to),
          'toStnName': _str(_pick(x, [
            'to_stn_name', 'toStnName', 'toName',
          ]), to),
          'arrivalTime': _str(_pick(x, [
            'to_time', 'arrivalTime', 'arrTime', 'sta',
          ]), '--'),
          'toDay': _int(_pick(x, ['to_day', 'toDay']), 1),
          'distance': _int(_pick(x, ['distance', 'dist'])),
          'duration': _int(_pick(x, [
            'travel_time', 'duration', 'durationMin',
          ])),
          'totalHaltsBetween': _int(_pick(x, [
            'total_halts', 'halts', 'totalHaltsBetween',
          ])),
        });
      }
    }

    return {
      'from': {'code': from, 'name': from},
      'to': {'code': to, 'name': to},
      'journeyDate': date,
      'trains': trains,
      'count': trains.length,
      'source': 'mntes',
    };
  }

  // ═══════════════════════════════════════════════════════════════════
  // 3. PNR
  // ═══════════════════════════════════════════════════════════════════
  static Future<Map<String, dynamic>?> pnr(String pnrNumber) async {
    final p = pnrNumber.trim();
    if (p.isEmpty) return null;

    final rr = await _tryRailRadar(() => RailRadarSource.pnr(p));
    if (rr != null) return rr;

    final raw = await _mntes('PNR', 'ShowPNRStatus', {
      'pnrNumber': p,
    });
    if (!_isRealPayload(raw)) return null;

    return _normalizePnr(raw as Map, p);
  }

  static Map<String, dynamic> _normalizePnr(Map raw, String pnr) {
    final m = Map<String, dynamic>.from(raw);

    // Passengers
    final rawP = _pick(m, ['passengerStatus', 'passengers', 'passengerList']);
    final passengers = <Map<String, dynamic>>[];

    if (rawP is List) {
      for (var i = 0; i < rawP.length; i++) {
        final item = rawP[i];
        if (item is! Map) continue;
        final x = Map<String, dynamic>.from(item);
        passengers.add({
          'serialNumber': i + 1,
          'bookingStatus': _str(_pick(x, [
            'bookingStatus', 'booking', 'booking_status',
          ])),
          'currentStatus': _str(_pick(x, [
            'currentStatus', 'current', 'current_status', 'status',
          ])),
          'coach': _str(_pick(x, ['coach', 'coachNumber', 'coach_no'])),
          'berth': _str(_pick(x, [
            'berth', 'berthNo', 'berthNumber', 'berth_no',
          ])),
          'berthType': _str(_pick(x, [
            'berthType', 'berthCode', 'berth_type',
          ])),
        });
      }
    }

    return {
      'pnrNumber': _str(_pick(m, ['pnrNumber', 'pnr', 'pnr_no']), pnr),
      'trainNumber': _str(_pick(m, [
        'trainNumber', 'train_no', 'trainNo',
      ])),
      'trainName': _str(_pick(m, [
        'trainName', 'train_name',
      ])),
      'doj': _str(_pick(m, [
        'doj', 'journeyDate', 'dateOfJourney', 'date_of_journey',
      ])),
      'boardingStation': _str(_pick(m, [
        'boardingStation', 'from', 'boarding_station', 'fromStnCode',
      ])),
      'reservationUpto': _str(_pick(m, [
        'reservationUpto', 'to', 'reservation_upto', 'toStnCode',
      ])),
      'journeyClass': _str(_pick(m, [
        'journeyClass', 'class', 'classCode', 'journey_class',
      ])),
      'chartStatus': _str(_pick(m, [
        'chartStatus', 'chart_status', 'chartingStatus',
      ])),
      'passengerStatus': passengers,
      'passengers': passengers,
      'source': 'mntes',
    };
  }

  // ═══════════════════════════════════════════════════════════════════
  // 4. COACH POSITION
  // ═══════════════════════════════════════════════════════════════════
  static Future<Map<String, dynamic>?> coachPosition(
      String trainNumber, {
        String? stationCode,
      }) async {
    final n = trainNumber.trim();
    if (n.isEmpty) return null;

    // ── 1) RailRadar (station known) ─────────────────────────────
    if (stationCode != null && stationCode.trim().isNotEmpty) {
      final rr = await _tryRailRadar(
              () => RailRadarSource.coachPosition(n, stationCode));
      if (rr != null) return rr;
    } else {
      // Derive source station from schedule (RailRadar only)
      final sched = await _tryRailRadar(
              () => RailRadarSource.trainSchedule(n));
      if (sched != null) {
        final route = sched['route'];
        if (route is List && route.isNotEmpty) {
          final first = route.first;
          if (first is Map) {
            final code = first['stationCode']?.toString();
            if (code != null && code.isNotEmpty) {
              final rr = await _tryRailRadar(
                      () => RailRadarSource.coachPosition(n, code));
              if (rr != null) return rr;
            }
          }
        }
      }
    }

    // ── 2) MNTES ─────────────────────────────────────────────────
    final raw = await _mntes('TrainRunning', 'CoachPosition', {
      'trainNo': n,
    });
    if (!_isRealPayload(raw)) return null;

    return _normalizeCoach(raw as Map, n, stationCode);
  }

  static Map<String, dynamic> _normalizeCoach(
      Map raw, String number, String? station) {
    final m = Map<String, dynamic>.from(raw);

    final rawList = _pick(m, [
      'coachPositionList', 'coaches', 'coachList', 'composition', 'rake',
    ]);
    final coaches = <Map<String, dynamic>>[];

    if (rawList is List) {
      for (var i = 0; i < rawList.length; i++) {
        final item = rawList[i];
        if (item is Map) {
          final x = Map<String, dynamic>.from(item);
          coaches.add({
            'position': _int(_pick(x, ['position', 'index', 'seq']), i + 1),
            'code': _str(_pick(x, [
              'code', 'coachCode', 'coach', 'number',
            ])),
            'class': _str(_pick(x, [
              'class', 'classCode', 'category', 'type',
            ])),
          });
        } else if (item is String && item.trim().isNotEmpty) {
          coaches.add({
            'position': i + 1,
            'code': item.trim(),
          });
        }
      }
    }

    // Fallback: "ENG-B1-B2-A1-..." string
    if (coaches.isEmpty) {
      final str = _str(_pick(m, [
        'coachPosition', 'coach_position', 'rakeStr',
      ]));
      if (str.isNotEmpty) {
        final parts = str.split('-');
        for (var i = 0; i < parts.length; i++) {
          final c = parts[i].trim();
          if (c.isEmpty) continue;
          coaches.add({'position': i + 1, 'code': c});
        }
      }
    }

    return {
      'trainNumber': _str(_pick(m, ['trainNumber', 'train_no']), number),
      'trainName': _str(_pick(m, ['trainName', 'train_name'])),
      'totalCoaches': coaches.length,
      'coaches': coaches,
      'stationCode': station,
      'stationName': _str(_pick(m, ['stationName', 'stnName'])),
      'source': 'mntes',
    };
  }

  // ═══════════════════════════════════════════════════════════════════
  // 5. FARE (RailRadar doesn't expose fare; MNTES only)
  // ═══════════════════════════════════════════════════════════════════
  static Future<Map<String, dynamic>?> fare({
    required String trainNumber,
    required String from,
    required String to,
    required String date,
    required String classCode,
    required String quota,
  }) async {
    final raw = await _mntes('TrainRunning', 'FareEnquiry', {
      'trainNo': trainNumber,
      'fromStation': from,
      'toStation': to,
      'jDate': date,
      'class': classCode,
      'quota': quota,
    });
    if (!_isRealPayload(raw)) return null;

    return _normalizeFare(raw as Map);
  }

  static Map<String, dynamic> _normalizeFare(Map raw) {
    final m = Map<String, dynamic>.from(raw);
    final fareMap = m['fare'] is Map
        ? Map<String, dynamic>.from(m['fare'] as Map)
        : m;

    final total = _int(_pick(fareMap, [
      'total', 'totalFare', 'amount', 'fare',
    ]));
    final base = _int(_pick(fareMap, [
      'baseFare', 'base', 'basicFare',
    ]), total);

    return {
      'total': total,
      'totalFare': total,
      'baseFare': base,
      'reservationCharge': _int(_pick(fareMap, ['reservationCharge'])),
      'superfastCharge': _int(_pick(fareMap, ['superfastCharge'])),
      'cateringCharge': _int(_pick(fareMap, ['cateringCharge'])),
      'serviceTax': _int(_pick(fareMap, ['serviceTax', 'gst'])),
      'tatkalCharge': _int(_pick(fareMap, ['tatkalCharge'])),
      'otherCharges': _int(_pick(fareMap, ['otherCharges'])),
      'quota': _str(_pick(m, ['quota'])),
      'source': 'mntes',
    };
  }

  // ═══════════════════════════════════════════════════════════════════
  // 6. STATION LIVE TRAFFIC
  // ═══════════════════════════════════════════════════════════════════
  static Future<Map<String, dynamic>?> stationTraffic(
      String stationCode, int hours) async {
    final code = stationCode.trim().toUpperCase();
    if (code.isEmpty) return null;

    final rr = await _tryRailRadar(
            () => RailRadarSource.stationLive(code, hours: _normalizeHours(hours)));
    if (rr != null) return rr;

    final raw = await _mntes('Station', 'LiveStation', {
      'station': code,
      'nextMins': '${hours * 60}',
    });
    if (!_isRealPayload(raw)) return null;

    return _normalizeTraffic(raw as Map, code, hours);
  }

  static Map<String, dynamic> _normalizeTraffic(
      Map raw, String code, int hours) {
    final m = Map<String, dynamic>.from(raw);

    final rawList = _pick(m, [
      'trainList', 'trains', 'movements', 'data', 'departures', 'arrivals',
    ]);
    final trains = <Map<String, dynamic>>[];

    if (rawList is List) {
      for (final item in rawList) {
        if (item is! Map) continue;
        final x = Map<String, dynamic>.from(item);
        trains.add({
          'trainNumber': _str(_pick(x, [
            'train_no', 'trainNumber', 'trainNo', 'number',
          ])),
          'trainName': _str(_pick(x, [
            'train_name', 'trainName', 'name',
          ])),
          'source': _str(_pick(x, [
            'source', 'from', 'fromStnName', 'src',
          ])),
          'destination': _str(_pick(x, [
            'destination', 'to', 'toStnName', 'dest',
          ])),
          'arrival': _str(_pick(x, [
            'arrival', 'arrivalTime', 'sta', 'eta',
          ])),
          'departure': _str(_pick(x, [
            'departure', 'departureTime', 'std', 'etd',
          ])),
          'platform': _str(_pick(x, ['platform', 'pf'])),
          'delayMinutes': _int(_pick(x, [
            'delay', 'delayMinutes', 'lateBy',
          ])),
          'trainType': _str(_pick(x, ['trainType', 'type'])),
        });
      }
    }

    return {
      'stationCode': code,
      'stationName': _str(_pick(m, [
        'stationName', 'stnName', 'name',
      ]), code),
      'hours': hours,
      'hoursAhead': hours,
      'trainList': trains,
      'trains': trains,
      'count': trains.length,
      'source': 'mntes',
    };
  }

  // ═══════════════════════════════════════════════════════════════════
  // 7. STATION SCHEDULE
  // ═══════════════════════════════════════════════════════════════════
  static Future<Map<String, dynamic>?> stationSchedule(
      String stationCode) async {
    final code = stationCode.trim().toUpperCase();
    if (code.isEmpty) return null;

    final rr = await _tryRailRadar(
            () => RailRadarSource.stationSchedule(code));
    if (rr != null) return rr;

    final raw = await _mntes('Station', 'StationSchedule', {
      'station': code,
      'lang': 'en',
    });
    if (!_isRealPayload(raw)) return null;

    // Station schedule shape similar to traffic
    return _normalizeTraffic(raw as Map, code, 24);
  }

  // ═══════════════════════════════════════════════════════════════════
  // 8. LOOKUPS (RailRadar + Local / MNTES Fallbacks)
  // ═══════════════════════════════════════════════════════════════════
  static Future<List<Map<String, dynamic>>> searchTrains(
      String query, {
        int limit = 10,
      }) async {
    final rr = await _tryRailRadar(
            () => RailRadarSource.searchTrains(query, limit: limit));
    if (rr != null && rr.isNotEmpty) return rr;

    // Fallback: search in OfflineCache recent/tracked trains
    try {
      final recent = await OfflineCache.getRecentTrains(limit: limit);
      final q = query.trim().toLowerCase();
      return recent.where((t) {
        final num = t['train_number']?.toString().toLowerCase() ?? '';
        final name = t['train_name']?.toString().toLowerCase() ?? '';
        return num.contains(q) || name.contains(q);
      }).map((t) => {
        'number': t['train_number'],
        'name': t['train_name'],
      }).toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<List<Map<String, dynamic>>> searchStations(
      String query, {
        int limit = 10,
      }) async {
    final rr = await _tryRailRadar(
            () => RailRadarSource.searchStations(query, limit: limit));
    if (rr != null && rr.isNotEmpty) return rr;

    // Fallback: use local bundled StationSource (offline stations.json)
    try {
      if (!StationSource.isLoaded) {
        await StationSource.load();
      }
      final stations = StationSource.search(query, limit: limit);
      return stations.map((s) => {
        'code': s.code,
        'name': s.name,
        'city': s.city ?? '',
        'state': s.state ?? '',
      }).toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<Map<String, dynamic>?> trainSchedule(String trainNumber) async {
    final rr = await _tryRailRadar(
            () => RailRadarSource.trainSchedule(trainNumber));
    if (rr != null && rr.isNotEmpty) return rr;

    // Fallback: fetch liveTracking which contains full route/schedule!
    return await liveTracking(trainNumber);
  }

  // ═══════════════════════════════════════════════════════════════════
  // DIAGNOSTICS
  // ═══════════════════════════════════════════════════════════════════
  static Map<String, dynamic> get routingState => ApiRouter.state;
}