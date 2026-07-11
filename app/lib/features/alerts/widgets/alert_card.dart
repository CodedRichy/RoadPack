import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/alert_notification.dart';

class AlertCard extends StatelessWidget {
  const AlertCard({required this.alert, super.key});

  final AlertNotification alert;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: alert.acknowledged ? null : Colors.red.shade900,
      child: ListTile(
        leading: Icon(
          alert.acknowledged ? Icons.check_circle : Icons.warning,
          color: alert.acknowledged ? Colors.green : Colors.red,
        ),
        title: Text('${alert.victimName} - Emergency'),
        subtitle: Text(
          alert.acknowledged ? 'Acknowledged' : 'Tap to view and acknowledge',
        ),
        onTap: () => context.push('/alerts/${alert.incidentId}'),
      ),
    );
  }
}
