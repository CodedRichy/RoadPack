/// Pack Mode enums.
///
/// Every value here mirrors a CHECK constraint in
/// `backend/supabase/migrations/00017_create_pack_rides.sql`. The database is
/// the source of truth; if a constraint changes, this file changes with it.
library;

/// A member's role in the ride.
enum PackRole {
  leader('leader', 'Leader'),
  sweep('sweep', 'Sweep'),
  rider('rider', 'Rider');

  const PackRole(this.wire, this.label);

  final String wire;
  final String label;

  static PackRole fromWire(String value) =>
      PackRole.values.firstWhere((r) => r.wire == value, orElse: () => rider);
}

/// Lifecycle of the ride itself. draft -> active -> ended, nothing else.
enum PackRideStatus {
  draft('draft', 'Not started'),
  active('active', 'Riding'),
  ended('ended', 'Ended');

  const PackRideStatus(this.wire, this.label);

  final String wire;
  final String label;

  static PackRideStatus fromWire(String value) => PackRideStatus.values
      .firstWhere((s) => s.wire == value, orElse: () => draft);
}

/// A member's status.
///
/// The first block is rider-settable. The last three are written only by the
/// server (crash detection, the tick's stall detector, the heartbeat) and are
/// rejected from the client write path — [userSettable] is what the status
/// picker filters on, so an automatic value can never be faked by a tap.
enum PackStatus {
  riding('riding', 'Riding', userSettable: true, precedence: 0),
  refueling('refueling', 'Fuel', userSettable: true, precedence: 1),
  takingBreak('break', 'Break', userSettable: true, precedence: 1),
  wrongTurn('wrong_turn', 'Wrong turn', userSettable: true, precedence: 1),
  waiting('waiting', 'Waiting', userSettable: true, precedence: 1),
  stopped('stopped', 'Stopped', userSettable: true, precedence: 1),
  done('done', 'Done', userSettable: true, precedence: 1),

  /// Stationary past the threshold with no explanation. Not an impact.
  unexplainedStop(
    'unexplained_stop',
    'Stopped, unexplained',
    userSettable: false,
    precedence: 2,
  ),

  /// The phone stopped reporting. A dead zone, not a stop.
  unreachable('unreachable', 'No signal', userSettable: false, precedence: 3),

  /// Crash detection fired. The only pack state allowed the emergency tier.
  possibleIncident(
    'possible_incident',
    'Possible incident',
    userSettable: false,
    precedence: 4,
  );

  const PackStatus(
    this.wire,
    this.label, {
    required this.userSettable,
    required this.precedence,
  });

  final String wire;
  final String label;

  /// False for the automatic-only values. The picker must never offer these.
  final bool userSettable;

  /// Highest wins: possible_incident > unreachable > unexplained_stop >
  /// manual status > riding.
  final int precedence;

  bool get isAutomaticOnly => !userSettable;

  static PackStatus fromWire(String value) => PackStatus.values.firstWhere(
    (s) => s.wire == value,
    orElse: () => riding,
  );

  /// The values a rider may pick, in picker order.
  static List<PackStatus> get settable =>
      PackStatus.values.where((s) => s.userSettable).toList(growable: false);
}

/// What the server decided this member's gap cell should show.
///
/// This is computed in `fn_pack_member_gaps` and is the single source of truth
/// for whether a number may be rendered at all. The client does not re-derive
/// it: two implementations of "is this stale" is one implementation too many,
/// and the one that drifts is the one that shows a dead rider as live.
enum PackDisplayState {
  ok('ok'),
  estimated('estimated'),
  stale('stale'),
  offRoute('off_route'),
  locating('locating');

  const PackDisplayState(this.wire);

  final String wire;

  /// True when a numeric gap must NOT be rendered.
  ///
  /// A gap number is a claim about where someone is right now. Off route it is
  /// meaningless (the chainage no longer describes them), stale it is a lie
  /// (it describes where they were), and before the first fix there is nothing
  /// to describe.
  bool get suppressesGap =>
      this == offRoute || this == stale || this == locating;

  static PackDisplayState fromWire(String value) => PackDisplayState.values
      .firstWhere((s) => s.wire == value, orElse: () => locating);
}
