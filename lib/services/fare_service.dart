import '../core/cache/offline_cache.dart';
import '../data/models/fare.dart';
import '../data/sources/ntes_source.dart';

class FareService {
  static Future<TrainFareData?> fetch({
    required String trainNumber,
    required String from,
    required String to,
    required String date,
    String classCode = 'SL',
    String quota = 'GN',
  }) async {
    final cacheKey = 'fare_${trainNumber}_${from}_${to}_${date}_$classCode';
    final d = await NtesSource.fare(
      trainNumber: trainNumber,
      from: from,
      to: to,
      date: date,
      classCode: classCode,
      quota: quota,
    );
    if (d == null) {
      final cached = await OfflineCache.get(cacheKey);
      if (cached is Map) {
        return TrainFareData.fromNtes(
            Map<String, dynamic>.from(cached),
            trainNumber, from, to, date, classCode);
      }
      return null;
    }
    try {
      await OfflineCache.put(cacheKey, d, ttl: const Duration(hours: 24));
    } catch (_) {}
    return TrainFareData.fromNtes(
      Map<String, dynamic>.from(d),
      trainNumber, from, to, date, classCode,
    );
  }
}