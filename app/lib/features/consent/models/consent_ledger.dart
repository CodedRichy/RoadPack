import 'consent_record.dart';
import 'consent_type.dart';

/// The user's consent state as this device currently understands it.
///
/// The important part of this type is [isKnown]. Every consent question the
/// app asks has three possible answers — yes, no, and *we could not find
/// out* — and the third one must behave like no. A ledger built from a
/// failed fetch, an expired session, or an offline start returns
/// [ConsentLedger.unknown], and every query on it answers "not granted".
class ConsentLedger {
  const ConsentLedger(List<ConsentRecord> records)
    : _records = records,
      isKnown = true;

  /// The consent state could not be read. Treated as nothing granted.
  const ConsentLedger.unknown() : _records = const [], isKnown = false;

  final List<ConsentRecord> _records;

  /// False when the consent state could not be read from the server.
  final bool isKnown;

  /// Every record, newest grant first. Empty when [isKnown] is false — an
  /// unknown ledger has no history to show, only a warning to show.
  List<ConsentRecord> get records {
    final sorted = [..._records]
      ..sort((a, b) => b.grantedAt.compareTo(a.grantedAt));
    return List.unmodifiable(sorted);
  }

  /// The live consent of [type], or `null` if there is none. Always `null`
  /// when the ledger is unknown.
  ConsentRecord? activeFor(ConsentType type) {
    if (!isKnown) return null;
    ConsentRecord? best;
    for (final r in _records) {
      if (r.type != type || !r.isActive) continue;
      if (best == null || r.grantedAt.isAfter(best.grantedAt)) best = r;
    }
    return best;
  }

  /// The single question the rest of the app should ask. Fails closed.
  bool isGranted(ConsentType type) => activeFor(type) != null;

  /// History for [type], including withdrawn records, newest first.
  List<ConsentRecord> historyFor(ConsentType type) =>
      records.where((r) => r.type == type).toList(growable: false);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConsentLedger &&
          runtimeType == other.runtimeType &&
          isKnown == other.isKnown &&
          _listEquals(records, other.records);

  @override
  int get hashCode => Object.hash(isKnown, _records.length);

  static bool _listEquals(List<ConsentRecord> a, List<ConsentRecord> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  String toString() =>
      'ConsentLedger(isKnown: $isKnown, records: ${_records.length})';
}
