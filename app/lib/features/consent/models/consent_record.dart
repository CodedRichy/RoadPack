import 'consent_type.dart';

/// One row of the `consents` ledger (migration 00009).
///
/// The table is append-only by design: there is no DELETE policy, and a
/// trigger rejects any UPDATE that touches a column other than
/// `revoked_at`. This class mirrors that shape — it is immutable, and the
/// only state change it models is [revokedAt] being set once. Nothing here
/// offers a way to rewrite history, because a consent record you can edit
/// is not evidence of anything.
class ConsentRecord {
  const ConsentRecord({
    required this.id,
    required this.userId,
    required this.type,
    required this.grantedAt,
    this.grantedBy,
    this.method,
    this.revokedAt,
    this.version,
  });

  /// Parses a `consents` row, or returns `null` if the row cannot be
  /// understood (unknown `consent_type`, missing id, unparseable date).
  ///
  /// Returning `null` rather than throwing keeps one bad row from making
  /// the whole ledger unreadable — but the dropped row is never treated as
  /// a grant, so dropping it can only ever tighten access, never loosen it.
  static ConsentRecord? tryFromJson(Map<String, dynamic> json) {
    final type = ConsentType.fromWire(json['consent_type'] as String?);
    final id = json['id'] as String?;
    final userId = json['user_id'] as String?;
    final grantedAtRaw = json['granted_at'] as String?;
    if (type == null || id == null || userId == null || grantedAtRaw == null) {
      return null;
    }
    final grantedAt = DateTime.tryParse(grantedAtRaw);
    if (grantedAt == null) return null;

    final revokedAtRaw = json['revoked_at'] as String?;
    return ConsentRecord(
      id: id,
      userId: userId,
      type: type,
      grantedAt: grantedAt,
      grantedBy: json['granted_by'] as String?,
      method: ConsentMethod.fromWire(json['method'] as String?),
      revokedAt: revokedAtRaw == null ? null : DateTime.tryParse(revokedAtRaw),
      version: json['version'] as String?,
    );
  }

  final String id;
  final String userId;
  final ConsentType type;

  /// The user id that gave the consent. Equal to [userId] for a consent the
  /// user gave themselves; the parent's id for a `parental` consent.
  final String? grantedBy;

  final ConsentMethod? method;
  final DateTime grantedAt;
  final DateTime? revokedAt;

  /// Version of the consent wording the user actually saw. Without it the
  /// record proves someone tapped yes, but not to what.
  final String? version;

  /// A consent is live only until it is withdrawn. A record with a
  /// [revokedAt] is history, not permission.
  bool get isActive => revokedAt == null;

  /// Returns the same record marked withdrawn. Every other field is carried
  /// through untouched, which is exactly what the database trigger
  /// `consents_restrict_update` enforces server-side.
  ConsentRecord revoked(DateTime at) => ConsentRecord(
    id: id,
    userId: userId,
    type: type,
    grantedAt: grantedAt,
    grantedBy: grantedBy,
    method: method,
    revokedAt: at,
    version: version,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConsentRecord &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          userId == other.userId &&
          type == other.type &&
          grantedBy == other.grantedBy &&
          method == other.method &&
          grantedAt == other.grantedAt &&
          revokedAt == other.revokedAt &&
          version == other.version;

  @override
  int get hashCode => Object.hash(
    id,
    userId,
    type,
    grantedBy,
    method,
    grantedAt,
    revokedAt,
    version,
  );

  @override
  String toString() =>
      'ConsentRecord(id: $id, type: ${type.wireValue}, '
      'grantedBy: $grantedBy, method: ${method?.wireValue}, '
      'grantedAt: $grantedAt, revokedAt: $revokedAt, version: $version)';
}
