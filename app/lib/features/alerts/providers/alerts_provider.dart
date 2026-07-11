import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/alert_notification.dart';

final alertsProvider =
    StateNotifierProvider<AlertsNotifier, List<AlertNotification>>(
      (ref) => AlertsNotifier(),
    );

class AlertsNotifier extends StateNotifier<List<AlertNotification>> {
  AlertsNotifier() : super([]);

  void addAlert(AlertNotification alert) {
    state = [alert, ...state];
  }

  void markAcknowledged(String incidentId) {
    state = [
      for (final a in state)
        if (a.incidentId == incidentId) a.copyWith(acknowledged: true) else a,
    ];
  }
}
