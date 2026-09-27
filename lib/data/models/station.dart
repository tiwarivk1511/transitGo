class Station {
  final String code;
  final String name;
  final String? city;
  final String? state;

  /// Optional metadata (RailRadar provides these).
  final double? latitude;
  final double? longitude;
  final String? zone;
  final String? division;
  final String? address;
  final int? elevation;
  final String? type; // 'junction' | 'terminal' | 'halt' | ...

  const Station({
    required this.code,
    required this.name,
    this.city,
    this.state,
    this.latitude,
    this.longitude,
    this.zone,
    this.division,
    this.address,
    this.elevation,
    this.type,
  });

  // ═══════════════════════════════════════════════════════════════════
  // Generic JSON parser — works for NTES, RailRadar and local list
  // ═══════════════════════════════════════════════════════════════════
  factory Station.fromJson(Map<String, dynamic> json) => Station(
    code: (json['code'] ??
        json['stationCode'] ??
        json['stnCode'] ??
        '')
        .toString(),
    name: (json['name'] ??
        json['stationName'] ??
        json['stnName'] ??
        '')
        .toString(),
    city: json['city']?.toString() ?? json['cityName']?.toString(),
    state: json['state']?.toString() ?? json['stateName']?.toString(),
    latitude: _dbl(json['latitude'] ?? json['lat']),
    longitude: _dbl(json['longitude'] ?? json['lng']),
    zone: json['zone']?.toString() ?? json['zoneCode']?.toString(),
    division: json['division']?.toString(),
    address: json['address']?.toString(),
    elevation: _int(json['elevation']),
    type: json['type']?.toString() ?? json['stationType']?.toString(),
  );

  static double? _dbl(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  static int? _int(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  Map<String, dynamic> toJson() => {
    'code': code,
    'name': name,
    if (city != null) 'city': city,
    if (state != null) 'state': state,
    if (latitude != null) 'latitude': latitude,
    if (longitude != null) 'longitude': longitude,
    if (zone != null) 'zone': zone,
    if (division != null) 'division': division,
    if (address != null) 'address': address,
    if (elevation != null) 'elevation': elevation,
    if (type != null) 'type': type,
  };

  bool get hasCoordinates => latitude != null && longitude != null;

  @override
  String toString() => '$name ($code)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is Station && code.toLowerCase() == other.code.toLowerCase();

  @override
  int get hashCode => code.toLowerCase().hashCode;
}