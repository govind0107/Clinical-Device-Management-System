import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/models.dart';
import '../core/role_config.dart';
import '../providers/auth_provider.dart';
import '../providers/data_providers.dart';
import '../providers/history_provider.dart';
import '../providers/live_chart_provider.dart';
import '../services/api_client.dart';
import '../services/local_db.dart';
import '../services/telemetry_hub_service.dart';
import '../theme/app_theme.dart';
import '../widgets/live_chart.dart';
import '../widgets/state_views.dart';

class DeviceDetailScreen extends ConsumerStatefulWidget {
  const DeviceDetailScreen({super.key, required this.deviceId});
  final String deviceId;

  @override
  ConsumerState<DeviceDetailScreen> createState() => _DeviceDetailScreenState();
}

class _DeviceDetailScreenState extends ConsumerState<DeviceDetailScreen> with SingleTickerProviderStateMixin {
  SessionModel? _activeSession;
  String? _selectedPatientId;
  var _busy = false;
  var _leaving = false;

  // Blinking dot animation for active vitals tracking
  late AnimationController _pulseController;
  late Animation<double> _pulseScale;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncExistingSession());
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _pulseScale = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  /// If user left without Stop, server may still have an active session (causes 409).
  Future<void> _syncExistingSession() async {
    try {
      final health = await ref.read(apiServiceProvider).getDeviceHealth(widget.deviceId);
      final sessionId = health['activeSessionId'] as String?;
      if (sessionId == null || !mounted) return;

      final session = SessionModel(
        sessionId: sessionId,
        deviceId: widget.deviceId,
        patientId: null,
        startTime: DateTime.now(),
      );
      setState(() => _activeSession = session);
      await ref.read(liveChartProvider.notifier).start(sessionId, widget.deviceId);
    } catch (_) {
      // ignore — health check optional
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    final session = _activeSession;
    if (session != null) {
      unawaited(ref.read(apiServiceProvider).stopSession(session.sessionId));
    }
    unawaited(ref.read(liveChartProvider.notifier).stopMonitoring());
    super.dispose();
  }

  Future<bool> _handleBack(AsyncValue<List<PatientModel>> patientsAsync) async {
    if (_leaving) return false;
    if (_activeSession == null) return true;

    setState(() => _leaving = true);
    await _stopSession(patientsAsync, navigateBack: false);
    setState(() => _leaving = false);
    return true;
  }

  String _friendlyError(Object e) {
    if (e is DioException) {
      final code = e.response?.statusCode;
      final data = e.response?.data;
      if (code == 409) {
        return 'This device already has an active session. Use Stop or go back to end it.';
      }
      if (data is Map && data['message'] != null) {
        return data['message'].toString();
      }
      if (code != null) return 'Request failed ($code)';
    }
    return e.toString();
  }

  @override
  Widget build(BuildContext context) {
    final devicesAsync = ref.watch(devicesProvider);
    final patientsAsync = ref.watch(patientsProvider(null));
    ref.watch(hubConnectionProvider);
    final chart = ref.watch(liveChartProvider);
    final role = ref.watch(authProvider).valueOrNull?.role ?? '';
    final canStart = RoleConfig.canStartSessions(role);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: _activeSession == null && !_busy && !_leaving,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final ok = await _handleBack(patientsAsync);
        if (ok && context.mounted) context.pop();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: BackButton(
            onPressed: _busy || _leaving
                ? null
                : () async {
                    final ok = await _handleBack(patientsAsync);
                    if (ok && context.mounted) context.pop();
                  },
          ),
          title: const Text('ICU Live Monitor'),
          actions: [
            if (_activeSession != null)
              IconButton(
                tooltip: 'Simulate critical threshold event',
                icon: const Icon(Icons.bolt, color: AppTheme.clinicalAmber, size: 28),
                onPressed: _triggerSimulate,
              ),
          ],
        ),
        body: devicesAsync.when(
          loading: () => const LoadingView(message: 'Initializing device signals...'),
          error: (e, _) =>
              ErrorView(message: e.toString(), onRetry: () => ref.invalidate(devicesProvider)),
          data: (devices) {
            DeviceModel? device;
            for (final d in devices) {
              if (d.deviceId == widget.deviceId) {
                device = d;
                break;
              }
            }
            if (device == null) {
              return const EmptyView(message: 'Clinical device not found');
            }

            final activeDevice = device;
            final isSessionActive = _activeSession != null;

            // Fetch the latest values for digital led readouts
            final lastEcg = chart.channels['ECG']?.isNotEmpty == true ? chart.channels['ECG']!.last.value : null;
            final lastSpo2 = chart.channels['SpO2']?.isNotEmpty == true ? chart.channels['SpO2']!.last.value : null;
            final lastBp = chart.channels['BP']?.isNotEmpty == true ? chart.channels['BP']!.last.value : null;

            return Column(
              children: [
                // Top control panel & patient settings
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Container(
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
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppTheme.statusColor(activeDevice.status).withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.settings_input_hdmi_rounded,
                                  color: AppTheme.statusColor(activeDevice.status),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      activeDevice.serialNumber,
                                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: -0.2,
                                          ),
                                    ),
                                    Text(
                                      '${activeDevice.model} • ${activeDevice.status.toUpperCase()}',
                                      style: TextStyle(
                                        color: AppTheme.statusColor(activeDevice.status),
                                        fontWeight: FontWeight.w800,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 32),
                          Row(
                            children: [
                              if (canStart)
                                Expanded(
                                  child: patientsAsync.when(
                                    data: (patients) => InputDecorator(
                                      decoration: const InputDecoration(
                                        labelText: 'Assign Patient Profile',
                                        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                      ),
                                      child: DropdownButtonHideUnderline(
                                        child: DropdownButton<String?>(
                                          value: _selectedPatientId,
                                          isExpanded: true,
                                          hint: const Text('Select Patient', style: TextStyle(fontWeight: FontWeight.w500)),
                                          items: patients.map((p) => DropdownMenuItem<String?>(
                                                value: p.patientId,
                                                child: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                                              )).toList(),
                                          onChanged: !isSessionActive
                                              ? (v) => setState(() => _selectedPatientId = v)
                                              : null,
                                        ),
                                      ),
                                    ),
                                    loading: () => const LinearProgressIndicator(),
                                    error: (_, __) => const Text('Error loading patient list'),
                                  ),
                                ),
                              const SizedBox(width: 16),
                              if (canStart && !isSessionActive)
                                Container(
                                  decoration: BoxDecoration(
                                    gradient: _selectedPatientId == null ? null : AppTheme.greenGradient,
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: _selectedPatientId == null 
                                        ? null 
                                        : AppTheme.glowShadow(AppTheme.clinicalGreen, opacity: 0.3, blur: 10),
                                  ),
                                  child: FilledButton.icon(
                                    onPressed: _busy || _selectedPatientId == null
                                        ? null
                                        : () => _startSession(activeDevice, patientsAsync),
                                    icon: const Icon(Icons.play_arrow_rounded),
                                    label: const Text('BOOT MONITOR'),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: _selectedPatientId == null ? Colors.grey : Colors.transparent,
                                      foregroundColor: Colors.white,
                                      shadowColor: Colors.transparent,
                                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                                    ),
                                  ),
                                )
                              else if (canStart)
                                Container(
                                  decoration: BoxDecoration(
                                    gradient: AppTheme.redGradient,
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: AppTheme.glowShadow(AppTheme.clinicalRed, opacity: 0.3, blur: 10),
                                  ),
                                  child: FilledButton.icon(
                                    onPressed: _busy ? null : () => _stopSession(patientsAsync),
                                    icon: const Icon(Icons.stop_rounded),
                                    label: const Text('TERMINATE'),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      foregroundColor: Colors.white,
                                      shadowColor: Colors.transparent,
                                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Channel Toggles Row
                if (isSessionActive)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    child: Row(
                      children: [
                        const Text(
                          'Vitals Channels:',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Wrap(
                            spacing: 10,
                            children: chart.enabled.keys.map((ch) {
                              final on = chart.enabled[ch] ?? true;
                              final color = channelColors[ch] ?? Colors.blue;
                              return FilterChip(
                                label: Text(ch),
                                selected: on,
                                selectedColor: color.withValues(alpha: 0.15),
                                checkmarkColor: color,
                                labelStyle: TextStyle(
                                  color: on ? color : null,
                                  fontWeight: on ? FontWeight.w800 : FontWeight.w600,
                                  fontSize: 12,
                                ),
                                onSelected: (_) =>
                                    ref.read(liveChartProvider.notifier).toggleChannel(ch),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Live Vitals Monitor Board
                Expanded(
                  child: !isSessionActive
                      ? Center(
                          child: Container(
                            margin: const EdgeInsets.all(24),
                            padding: const EdgeInsets.all(32),
                            constraints: const BoxConstraints(maxWidth: 450),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF131B2E) : Colors.white,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFE2E8F0)),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.sensors_off_rounded, size: 48, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.25)),
                                const SizedBox(height: 20),
                                const Text(
                                  'TELEMETRY OFFLINE',
                                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: 1.0),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'No clinical monitoring session is active. Assign a patient and tap "BOOT MONITOR" above to start live SignalR telemetry.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                                    height: 1.4,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : Container(
                          margin: const EdgeInsets.all(20),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF070B14), // Deep ICU Dark Mode screen
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: activeDevice.status.toLowerCase() == 'alert' 
                                  ? AppTheme.clinicalRed 
                                  : Colors.white.withValues(alpha: 0.08),
                              width: 2,
                            ),
                            boxShadow: activeDevice.status.toLowerCase() == 'alert'
                                ? AppTheme.glowShadow(AppTheme.clinicalRed, opacity: 0.15, blur: 24)
                                : AppTheme.glowShadow(Colors.blue, opacity: 0.05, blur: 16),
                          ),
                          child: Column(
                            children: [
                              // Digital LED Vitals Dashboard Row
                              Row(
                                children: [
                                  if (chart.enabled['ECG'] == true)
                                    Expanded(
                                      child: _LedVitalsBadge(
                                        title: 'ECG / PULSE',
                                        value: lastEcg != null ? lastEcg.toStringAsFixed(0) : '--',
                                        unit: 'BPM',
                                        color: AppTheme.clinicalRed,
                                        child: ScaleTransition(
                                          scale: _pulseScale,
                                          child: const Icon(Icons.favorite_rounded, color: AppTheme.clinicalRed, size: 16),
                                        ),
                                      ),
                                    ),
                                  const SizedBox(width: 12),
                                  if (chart.enabled['SpO2'] == true)
                                    Expanded(
                                      child: _LedVitalsBadge(
                                        title: 'SpO2 / OX',
                                        value: lastSpo2 != null ? lastSpo2.toStringAsFixed(0) : '--',
                                        unit: '%',
                                        color: AppTheme.clinicalBlue,
                                        child: const Icon(Icons.water_drop_rounded, color: AppTheme.clinicalBlue, size: 16),
                                      ),
                                    ),
                                  const SizedBox(width: 12),
                                  if (chart.enabled['BP'] == true)
                                    Expanded(
                                      child: _LedVitalsBadge(
                                        title: 'BLOOD PRES',
                                        value: lastBp != null ? lastBp.toStringAsFixed(0) : '--',
                                        unit: 'mmHg',
                                        color: AppTheme.clinicalGreen,
                                        child: const Icon(Icons.speed_rounded, color: AppTheme.clinicalGreen, size: 16),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              // Live Waves List/Grid
                              Expanded(
                                child: LayoutBuilder(
                                  builder: (context, constraints) {
                                    final enabledEntries = chart.enabled.entries.where((e) => e.value).toList();
                                    final gridCols = constraints.maxWidth > 900 ? 2 : 1;
                                    
                                    if (gridCols > 1 && enabledEntries.length > 1) {
                                      // Render Grid for large screens
                                      return GridView.builder(
                                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                          crossAxisCount: 2,
                                          mainAxisSpacing: 12,
                                          crossAxisSpacing: 12,
                                          childAspectRatio: 2.2,
                                        ),
                                        itemCount: enabledEntries.length,
                                        itemBuilder: (ctx, i) {
                                          final ch = enabledEntries[i].key;
                                          return _buildWaveCard(ch, chart.channels[ch] ?? []);
                                        },
                                      );
                                    } else {
                                      // Standard stack list
                                      return ListView(
                                        children: enabledEntries.map((e) {
                                          final ch = e.key;
                                          return SizedBox(
                                            height: 155,
                                            child: Padding(
                                              padding: const EdgeInsets.only(bottom: 12),
                                              child: _buildWaveCard(ch, chart.channels[ch] ?? []),
                                            ),
                                          );
                                        }).toList(),
                                      );
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildWaveCard(String channel, List<TelemetryPoint> points) {
    final color = channelColors[channel] ?? Colors.blue;
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F1524),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.15), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: LiveTelemetryChart(
          channel: channel,
          points: points,
          color: color,
        ),
      ),
    );
  }

  Future<void> _startSession(
      DeviceModel device, AsyncValue<List<PatientModel>> patientsAsync) async {
    setState(() => _busy = true);
    try {
      final session = await ref.read(apiServiceProvider).startSession(
            device.deviceId,
            patientId: _selectedPatientId,
          );
      if (!mounted) return;
      setState(() => _activeSession = session);
      await LocalDb.saveSession(session);
      if (!mounted) return;
      await ref.read(liveChartProvider.notifier).start(session.sessionId, device.deviceId);
    } on DioException catch (e) {
      if (e.response?.statusCode == 409) {
        await _syncExistingSession();
        if (mounted && _activeSession != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Resumed existing session for this device.'),
            ),
          );
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_friendlyError(e))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_friendlyError(e))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _stopSession(
    AsyncValue<List<PatientModel>> patientsAsync, {
    bool navigateBack = false,
  }) async {
    if (_activeSession == null) return;
    setState(() => _busy = true);
    try {
      final stopped =
          await ref.read(apiServiceProvider).stopSession(_activeSession!.sessionId);
      if (!mounted) return;
      String? patientName;
      final pid = stopped.patientId;
      if (pid != null && patientsAsync.hasValue) {
        for (final p in patientsAsync.value!) {
          if (p.patientId == pid) {
            patientName = p.name;
            break;
          }
        }
      }
      await LocalDb.saveSession(stopped, patientName: patientName);
      try {
        final readings = await ref.read(apiServiceProvider).getReadings(stopped.sessionId);
        if (!mounted) return;
        await LocalDb.cacheReadingsBatch(stopped.sessionId, readings);
      } catch (_) {
        // ignore fallback errors
      }
      if (!mounted) return;
      await ref.read(liveChartProvider.notifier).stopMonitoring();
      ref.invalidate(historySessionsProvider);
      ref.invalidate(devicesProvider);
      setState(() => _activeSession = null);
      if (mounted && !navigateBack) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Session stopped — open History to playback')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_friendlyError(e))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _triggerSimulate() async {
    try {
      await ref.read(apiServiceProvider).simulateDevice(widget.deviceId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Simulated vitals threshold spike sent.'),
            backgroundColor: AppTheme.clinicalAmber,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_friendlyError(e))));
      }
    }
  }
}

class _LedVitalsBadge extends StatelessWidget {
  const _LedVitalsBadge({
    required this.title,
    required this.value,
    required this.unit,
    required this.color,
    this.child,
  });

  final String title;
  final String value;
  final String unit;
  final Color color;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1524),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.15), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title.toUpperCase(),
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w800,
                  fontSize: 10,
                  letterSpacing: 0.5,
                ),
              ),
              if (child != null) child!,
            ],
          ),
          const SizedBox(height: 6),
          Row(
            textBaseline: TextBaseline.alphabetic,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            children: [
              Text(
                value,
                style: TextStyle(
                  color: color,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(width: 4),
              Text(
                unit,
                style: TextStyle(
                  color: color.withValues(alpha: 0.5),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
