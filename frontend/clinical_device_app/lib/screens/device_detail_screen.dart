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

class _DeviceDetailScreenState extends ConsumerState<DeviceDetailScreen> {
  SessionModel? _activeSession;
  String? _selectedPatientId;
  var _busy = false;
  var _leaving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncExistingSession());
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
          title: const Text('Live Monitor'),
          actions: [
            if (_activeSession != null)
              IconButton(
                tooltip: 'Trigger threshold alert',
                icon: const Icon(Icons.bolt),
                onPressed: _triggerSimulate,
              ),
          ],
        ),
        body: devicesAsync.when(
          loading: () => const LoadingView(),
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
              return const EmptyView(message: 'Device not found');
            }

            final activeDevice = device;

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(activeDevice.serialNumber,
                                style: Theme.of(context).textTheme.titleLarge),
                            Text('${activeDevice.model} • ${activeDevice.status}',
                                style:
                                    TextStyle(color: AppTheme.statusColor(activeDevice.status))),
                          ],
                        ),
                      ),
                      if (canStart)
                        patientsAsync.when(
                          data: (patients) => DropdownButton<String?>(
                            hint: const Text('Select Patient'),
                            value: _selectedPatientId,
                            items: patients.map((p) => DropdownMenuItem<String?>(
                                  value: p.patientId,
                                  child: Text(p.name),
                                )).toList(),
                            onChanged: _activeSession == null
                                ? (v) => setState(() => _selectedPatientId = v)
                                : null,
                          ),
                          loading: () => const SizedBox.shrink(),
                          error: (_, __) => const SizedBox.shrink(),
                        ),
                      const SizedBox(width: 8),
                      if (canStart && _activeSession == null)
                        FilledButton.icon(
                          onPressed: _busy || _selectedPatientId == null
                              ? null
                              : () => _startSession(activeDevice, patientsAsync),
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('Start'),
                        )
                      else if (canStart)
                        FilledButton.tonalIcon(
                          onPressed: _busy ? null : () => _stopSession(patientsAsync),
                          icon: const Icon(Icons.stop),
                          label: const Text('Stop'),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Wrap(
                    spacing: 8,
                    children: chart.enabled.keys.map((ch) {
                      final on = chart.enabled[ch] ?? true;
                      return FilterChip(
                        label: Text(ch),
                        selected: on,
                        onSelected: (_) =>
                            ref.read(liveChartProvider.notifier).toggleChannel(ch),
                      );
                    }).toList(),
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: chart.enabled.entries.where((e) => e.value).map((e) {
                      final ch = e.key;
                      return SizedBox(
                        height: 180,
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: LiveTelemetryChart(
                              channel: ch,
                              points: chart.channels[ch] ?? [],
                              color: channelColors[ch] ?? Colors.blue,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            );
          },
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
          const SnackBar(content: Text('Threshold spike sent — watch alerts')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_friendlyError(e))));
      }
    }
  }
}
