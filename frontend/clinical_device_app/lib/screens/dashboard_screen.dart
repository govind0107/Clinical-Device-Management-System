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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Device Dashboard'),
        actions: [
          if (RoleConfig.canManageDevices(auth?.role ?? ''))
            IconButton(
              icon: const Icon(Icons.add_circle_outline_rounded),
              tooltip: 'Register device',
              onPressed: () => _showAddDeviceDialog(context, ref),
            ),
          IconButton(
            icon: const Icon(Icons.notifications_rounded),
            onPressed: () => context.push('/alerts'),
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Logout',
            onPressed: () async {
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) context.go('/login');
            },
          ),
        ],
      ),
      body: devicesAsync.when(
        loading: () => const LoadingView(message: 'Retrieving clinical devices...'),
        error: (e, _) => ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(devicesProvider),
        ),
        data: (devices) {
          if (devices.isEmpty) {
            return const EmptyView(message: 'No medical devices registered.');
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
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Main Welcome Header
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF131B2E) : Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFE2E8F0),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.02),
                                blurRadius: 20,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  gradient: AppTheme.primaryGradient,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: AppTheme.glowShadow(AppTheme.clinicalPrimary, opacity: 0.25, blur: 12),
                                ),
                                child: const Icon(Icons.admin_panel_settings_rounded, color: Colors.white, size: 28),
                              ),
                              const SizedBox(width: 18),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Welcome back, ${auth?.username ?? 'Clinician'}',
                                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: -0.5,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Role clearance: ${auth?.role.toUpperCase() ?? 'USER'} • Live Telemetry Connection Secure',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Critical System Alerts Stream Indicator
                        alertsAsync.when(
                          data: (alerts) {
                            if (alerts.isEmpty) return const SizedBox.shrink();
                            return Container(
                              margin: const EdgeInsets.only(bottom: 24),
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                              decoration: BoxDecoration(
                                color: AppTheme.clinicalRed.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: AppTheme.clinicalRed.withValues(alpha: 0.3), width: 1.5),
                                boxShadow: AppTheme.glowShadow(AppTheme.clinicalRed, opacity: 0.05, blur: 10),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: AppTheme.clinicalRed.withValues(alpha: 0.15),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const PulsingStatusDot(color: AppTheme.clinicalRed, size: 14),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'CRITICAL TELEMETRY ALERTS DETECTED',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w900,
                                            color: AppTheme.clinicalRed,
                                            fontSize: 13,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'There are currently $alertCount device metrics violating thresholds. Check detail streams.',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  FilledButton(
                                    onPressed: () => context.push('/alerts'),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: AppTheme.clinicalRed,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    child: const Text('DISPATCH', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                                  ),
                                ],
                              ),
                            );
                          },
                          loading: () => const SizedBox.shrink(),
                          error: (_, __) => const SizedBox.shrink(),
                        ),
                        // KPI Grid Row
                        Wrap(
                          spacing: 16,
                          runSpacing: 16,
                          children: [
                            _KpiCard(
                              label: 'Total Devices',
                              value: '${devices.length}',
                              icon: Icons.devices_other_rounded,
                              color: Theme.of(context).colorScheme.primary,
                              gradient: AppTheme.primaryGradient,
                            ),
                            _KpiCard(
                              label: 'Active Streams',
                              value: '$online',
                              icon: Icons.sensors_rounded,
                              color: AppTheme.clinicalGreen,
                              gradient: AppTheme.greenGradient,
                              isOnline: true,
                            ),
                            _KpiCard(
                              label: 'System Alerts',
                              value: '$alertCount',
                              icon: Icons.warning_amber_rounded,
                              color: AppTheme.clinicalRed,
                              gradient: AppTheme.redGradient,
                              isAlert: alertCount > 0,
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),
                        Text(
                          'Device Console Streams',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  sliver: SliverLayoutBuilder(
                    builder: (context, constraints) {
                      final width = MediaQuery.sizeOf(context).width;
                      final cols = width > 1000 ? 3 : (width > 600 ? 2 : 1);
                      return SliverGrid(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: cols,
                          mainAxisSpacing: 20,
                          crossAxisSpacing: 20,
                          childAspectRatio: width > 1000 ? 1.55 : 1.65,
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
        title: const Text('Register Medical Device'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: serial,
              decoration: const InputDecoration(labelText: 'Serial Number (e.g. CDMS-104)', prefixIcon: Icon(Icons.tag_rounded)),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: model,
              decoration: const InputDecoration(labelText: 'Device Classification Model', prefixIcon: Icon(Icons.branding_watermark_rounded)),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if (serial.text.isEmpty || model.text.isEmpty) return;
              await ref.read(apiServiceProvider).createDevice({
                'serialNumber': serial.text.trim(),
                'model': model.text.trim(),
              });
              ref.invalidate(devicesProvider);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Register'),
          ),
        ],
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.gradient,
    this.isOnline = false,
    this.isAlert = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final LinearGradient gradient;
  final bool isOnline;
  final bool isAlert;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: 172,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131B2E) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFE2E8F0),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.02),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: gradient,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: AppTheme.glowShadow(color, opacity: 0.3, blur: 8),
                  ),
                  child: Icon(icon, color: Colors.white, size: 20),
                ),
                if (isOnline)
                  const PulsingStatusDot(color: AppTheme.clinicalGreen, size: 10)
                else if (isAlert)
                  const PulsingStatusDot(color: AppTheme.clinicalRed, size: 10),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    letterSpacing: -0.5,
                  ),
            ),
            const SizedBox(height: 2),
            Text(
              label.toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45),
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
          ],
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isOnline = device.status.toLowerCase() == 'online';
    final isAlert = device.status.toLowerCase() == 'alert';

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131B2E) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isAlert 
              ? AppTheme.clinicalRed.withValues(alpha: 0.3) 
              : (isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFE2E8F0)),
          width: 1.5,
        ),
        boxShadow: isAlert 
            ? AppTheme.glowShadow(AppTheme.clinicalRed, opacity: 0.08, blur: 16)
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.02),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.push('/devices/${device.deviceId}'),
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: color.withValues(alpha: 0.2), width: 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isOnline || isAlert)
                            PulsingStatusDot(color: color, size: 8)
                          else
                            Icon(Icons.circle, size: 8, color: color),
                          const SizedBox(width: 6),
                          Text(
                            device.status.toUpperCase(),
                            style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.w900,
                              fontSize: 9,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      isOnline
                          ? Icons.sensors_rounded
                          : (isAlert ? Icons.warning_rounded : Icons.sensors_off_rounded),
                      color: color.withValues(alpha: 0.6),
                      size: 20,
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  device.serialNumber,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.2,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Text(
                        device.model,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                    if (isOnline)
                      SizedBox(
                        width: 80,
                        height: 24,
                        child: CustomPaint(
                          painter: SparklinePainter(AppTheme.clinicalGreen),
                        ),
                      )
                    else if (isAlert)
                      SizedBox(
                        width: 80,
                        height: 24,
                        child: CustomPaint(
                          painter: SparklinePainter(AppTheme.clinicalRed),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class PulsingStatusDot extends StatefulWidget {
  final Color color;
  final double size;
  const PulsingStatusDot({super.key, required this.color, this.size = 8});

  @override
  State<PulsingStatusDot> createState() => _PulsingStatusDotState();
}

class _PulsingStatusDotState extends State<PulsingStatusDot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.4, end: 1.0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.color,
          boxShadow: [
            BoxShadow(
              color: widget.color.withValues(alpha: 0.6),
              blurRadius: 6,
              spreadRadius: 1,
            ),
          ],
        ),
      ),
    );
  }
}

class SparklinePainter extends CustomPainter {
  final Color color;
  SparklinePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.75
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    final w = size.width;
    final h = size.height;

    path.moveTo(0, h * 0.6);
    path.lineTo(w * 0.2, h * 0.6);
    path.lineTo(w * 0.3, h * 0.35);
    path.lineTo(w * 0.4, h * 0.8);
    path.lineTo(w * 0.5, h * 0.1);
    path.lineTo(w * 0.6, h * 0.9);
    path.lineTo(w * 0.7, h * 0.5);
    path.lineTo(w * 0.8, h * 0.6);
    path.lineTo(w, h * 0.6);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
