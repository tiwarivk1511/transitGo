class CoachInfo {
  final int position;
  final String code;
  final String category;
  final String? classType;
  final String? className;
  final int totalBerths;
  final bool hasSeats;

  CoachInfo({
    required this.position,
    required this.code,
    required this.category,
    this.classType,
    this.className,
    this.totalBerths = 0,
    this.hasSeats = false,
  });

  /// Alias getter for type (resolves `coach.type` errors across UI components)
  String get type => classType ?? category;

  /// Helper to check if this specific coach or loco belongs to a Vande Bharat trainset
  bool get isVandeBharat {
    final cCode = code.toUpperCase();
    final cCat = category.toUpperCase();
    final cName = (className ?? '').toUpperCase();
    final cType = type.toUpperCase();

    return cCode.contains('VB') ||
        cCode.contains('VANDE') ||
        cCat.contains('VB') ||
        cType.contains('VB') ||
        cName.contains('VANDE BHARAT');
  }

  factory CoachInfo.fromCode(String code, int position, {String? category}) {
    return CoachInfo(
      position: position,
      code: code,
      category: (category != null && category.trim().isNotEmpty)
          ? category.trim().toUpperCase()
          : _catFrom(code),
    );
  }

  factory CoachInfo.fromMap(Map<String, dynamic> m, int index) {
    final code =
        (m['code'] ??
                m['coachCode'] ??
                m['coach'] ??
                m['name'] ??
                m['number'] ??
                '')
            .toString();
    final category =
        (m['category'] ?? m['classType'] ?? m['class'] ?? m['type'])
            ?.toString() ??
        '';
    final rawSeatLayout =
        m['blueprint'] ?? m['seatLayout'] ?? m['seats'] ?? m['berths'];
    final totalBerths =
        _readInt(
          m['totalBerths'] ??
              m['totalSeats'] ??
              m['seatCount'] ??
              m['berthCount'],
        ) ??
        (rawSeatLayout is List ? rawSeatLayout.length : 0);
    final hasSeats =
        m['hasSeats'] == true ||
        totalBerths > 0 ||
        (rawSeatLayout is List && rawSeatLayout.isNotEmpty);
    final className = m['className']?.toString();
    final classType = m['classType']?.toString();

    int position = index + 1;
    final posRaw = m['position'] ?? m['index'] ?? m['sequence'];
    if (posRaw is num) {
      position = posRaw.toInt();
    } else if (posRaw is String) {
      position = int.tryParse(posRaw) ?? position;
    }

    final catNormalized = category.trim().toUpperCase();
    final resolvedCategory = catNormalized.isNotEmpty
        ? catNormalized
        : _catFrom(code);

    return CoachInfo(
      position: position,
      code: code.trim(),
      category: resolvedCategory,
      classType: classType,
      className: className,
      totalBerths: totalBerths,
      hasSeats: hasSeats,
    );
  }


  static String _catFrom(String code) {
    final c = code.toUpperCase().trim();
    if (c.isEmpty) return 'GEN';

    if (c == 'LOCO' || c.contains('ENG') || c.contains('VB')) return 'LOCO';
    if (c.contains('EOG') || c == 'LPR' || c == 'SLRD') return 'EOG';
    if (c.contains('SLR')) return 'SLRD';
    if (c.contains('PANTRY') || c == 'PC') return 'PC';
    if (c == 'GS' || c == 'GEN' || c == 'UR') return 'GEN';

    if (c.startsWith('EC')) return 'EC';
    if (c.startsWith('H')) return '1A';
    if (c.startsWith('A')) return '2A';
    if (c.startsWith('B')) return '3A';
    if (c.startsWith('M')) return '3E';
    if (c.startsWith('C')) return 'CC';
    if (c.startsWith('D')) return '2S';
    if (c.startsWith('S')) return 'SL';

    return 'GEN';
  }

  static int? _readInt(dynamic value) {
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }

  @override
  String toString() =>
      'CoachInfo($position, $code, $category, berths: $totalBerths)';
}

class TrainLeg {
  final int legIndex;
  final String fromStation;
  final String toStation;
  final String fromStationName;
  final String toStationName;
  final bool isReversed;
  final String? reversalStation;
  final List<CoachInfo> coaches;

