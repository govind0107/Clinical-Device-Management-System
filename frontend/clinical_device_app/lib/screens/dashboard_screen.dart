import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/models.dart';
import '../core/role_config.dart';
import '../providers/auth_provider.dart';
import '../providers/data_providers.dart';
import '../services/api_client.dart';
import '../services/telemetry_hub_service.dart';
import '../theme/app_theme.dart';
import '../widgets/state_views.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(hubConnectionProvider);
    final devicesAsync = ref.watch(devicesProvider);
    final alertsAsync = ref.watch(activeAlertsProvider);
    final auth = ref.watch(authProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Device Dashboard'),
        actions: [
          if (RoleConfig.canManageDevices(auth?.role ?? ''))
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              tooltip: 'Register device',
              onPressed: () => _showAddDeviceDialog(context, ref),
            ),
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => context.push('/alerts'),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) context.go('/login');
            },
          ),
        ],
      ),
      body: devicesAsync.when(
        loading: () => const LoadingView(message: 'Loading devices...'),
        error: (e, _) => ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(devicesProvider),
        ),
        data: (devices) {
          if (devices.isEmpty) {
            return const EmptyView(message: 'No devices registered.');
          }

          final online = devices.where((d) => d.status == 'Online').length;
          final alertCount = alertsAsync.valueOrNull?.length ?? 0;

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(devicesProvider);
              ref.invalidate(activeAlertsProvider);
            },
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Welcome, ${auth?.username ?? ''}',
                            style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 12),
                        alertsAsync.when(
                          data: (alerts) => alerts.isEmpty
                              ? const SizedBox.shrink()
                              : MaterialBanner(
                                  content: Text(
                                      '${alerts.length} active alert(s) require attention'),
                                  leading: const Icon(Icons.warning_amber,
                                      color: AppTheme.clinicalAmber),
                                  actions: [
                                    TextButton(
                                      onPressed: () => context.push('/alerts'),
                                      child: const Text('VIEW'),
                                    ),
                                  ],
                                ),
                          loading: () => const SizedBox.shrink(),
                          error: (_, __) => const SizedBox.shrink(),
                        ),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            _KpiCard('Total', '${devices.length}', Icons.devices),
                            _KpiCard('Online', '$online', Icons.wifi, AppTheme.clinicalGreen),
                            _KpiCard('Alerts', '$alertCount', Icons.warning,
                                AppTheme.clinicalRed),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverLayoutBuilder(
                    builder: (context, constraints) {
                      final width = MediaQuery.sizeOf(context).width;
                      final cols = width > 900 ? 3 : (width > 600 ? 2 : 1);
                      return SliverGrid(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: cols,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 1.6,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, i) => _DeviceCard(device: devices[i]),
                          childCount: devices.length,
                        ),
                      );
                    },
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 80)),
              ],
            ),
          );
        },
      ),
    );
  }

  static Future<void> _showAddDeviceDialog(BuildContext context, WidgetRef ref) async {
    final serial = TextEditingController();
    final model = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Register device'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: serial, decoration: const InputDecoration(labelText: 'Serial')),
            TextField(controller: model, decoration: const InputDecoration(labelText: 'Model')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              await ref.read(apiServiceProvider).createDevice({
                'serialNumber': serial.text,
                'model': model.text,
              });
              ref.invalidate(devicesProvider);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard(this.label, this.value, this.icon, [this.color]);
  final String label;
  final String value;
  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 140,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color),
              const SizedBox(height: 8),
              Text(value, style: Theme.of(context).textTheme.headlineSmall),
              Text(label),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeviceCard extends StatelessWidget {
  const _DeviceCard({required this.device});
  final DeviceModel device;

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.statusColor(device.status);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/devices/${device.deviceId}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.circle, size: 12, color: color),
                  const SizedBox(width: 8),
                  Text(device.status, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
                ],
              ),
              const Spacer(),
              Text(device.serialNumber, style: Theme.of(context).textTheme.titleMedium),
              Text(device.model, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}
