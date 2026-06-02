import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:signalr_netcore/signalr_client.dart';
import '../config/api_config.dart';
import '../models/models.dart';
import '../providers/auth_provider.dart';

class TelemetryHubService {
  HubConnection? _connection;
  final _telemetryController = StreamController<Map<String, dynamic>>.broadcast();
  final _alertController = StreamController<AlertModel>.broadcast();

  Stream<Map<String, dynamic>> get telemetryStream => _telemetryController.stream;
  Stream<AlertModel> get alertStream => _alertController.stream;

  Future<void> connect(String token) async {
    if (_connection?.state == HubConnectionState.Connected) return;

    _connection = HubConnectionBuilder()
        .withUrl(
          ApiConfig.hubUrl,
          options: HttpConnectionOptions(
            accessTokenFactory: () async => token,
          ),
        )
        .withAutomaticReconnect()
        .build();

    _connection!.on('TelemetryReceived', (args) {
      if (args != null && args.isNotEmpty) {
        _telemetryController.add(Map<String, dynamic>.from(args[0] as Map));
      }
    });

    _connection!.on('AlertRaised', (args) {
      if (args != null && args.isNotEmpty) {
        _alertController.add(
          AlertModel.fromJson(Map<String, dynamic>.from(args[0] as Map)),
        );
      }
    });

    await _connection!.start();
  }

  Future<void> subscribeSession(String sessionId) async {
    await _connection?.invoke('SubscribeSession', args: [sessionId]);
  }

  Future<void> subscribeDevice(String deviceId) async {
    await _connection?.invoke('SubscribeDevice', args: [deviceId]);
  }

  Future<void> unsubscribeSession(String sessionId) async {
    await _connection?.invoke('UnsubscribeSession', args: [sessionId]);
  }

  Future<void> unsubscribeDevice(String deviceId) async {
    await _connection?.invoke('UnsubscribeDevice', args: [deviceId]);
  }

  Future<void> disconnect() async {
    await _connection?.stop();
  }

  void dispose() {
    _telemetryController.close();
    _alertController.close();
  }
}

final telemetryHubProvider = Provider<TelemetryHubService>((ref) {
  final service = TelemetryHubService();
  ref.onDispose(() => service.dispose());
  return service;
});

final hubConnectionProvider = FutureProvider<void>((ref) async {
  final auth = ref.watch(authProvider).valueOrNull;
  if (auth == null) return;
  await ref.read(telemetryHubProvider).connect(auth.token);
});
