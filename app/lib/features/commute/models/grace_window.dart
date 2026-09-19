/// How long after the expected arrival the app waits before it asks the rider
/// anything at all (FR-042).
///
/// Three values, not a slider. A slider invites a rider to dial the window out
/// to two hours to stop the app nagging, which quietly turns the protection
/// off; three coarse steps keep the worst case bounded at 30 minutes.
///
/// The value is stored per user in `users.non_arrival_delay_min` (migration
/// 00016) and read by the `non-arrival-check` edge function, which defaults a
/// null column to 15. Anything the server would not honour must not be
/// offerable here, which is why [fromMinutes] collapses unknown values back to
/// the default rather than inventing a fourth option.
enum GraceWindow {
  ten(10),
  fifteen(15),
  thirty(30);

  const GraceWindow(this.minutes);

  /// Minutes past expected arrival before the rider is asked to check in.
  final int minutes;

  Duration get duration => Duration(minutes: minutes);

  /// The server-side default (`non_arrival_delay_min INT DEFAULT 15`).
  static const GraceWindow defaultWindow = GraceWindow.fifteen;

  /// Reads a stored delay. A null column, a legacy value, or anything the
  /// server would not have written falls back to [defaultWindow] — a rider
  /// with a corrupt setting must still be watched, just on the default terms.
  static GraceWindow fromMinutes(int? minutes) {
    for (final window in values) {
      if (window.minutes == minutes) return window;
    }
    return defaultWindow;
  }

  String get label => '$minutes min';

  /// Spoken form for the settings row and the countdown's explanation.
  String get description => switch (this) {
    GraceWindow.ten => '10 minutes late',
    GraceWindow.fifteen => '15 minutes late',
    GraceWindow.thirty => '30 minutes late',
  };
}
