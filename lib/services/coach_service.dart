import '../core/cache/offline_cache.dart';
import '../data/models/coach.dart';
import '../data/sources/railradar_source.dart';

class CoachService {
  static Future<TrainFormation?> fetch(String trainNumber,
      {String stationCode = 'NDLS'}) async {
    final cacheKey = 'coach_${trainNumber}_$stationCode';

    final rr = await RailRadarSource.coachPosition(
        trainNumber, stationCode);
    if (rr != null) {
      try {
        await OfflineCache.put(cacheKey, rr,
            ttl: const Duration(hours: 12));
      } catch (_) {}
      return TrainFormation.fromRailRadar(rr, trainNumber);
    }

    final cached = await OfflineCache.get(cacheKey);
    if (cached is Map) {
      return TrainFormation.fromRailRadar(
          Map<String, dynamic>.from(cached), trainNumber);
    }
    return null;
  }
}