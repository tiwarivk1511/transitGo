class CoachInfo {
  final int position;
  final String code;
  final String category;

  CoachInfo({
    required this.position,
    required this.code,
    required this.category,
  });

  factory CoachInfo.fromCode(String code, int position, {String? category}) {
    return CoachInfo(
      position: position,
      code: code,
      category: (category != null && category.trim().isNotEmpty)
          ? category.trim().toUpperCase()
          : _catFrom(code),
    );
  }

  /// Best-effort local classification of a coach code into an IR class.
  ///
  /// Handles common Indian Railways rake markings:
  ///   H1 / H2       → 1A (First AC)
  ///   A1 / A2 / A3  → 2A (Second AC)
  ///   B1 / B2 / …   → 3A (Third AC)
  ///   M1 / M2 / …   → 3E (3AC Economy)
  ///   C1 / C2 / …   → CC (Chair Car)
  ///   D1 / D2 / …   → 2S (Second Sitting)
  ///   S1 / S2 / …   → SL (Sleeper)
  ///   ENG / LOCO    → LOCO
  ///   EOG / LPR / SLR → EOG / SLRD
  ///   PC / PANTRY   → PC
  ///   GS / GEN / UR → GEN
  static String _catFrom(String code) {
    final c = code.toUpperCase().trim();
    if (c.isEmpty) return 'GEN';

    // Full-word markers first
    if (c == 'LOCO' || c.contains('ENG')) return 'LOCO';
    if (c.contains('EOG') || c == 'LPR') return 'EOG';
    if (c.contains('SLR')) return 'SLRD';
    if (c.contains('PANTRY') || c == 'PC') return 'PC';
    if (c == 'GS' || c == 'GEN' || c == 'UR') return 'GEN';

    // Single-letter prefixes
    if (c.startsWith('H')) return '1A';
    if (c.startsWith('A')) return '2A';
    if (c.startsWith('B')) return '3A';
    if (c.startsWith('M')) return '3E';
    if (c.startsWith('C')) return 'CC';
    if (c.startsWith('D')) return '2S';
    if (c.startsWith('S')) return 'SL';

    return 'GEN';
  }

  @override
  String toString() => 'CoachInfo($position, $code, $category)';
}

class TrainFormation {
  final String trainNumber;
  final String trainName;
  final int totalCoaches;
  final List<CoachInfo> coaches;

  /// Optional metadata — populated when available.
  final String? stationCode;
  final String? stationName;
  final String? enginePosition; // 'front' | 'rear' | null

  TrainFormation({
    required this.trainNumber,
    required this.trainName,
    required this.totalCoaches,
    required this.coaches,
    this.stationCode,
    this.stationName,
    this.enginePosition,
  });

