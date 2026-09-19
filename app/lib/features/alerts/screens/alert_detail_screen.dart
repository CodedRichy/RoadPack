import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../l10n/l10n.dart';
import '../providers/alerts_provider.dart';
import '../services/alert_service.dart';

class AlertDetailScreen extends ConsumerWidget {
  const AlertDetailScreen({required this.incidentId, super.key});

  final String incidentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final alerts = ref.watch(alertsProvider);
    final alert = alerts.where((a) => a.incidentId == incidentId).firstOrNull;

    if (alert == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.alertTitle)),
        body: Center(child: Text(l10n.alertNotFound)),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.alertDetailTitle),
        backgroundColor: Colors.red,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.alertVictimHeadline(alert.victimName),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.alertLocationLine(
                alert.lat.toStringAsFixed(4),
                alert.lng.toStringAsFixed(4),
              ),
            ),
            const SizedBox(height: 8),
            Text(l10n.alertTimeLine(alert.receivedAt)),
            const SizedBox(height: 24),
            if (!alert.acknowledged)
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    try {
                      await ref
                          .read(alertServiceProvider)
                          ?.acknowledgeIncident(incidentId);
                      ref
                          .read(alertsProvider.notifier)
                          .markAcknowledged(incidentId);
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(
                          SnackBar(content: Text(l10n.commonError('$e'))),
                        );
                      }
                    }
                  },
                  child: Text(
                    l10n.alertAcknowledge,
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
              ),
            if (alert.acknowledged)
              Chip(
                label: Text(l10n.alertAcknowledged),
                backgroundColor: Colors.green,
                labelStyle: const TextStyle(color: Colors.white),
              ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              icon: const Icon(Icons.phone),
              label: Text(l10n.commonCall112),
              onPressed: () => launchUrl(Uri.parse('tel:112')),
            ),
            const SizedBox(height: 8),
            if (alert.victimPhone.isNotEmpty)
              OutlinedButton.icon(
                icon: const Icon(Icons.phone),
                label: Text(l10n.alertCallPerson(alert.victimName)),
                onPressed: () =>
                    launchUrl(Uri.parse('tel:${alert.victimPhone}')),
              ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.map),
              label: Text(l10n.alertOpenInMaps),
              onPressed: () => launchUrl(
                Uri.parse(
                  'https://maps.google.com/?q=${alert.lat},${alert.lng}',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
