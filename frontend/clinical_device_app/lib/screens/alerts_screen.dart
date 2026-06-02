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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Alarm Log Stream')),
      body: alertsAsync.when(
        loading: () => const LoadingView(message: 'Connecting to real-time alarm stream...'),
        error: (e, _) => ErrorView(
          message: e.toString(),
          onRetry: () {
            ref.invalidate(alertsProvider);
            ref.invalidate(activeAlertsProvider);
          },
        ),
        data: (alerts) {
          if (alerts.isEmpty) {
            return const EmptyView(
              message: 'No medical alerts recorded on the system.',
              icon: Icons.check_circle_outline_rounded,
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(alertsProvider);
              ref.invalidate(activeAlertsProvider);
            },
            child: ListView.builder(
              itemCount: alerts.length,
              padding: const EdgeInsets.all(20),
              itemBuilder: (context, i) {
                final a = alerts[i];
                final severityColor = AppTheme.severityColor(a.severity);
                final isPending = !a.acknowledged;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF131B2E) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isPending 
                          ? severityColor.withValues(alpha: 0.3)
                          : (isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFE2E8F0)),
                      width: 1.5,
                    ),
                    boxShadow: isPending 
                        ? AppTheme.glowShadow(severityColor, opacity: 0.08, blur: 14)
                        : [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.02),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border(
                          left: BorderSide(color: severityColor, width: 6),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Row(
                          children: [
                            // Alert Status Icon
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: severityColor.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                a.acknowledged
                                    ? Icons.check_circle_outline_rounded
                                    : Icons.warning_amber_rounded,
                                color: severityColor,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 16),
                            // Alert message details
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    a.message,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14,
                                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: severityColor.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          a.severity.toUpperCase(),
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w900,
                                            color: severityColor,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        DateFormat.MMMd().add_jm().format(a.createdAt.toLocal()),
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Action / Acknowledged status tag
                            if (a.acknowledged)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.grey.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.check_rounded, size: 12, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45)),
                                    const SizedBox(width: 4),
                                    Text(
                                      'ACKNOWLEDGED',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w900,
                                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45),
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else if (canAck)
                              Container(
                                decoration: BoxDecoration(
                                  gradient: AppTheme.primaryGradient,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: AppTheme.glowShadow(AppTheme.clinicalPrimary, opacity: 0.25, blur: 8),
                                ),
                                child: FilledButton(
                                  onPressed: () async {
                                    await ref.read(apiServiceProvider).acknowledgeAlert(a.alertId);
                                    await LocalDb.setAlertAcknowledged(a.alertId);
                                    ref.invalidate(alertsProvider);
                                    ref.invalidate(activeAlertsProvider);
                                  },
                                  style: FilledButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    backgroundColor: Colors.transparent,
                                    foregroundColor: Colors.white,
                                    shadowColor: Colors.transparent,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.check_rounded, size: 14),
                                      SizedBox(width: 4),
                                      Text('ACK', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11)),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
