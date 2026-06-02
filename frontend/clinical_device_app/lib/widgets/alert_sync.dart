import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/data_providers.dart';
import '../services/local_db.dart';
import '../services/telemetry_hub_service.dart';

/// Subscribes to SignalR alerts and refreshes UI (assignment demo flow).
class AlertSync extends ConsumerStatefulWidget {
  const AlertSync({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<AlertSync> createState() => _AlertSyncState();
}

class _AlertSyncState extends ConsumerState<AlertSync> {
  StreamSubscription? _sub;
  static final Set<String> _processedAlertIds = {};

  @override
  void initState() {
    super.initState();
    Future.microtask(_bind);
  }

  Future<void> _bind() async {
    await ref.read(hubConnectionProvider.future);
    if (!mounted) return;
    _sub?.cancel();
    _sub = ref.read(telemetryHubProvider).alertStream.listen((alert) async {
      if (_processedAlertIds.contains(alert.alertId)) return;
      _processedAlertIds.add(alert.alertId);

      await LocalDb.cacheAlert(alert);
      if (!mounted) return;
      ref.invalidate(alertsProvider);
      ref.invalidate(activeAlertsProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Alert: ${alert.message}'),
          backgroundColor: Colors.red.shade800,
        ),
      );
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
