import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../services/telemetry_hub_service.dart';

const _windowSeconds = 30;
const _maxPointsPerChannel = 120; // decimated cap for smooth 60fps plotting

class LiveChartState {
  final Map<String, List<TelemetryPoint>> channels;
  final Map<String, bool> enabled;
  final String? sessionId;
  final String? deviceId;

  LiveChartState({
    required this.channels,
    required this.enabled,
    this.sessionId,
    this.deviceId,
  });

  LiveChartState copyWith({
    Map<String, List<TelemetryPoint>>? channels,
    Map<String, bool>? enabled,
    String? sessionId,
    String? deviceId,
  }) =>
      LiveChartState(
        channels: channels ?? this.channels,
        enabled: enabled ?? this.enabled,
        sessionId: sessionId ?? this.sessionId,
        deviceId: deviceId ?? this.deviceId,
      );
}

class LiveChartNotifier extends Notifier<LiveChartState> {
  StreamSubscription<Map<String, dynamic>>? _sub;
  Timer? _updateTimer;
  final Map<String, List<TelemetryPoint>> _buffer = {
    'ECG': [],
    'SpO2': [],
    'BP': [],
  };

  @override
  LiveChartState build() {
    ref.onDispose(() {
      _sub?.cancel();
      _updateTimer?.cancel();
    });
    return LiveChartState(
      channels: {'ECG': [], 'SpO2': [], 'BP': []},
      enabled: {'ECG': true, 'SpO2': true, 'BP': true},
    );
  }

  Future<void> start(String sessionId, String deviceId) async {
    _sub?.cancel();
    _updateTimer?.cancel();

    state = state.copyWith(
      sessionId: sessionId,
      deviceId: deviceId,
      channels: {'ECG': [], 'SpO2': [], 'BP': []},
    );

    _buffer['ECG']!.clear();
    _buffer['SpO2']!.clear();
    _buffer['BP']!.clear();

    final hub = ref.read(telemetryHubProvider);
    await ref.read(hubConnectionProvider.future);
    await hub.subscribeSession(sessionId);

    _sub = hub.telemetryStream.listen(_onTelemetry);
    _updateTimer = Timer.periodic(const Duration(milliseconds: 33), (_) => _flushBuffer());
  }

  void _onTelemetry(Map<String, dynamic> data) {
    if (data['sessionId']?.toString() != state.sessionId) return;

    final channel = data['channel'] as String? ?? '';
    final value = (data['value'] as num?)?.toDouble() ?? 0;
    final ts = DateTime.tryParse(data['timestamp']?.toString() ?? '') ?? DateTime.now();

    _buffer[channel]?.add(TelemetryPoint(ts, value));
  }

  void _flushBuffer() {
    if (_buffer.values.every((list) => list.isEmpty)) return;

    final updated = Map<String, List<TelemetryPoint>>.from(state.channels);
    final cutoff = DateTime.now().subtract(const Duration(seconds: _windowSeconds));

    var hasChanges = false;
    for (final channel in _buffer.keys) {
      final newPoints = _buffer[channel]!;
      if (newPoints.isEmpty) continue;

      hasChanges = true;
      var list = List<TelemetryPoint>.from(updated[channel] ?? []);
      list.addAll(newPoints);
      newPoints.clear();

      list.removeWhere((p) => p.timestamp.isBefore(cutoff));
      list = _decimate(list, _maxPointsPerChannel);
      updated[channel] = list;
    }

    if (hasChanges) {
      state = state.copyWith(channels: updated);
    }
  }

  /// Keep evenly spaced points when buffer exceeds cap (assignment 3.2).
  static List<TelemetryPoint> _decimate(List<TelemetryPoint> points, int maxPoints) {
    if (points.length <= maxPoints) return points;
    final step = points.length / maxPoints;
    final result = <TelemetryPoint>[];
    for (var i = 0; i < maxPoints; i++) {
      result.add(points[(i * step).floor()]);
    }
    return result;
  }

  void toggleChannel(String channel) {
    final enabled = Map<String, bool>.from(state.enabled);
    enabled[channel] = !(enabled[channel] ?? true);
    state = state.copyWith(enabled: enabled);
  }

  Future<void> stopMonitoring() async {
    _sub?.cancel();
    _sub = null;
    _updateTimer?.cancel();
    _updateTimer = null;
    final sessionId = state.sessionId;
    final deviceId = state.deviceId;
    if (sessionId != null || deviceId != null) {
      final hub = ref.read(telemetryHubProvider);
      if (sessionId != null) await hub.unsubscribeSession(sessionId);
      if (deviceId != null) await hub.unsubscribeDevice(deviceId);
    }
    state = LiveChartState(
      channels: {'ECG': [], 'SpO2': [], 'BP': []},
      enabled: state.enabled,
    );
  }

  void clear() {
    _sub?.cancel();
    _sub = null;
    _updateTimer?.cancel();
    _updateTimer = null;
    state = LiveChartState(
      channels: {'ECG': [], 'SpO2': [], 'BP': []},
      enabled: state.enabled,
    );
  }

  static ({double min, double max, double avg}) stats(List<TelemetryPoint> points) {
    if (points.isEmpty) return (min: 0.0, max: 0.0, avg: 0.0);
    var min = points.first.value;
    var max = points.first.value;
    var sum = 0.0;
    for (final p in points) {
      if (p.value < min) min = p.value;
      if (p.value > max) max = p.value;
      sum += p.value;
    }
    return (min: min, max: max, avg: sum / points.length);
  }
}

final liveChartProvider =
    NotifierProvider<LiveChartNotifier, LiveChartState>(LiveChartNotifier.new);
