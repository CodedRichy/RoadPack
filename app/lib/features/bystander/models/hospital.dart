/// Facility class, mirroring `hospitals.type` in migration 00008.
enum HospitalType {
  phc('phc', 'Primary Health Centre'),
  chc('chc', 'Community Health Centre'),
  district('district', 'District Hospital'),
  medicalCollege('medical_college', 'Medical College'),
  private('private', 'Private Hospital');

  const HospitalType(this.value, this.label);

  final String value;
  final String label;

  static HospitalType fromValue(String? v) =>
      HospitalType.values.firstWhere((t) => t.value == v, orElse: () => phc);
}

/// A row of the `hospitals` table, cached on device for offline lookup.
class Hospital {
  const Hospital({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
    required this.type,
    this.address,
    this.phones = const [],
    this.traumaLevel,
    this.hasEmergency = true,
    this.district,
    this.verifiedAt,
    this.source,
  });

  final String id;
  final String name;
  final double lat;
  final double lng;
  final HospitalType type;
  final String? address;
  final List<String> phones;
  final String? traumaLevel;
  final bool hasEmergency;
  final String? district;

  /// Null until a human has checked this row on the ground (FR-111/FR-114).
  /// The UI must say "unverified" whenever this is null. Getting a bystander
  /// to the wrong casualty department is worse than showing no hospital.
  final DateTime? verifiedAt;

  final String? source;

  bool get isVerified => verifiedAt != null;

  factory Hospital.fromJson(Map<String, dynamic> json) {
    final loc = json['location'];
    double coord(String flat, String nested) {
      final direct = json[flat];
      if (direct is num) return direct.toDouble();
      if (loc is Map && loc[nested] is num) return (loc[nested] as num).toDouble();
      return 0;
    }

    return Hospital(
      id: json['id'] as String,
      name: json['name'] as String,
      lat: coord('lat', 'lat'),
      lng: coord('lng', 'lng'),
      type: HospitalType.fromValue(json['type'] as String?),
      address: json['address'] as String?,
      phones: (json['phone'] as List?)?.map((e) => '$e').toList() ?? const [],
      traumaLevel: json['trauma_level'] as String?,
      hasEmergency: json['has_emergency'] as bool? ?? true,
      district: json['district'] as String?,
      verifiedAt: json['verified_at'] == null
          ? null
          : DateTime.parse(json['verified_at'] as String),
      source: json['source'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'lat': lat,
    'lng': lng,
    'type': type.value,
    'address': address,
    'phone': phones,
    'trauma_level': traumaLevel,
    'has_emergency': hasEmergency,
    'district': district,
    'verified_at': verifiedAt?.toIso8601String(),
    'source': source,
  };
}

/// A hospital plus its distance from the incident.
class RankedHospital {
  const RankedHospital(this.hospital, this.distanceMeters);

  final Hospital hospital;
  final double distanceMeters;

  /// Straight-line distance, and labelled as such -- this is not road
  /// distance and must never be shown as an ETA.
  String get distanceLabel => distanceMeters < 1000
      ? '${distanceMeters.round()} m'
      : '${(distanceMeters / 1000).toStringAsFixed(1)} km';
}
