import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../core/role_config.dart';
import '../providers/auth_provider.dart';
import '../providers/data_providers.dart';
import '../services/api_client.dart';
import '../services/local_db.dart';
import '../theme/app_theme.dart';
import '../widgets/state_views.dart';

class AlertsScreen extends ConsumerStatefulWidget {
  const AlertsScreen({super.key});

  @override
  ConsumerState<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends ConsumerState<AlertsScreen> {
  @override
  Widget build(BuildContext context) {
    final role = ref.watch(authProvider).valueOrNull?.role ?? '';
    final canAck = RoleConfig.canAcknowledgeAlerts(role);
    final alertsAsync = ref.watch(alertsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Alerts')),
      body: alertsAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          message: e.toString(),
          onRetry: () {
            ref.invalidate(alertsProvider);
            ref.invalidate(activeAlertsProvider);
          },
        ),
        data: (alerts) {
          if (alerts.isEmpty) {
            return const EmptyView(message: 'No alerts recorded.');
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(alertsProvider);
              ref.invalidate(activeAlertsProvider);
            },
            child: ListView.separated(
              itemCount: alerts.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final a = alerts[i];
                final color = AppTheme.severityColor(a.severity);
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: color.withValues(alpha: 0.15),
                    child: Icon(Icons.warning_amber, color: color, size: 20),
                  ),
                  title: Text(a.message),
                  subtitle: Text(
                    '${a.severity} • ${DateFormat.MMMd().add_jm().format(a.createdAt.toLocal())}',
                  ),
                  trailing: a.acknowledged
                      ? const Chip(label: Text('Ack'))
                      : canAck
                          ? TextButton(
                              onPressed: () async {
                                await ref.read(apiServiceProvider).acknowledgeAlert(a.alertId);
                                await LocalDb.setAlertAcknowledged(a.alertId);
                                ref.invalidate(alertsProvider);
                                ref.invalidate(activeAlertsProvider);
                              },
                              child: const Text('Acknowledge'),
                            )
                          : null,
                );
              },
            ),
          );
        },
      ),
    );
  }
}