  TrainLeg({
    required this.legIndex,
    required this.fromStation,
    required this.toStation,
    required this.fromStationName,
    required this.toStationName,
    required this.isReversed,
    this.reversalStation,
    required this.coaches,
  });
}

class StationCoachStop {
  final String stationCode;
  final String stationName;
  final String? platform;
  final bool reversal;
  final String? formation;
  final List<CoachInfo> coaches;

  StationCoachStop({
    required this.stationCode,
    required this.stationName,
    this.platform,
    required this.reversal,
    this.formation,
    required this.coaches,
  });

  /// A station is considered a "major halt" when the API supplies a platform.
  bool get isMajorHalt {
    final p = platform;
    return p != null && p.trim().isNotEmpty;
  }
}

class TrainFormation {
  final String trainNumber;
  final String trainName;
  final String? trainType;
  final String? officialLivery;
  final int totalCoaches;
  final List<CoachInfo> coaches;
  final String? stationCode;
  final String? stationName;
  final String? enginePosition;
  final Map<String, dynamic>? blueprints;

  /// Insertion-ordered map of `stationCode -> stop data` (LinkedHashMap).
  /// Order matches the API payload.
  final Map<String, StationCoachStop> stationStops;
  final List<TrainLeg> legs;
  final Map<String, dynamic> sourceStation;
  final Map<String, dynamic> destinationStation;

  TrainFormation({
    required this.trainNumber,
    required this.trainName,
    this.trainType,
    this.officialLivery,
    required this.totalCoaches,
    required this.coaches,
    this.stationCode,
    this.stationName,
    this.enginePosition,
    this.blueprints,
    required this.stationStops,
    required this.legs,
    required this.sourceStation,
    required this.destinationStation,
  });

