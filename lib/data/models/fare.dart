class TrainFareData {
  final String trainNumber;
  final String source;
  final String destination;
  final String journeyDate;
  final String classCode;
  final int totalFare;
  final int baseFare;

  /// Optional breakdown — populated when the API returns it.
  final int? reservationCharge;
  final int? superfastCharge;
  final int? cateringCharge;
  final int? serviceTax;
  final int? tatkalCharge;
  final int? otherCharges;
  final String? quota;

  TrainFareData({
    required this.trainNumber,
    required this.source,
    required this.destination,
    required this.journeyDate,
    required this.classCode,
    required this.totalFare,
    required this.baseFare,
    this.reservationCharge,
    this.superfastCharge,
    this.cateringCharge,
    this.serviceTax,
    this.tatkalCharge,
    this.otherCharges,
    this.quota,
  });

  // ═══════════════════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════════════════
  static int _int(dynamic v, [int fallback = 0]) {
    if (v == null) return fallback;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? fallback;
  }

  static int? _intOrNull(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  // ═══════════════════════════════════════════════════════════════════
  // NTES PARSER (legacy)
  // ═══════════════════════════════════════════════════════════════════
  factory TrainFareData.fromNtes(
      Map<String, dynamic> data,
      String train,
      String src,
      String dst,
      String date,
      String cls,
      ) {
    final total = _int(data['totalFare']) != 0
        ? _int(data['totalFare'])
        : _int(data['fare']);

    return TrainFareData(
      trainNumber: train,
      source: src,
      destination: dst,
      journeyDate: date,
      classCode: cls,
      totalFare: total,
      baseFare: _int(data['baseFare'], total),
      reservationCharge: _intOrNull(data['reservationCharge']),
      superfastCharge: _intOrNull(data['superfastCharge']),
      cateringCharge: _intOrNull(data['cateringCharge']),
      serviceTax: _intOrNull(data['serviceTax'] ?? data['gst']),
      tatkalCharge: _intOrNull(data['tatkalCharge']),
      otherCharges: _intOrNull(data['otherCharges']),
      quota: data['quota']?.toString(),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // RAILRADAR PARSER
  //
  // Handles shapes like:
  //   { "train": {...}, "from": {...}, "to": {...},
  //     "fare": { "total": 1250, "baseFare": 980, ... } }
  //   or flat: { "totalFare": ..., "baseFare": ... }
  // ═══════════════════════════════════════════════════════════════════
  factory TrainFareData.fromRailRadar(
      Map<String, dynamic> data, {
        required String train,
        required String from,
        required String to,
        required String date,
        required String classCode,
      }) {
    final fareMap = data['fare'] is Map
        ? Map<String, dynamic>.from(data['fare'] as Map)
        : data;

    final fromMap =
    data['from'] is Map ? Map<String, dynamic>.from(data['from'] as Map) : const {};
    final toMap =
    data['to'] is Map ? Map<String, dynamic>.from(data['to'] as Map) : const {};

    final total = _int(fareMap['total']) != 0
        ? _int(fareMap['total'])
        : (_int(fareMap['totalFare']) != 0
        ? _int(fareMap['totalFare'])
        : _int(fareMap['amount']));

    final base = _int(fareMap['baseFare']) != 0
        ? _int(fareMap['baseFare'])
        : (_int(fareMap['base']) != 0 ? _int(fareMap['base']) : total);

    return TrainFareData(
      trainNumber: train,
      source: fromMap['code']?.toString() ?? from,
      destination: toMap['code']?.toString() ?? to,
      journeyDate: data['journeyDate']?.toString() ?? date,
      classCode:
      (data['class'] ?? classCode).toString().toUpperCase(),
      totalFare: total,
      baseFare: base,
      reservationCharge: _intOrNull(fareMap['reservationCharge']),
      superfastCharge: _intOrNull(fareMap['superfastCharge']),
      cateringCharge: _intOrNull(fareMap['cateringCharge']),
      serviceTax: _intOrNull(fareMap['serviceTax'] ?? fareMap['gst']),
      tatkalCharge: _intOrNull(fareMap['tatkalCharge']),
      otherCharges: _intOrNull(fareMap['otherCharges']),
      quota: data['quota']?.toString(),
    );
  }

  /// Auto-detect: RailRadar responses typically nest fare under `fare`
  /// or contain `from`/`to` maps.
  factory TrainFareData.parse(
      Map<String, dynamic> data, {
        required String train,
        required String from,
        required String to,
        required String date,
        required String classCode,
      }) {
    if (data['fare'] is Map ||
        data['from'] is Map ||
        data['total'] != null ||
        data['amount'] != null) {
      return TrainFareData.fromRailRadar(
        data,
        train: train,
        from: from,
        to: to,
        date: date,
        classCode: classCode,
      );
    }
    return TrainFareData.fromNtes(
        data, train, from, to, date, classCode);
  }

  bool get hasBreakdown =>
      reservationCharge != null ||
          superfastCharge != null ||
          cateringCharge != null ||
          serviceTax != null ||
          tatkalCharge != null ||
          otherCharges != null;

  @override
  String toString() =>
      'TrainFareData($trainNumber, $classCode, ₹$totalFare)';
}