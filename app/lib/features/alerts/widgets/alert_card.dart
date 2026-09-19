import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/l10n.dart';
import '../models/alert_notification.dart';

class AlertCard extends StatelessWidget {
  const AlertCard({required this.alert, super.key});

  final AlertNotification alert;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Card(
      color: alert.acknowledged ? null : Colors.red.shade900,
      child: ListTile(
        leading: Icon(
          alert.acknowledged ? Icons.check_circle : Icons.warning,
          color: alert.acknowledged ? Colors.green : Colors.red,
        ),
        title: Text(l10n.alertCardTitle(alert.victimName)),
        subtitle: Text(
          alert.acknowledged
              ? l10n.alertAcknowledged
              : l10n.alertCardTapToView,
        ),
        onTap: () => context.push('/alerts/${alert.incidentId}'),
      ),
    );
  }
}