  factory TrainFormation.fromRailRadar(
    Map<String, dynamic> data,
    String number,
  ) {
    final trainMap = data['train'] is Map
        ? Map<String, dynamic>.from(data['train'] as Map)
        : const <String, dynamic>{};

    final stationMap = data['atStation'] is Map
        ? Map<String, dynamic>.from(data['atStation'] as Map)
        : (data['station'] is Map
              ? Map<String, dynamic>.from(data['station'] as Map)
              : const <String, dynamic>{});

    final blueprintsMap = data['blueprints'] is Map
        ? Map<String, dynamic>.from(data['blueprints'] as Map)
        : null;

    final sourceMap = data['sourceStation'] is Map
        ? Map<String, dynamic>.from(data['sourceStation'] as Map)
        : const <String, dynamic>{};

    final destMap = data['destinationStation'] is Map
        ? Map<String, dynamic>.from(data['destinationStation'] as Map)
        : const <String, dynamic>{};

    final raw =
        (data['rake'] ??
                data['coaches'] ??
                data['composition'] ??
                data['coachPositionList'] ??
                data['coachList'] ??
                [])
            as List?;

    final coaches = <CoachInfo>[];
    if (raw != null) {
      for (var i = 0; i < raw.length; i++) {
        final item = raw[i];
        if (item is Map) {
          coaches.add(CoachInfo.fromMap(Map<String, dynamic>.from(item), i));
        } else if (item is String) {
          coaches.add(CoachInfo.fromCode(item, i + 1));
        }
      }
    }
    coaches.sort((a, b) => a.position.compareTo(b.position));

    // ── Parse legs ────────────────────────────────────────────────
    final legsRaw = (data['legs'] ?? []) as List?;
    final legs = <TrainLeg>[];
    if (legsRaw != null) {
      for (var l in legsRaw) {
        if (l is Map) {
          final lMap = Map<String, dynamic>.from(l);
          final coachListRaw = (lMap['coaches'] ?? []) as List?;
          final legCoaches = <CoachInfo>[];
          if (coachListRaw != null) {
            for (var ci = 0; ci < coachListRaw.length; ci++) {
              if (coachListRaw[ci] is Map) {
                legCoaches.add(
                  CoachInfo.fromMap(
                    Map<String, dynamic>.from(coachListRaw[ci]),
                    ci,
                  ),
                );
              }
            }
          }
          legCoaches.sort((a, b) => a.position.compareTo(b.position));
          legs.add(
            TrainLeg(
              legIndex: (lMap['legIndex'] as num?)?.toInt() ?? 0,
              fromStation: lMap['fromStation']?.toString() ?? '',
              toStation: lMap['toStation']?.toString() ?? '',
              fromStationName: lMap['fromStationName']?.toString() ?? '',
              toStationName: lMap['toStationName']?.toString() ?? '',
              isReversed: lMap['isReversed'] == true,
              reversalStation: lMap['reversalStation']?.toString(),
              coaches: legCoaches,
            ),
          );
        }
      }
    }

    // ── Parse stationVariations.stops (preserving API order) ──────
    final stationVars = data['stationVariations'] is Map
        ? data['stationVariations'] as Map
        : null;
    final stopsMapRaw = stationVars != null && stationVars['stops'] is Map
        ? stationVars['stops'] as Map
        : null;

    final stationStops = <String, StationCoachStop>{};
    if (stopsMapRaw != null) {
      stopsMapRaw.forEach((key, val) {
        if (val is Map) {
          final vMap = Map<String, dynamic>.from(val);
          final cListRaw = (vMap['coaches'] ?? []) as List?;
          final cList = <CoachInfo>[];
          if (cListRaw != null) {
            for (var ci = 0; ci < cListRaw.length; ci++) {
              if (cListRaw[ci] is Map) {
                cList.add(
                  CoachInfo.fromMap(
                    Map<String, dynamic>.from(cListRaw[ci]),
                    ci,
                  ),
                );
              }
            }
          }
          cList.sort((a, b) => a.position.compareTo(b.position));
          stationStops[key.toString()] = StationCoachStop(
            stationCode: vMap['stationCode']?.toString() ?? key.toString(),
            stationName: vMap['stationName']?.toString() ?? '',
            platform: vMap['platform']?.toString(),
            reversal: vMap['reversal'] == true,
            formation: vMap['formation']?.toString(),
            coaches: cList,
          );
        }
      });
    }

    final total = (data['totalCoaches'] as num?)?.toInt() ?? coaches.length;
    final rawTrainType = trainMap['type'];
    final trainType = rawTrainType is Map
        ? rawTrainType['name'] ?? rawTrainType['type']
        : rawTrainType;

    return TrainFormation(
      trainNumber: (trainMap['number'] ?? data['trainNumber'] ?? number)
          .toString(),
      trainName: (trainMap['name'] ?? data['trainName'] ?? '').toString(),
      trainType:
          (trainType ??
                  trainMap['trainType'] ??
                  data['trainType'] ??
                  data['trainCategory'] ??
                  data['type'])
              ?.toString(),
      officialLivery:
          (trainMap['officialLivery'] ??
                  trainMap['livery'] ??
                  trainMap['liveryName'] ??
                  trainMap['coachLivery'] ??
                  trainMap['exteriorColor'] ??
                  data['officialLivery'] ??
                  data['coachLivery'] ??
                  data['liveryName'] ??
                  data['livery'] ??
                  data['exteriorColor'])
              ?.toString(),
      totalCoaches: total,
      coaches: coaches,
      stationCode:
          stationMap['code']?.toString() ?? data['stationCode']?.toString(),
      stationName:
          stationMap['name']?.toString() ?? data['stationName']?.toString(),
      enginePosition: data['enginePosition']?.toString(),
      blueprints: blueprintsMap,
      stationStops: stationStops,
      legs: legs,
      sourceStation: sourceMap,
      destinationStation: destMap,
    );
  }

  factory TrainFormation.parse(Map<String, dynamic> data, String number) {
    return TrainFormation.fromRailRadar(data, number);
  }

  Map<String, int> get compositionByClass {
    final out = <String, int>{};
    for (final c in coaches) {
      out[c.category] = (out[c.category] ?? 0) + 1;
    }
    return out;
  }

  CoachInfo? findByCode(String code) {
    final target = code.toUpperCase();
    for (final c in coaches) {
      if (c.code.toUpperCase() == target) return c;
    }
    return null;
  }

  @override
  String toString() =>
      'TrainFormation($trainNumber, $totalCoaches coaches, stops: ${stationStops.length}, legs: ${legs.length})';
}