  // ═══════════════════════════════════════════════════════════════════
  // NTES PARSER (legacy)
  // ═══════════════════════════════════════════════════════════════════
  factory TrainFormation.fromNtes(
      Map<String, dynamic> data, String number) {
    final raw = (data['coachPositionList'] ??
        data['coaches'] ??
        data['rake'] ??
        data['composition'] ??
        []) as List?;

    final coaches = <CoachInfo>[];
    if (raw != null) {
      for (var i = 0; i < raw.length; i++) {
        final item = raw[i];
        String code = '';
        String? category;

        if (item is Map) {
          code = (item['coachCode'] ??
              item['code'] ??
              item['coach'] ??
              item['number'] ??
              '')
              .toString();
          category = (item['class'] ??
              item['classCode'] ??
              item['category'] ??
              item['type'])
              ?.toString();
        } else {
          code = item.toString();
        }

        if (code.trim().isEmpty) continue;
        coaches.add(CoachInfo.fromCode(
          code.trim(),
          i + 1,
          category: category,
        ));
      }
    }

    return TrainFormation(
      trainNumber: number,
      trainName: data['trainName']?.toString() ??
          data['name']?.toString() ??
          '',
      totalCoaches: coaches.length,
      coaches: coaches,
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // RAILRADAR PARSER
  //
  // Handles both plausible response shapes:
  //   A) { "coaches": [ {position, code, class}, ... ], "train": {...} }
  //   B) { "composition": [ {position, code, class}, ... ], ... }
  //   C) { "data": { ... } }  ← already unwrapped by source layer
  // ═══════════════════════════════════════════════════════════════════
  factory TrainFormation.fromRailRadar(
      Map<String, dynamic> data, String number) {
    // Train metadata can be nested under 'train' or flat
    final trainMap = data['train'] is Map
        ? Map<String, dynamic>.from(data['train'] as Map)
        : const <String, dynamic>{};

    final stationMap = data['atStation'] is Map
        ? Map<String, dynamic>.from(data['atStation'] as Map)
        : (data['station'] is Map
        ? Map<String, dynamic>.from(data['station'] as Map)
        : const <String, dynamic>{});

    // Try every plausible key for the coach array
    final raw = (data['coaches'] ??
        data['composition'] ??
        data['coachPositionList'] ??
        data['rake'] ??
        data['coachList'] ??
        []) as List?;

    final coaches = <CoachInfo>[];
    if (raw != null) {
      for (var i = 0; i < raw.length; i++) {
        final item = raw[i];
        String code = '';
        String? category;
        int position = i + 1;

        if (item is Map) {
          final m = Map<String, dynamic>.from(item);
          code = (m['code'] ??
              m['coachCode'] ??
              m['coach'] ??
              m['name'] ??
              m['number'] ??
              '')
              .toString();

          category = (m['class'] ??
              m['classCode'] ??
              m['category'] ??
              m['type'])
              ?.toString();

          final posRaw = m['position'] ?? m['index'] ?? m['sequence'];
          if (posRaw is num) {
            position = posRaw.toInt();
          } else if (posRaw is String) {
            position = int.tryParse(posRaw) ?? position;
          }
        } else if (item is String) {
          code = item;
        }

        if (code.trim().isEmpty) continue;
        coaches.add(CoachInfo.fromCode(
          code.trim(),
          position,
          category: category,
        ));
      }
    }

    // Sort by position (server may send out of order)
    coaches.sort((a, b) => a.position.compareTo(b.position));

    final total = (data['totalCoaches'] as num?)?.toInt() ?? coaches.length;

    return TrainFormation(
      trainNumber:
      (trainMap['number'] ?? data['trainNumber'] ?? number).toString(),
      trainName:
      (trainMap['name'] ?? data['trainName'] ?? '').toString(),
      totalCoaches: total,
      coaches: coaches,
      stationCode: stationMap['code']?.toString() ??
          data['stationCode']?.toString(),
      stationName: stationMap['name']?.toString() ??
          data['stationName']?.toString(),
      enginePosition: data['enginePosition']?.toString(),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // AUTO — tries RailRadar shape first, then NTES shape
  // ═══════════════════════════════════════════════════════════════════
  factory TrainFormation.parse(
      Map<String, dynamic> data, String number) {
    // Heuristic: RailRadar responses contain 'train' as a Map,
    // NTES responses are usually flat.
    if (data['train'] is Map ||
        data['composition'] is List ||
        data['atStation'] is Map) {
      return TrainFormation.fromRailRadar(data, number);
    }
    return TrainFormation.fromNtes(data, number);
  }

  /// Convenience: group coaches by their category.
  Map<String, int> get compositionByClass {
    final out = <String, int>{};
    for (final c in coaches) {
      out[c.category] = (out[c.category] ?? 0) + 1;
    }
    return out;
  }

  /// Locate a coach by its code (case-insensitive).
  CoachInfo? findByCode(String code) {
    final target = code.toUpperCase();
    for (final c in coaches) {
      if (c.code.toUpperCase() == target) return c;
    }
    return null;
  }

  @override
  String toString() =>
      'TrainFormation($trainNumber, $totalCoaches coaches)';
}