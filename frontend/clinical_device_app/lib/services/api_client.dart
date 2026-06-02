import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/api_config.dart';
import '../models/models.dart';
import '../providers/auth_provider.dart';

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(BaseOptions(
    baseUrl: ApiConfig.apiBase,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 30),
  ));

  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) {
      final token = ref.read(authProvider).valueOrNull?.token;
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
      }
      handler.next(options);
    },
  ));

  return dio;
});

class ApiService {
  ApiService(this._dio);
  final Dio _dio;

  // POST /api/auth/login
  Future<UserSession> login(String username, String password) async {
    final res = await _dio.post('/auth/login', data: {
      'username': username,
      'password': password,
    });
    return UserSession.fromJson(res.data as Map<String, dynamic>);
  }

  // GET/POST/PUT/DELETE /api/devices
  Future<List<DeviceModel>> getDevices({String? status}) async {
    final res = await _dio.get('/devices', queryParameters: {
      if (status != null) 'status': status,
    });
    return (res.data as List)
        .map((e) => DeviceModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<DeviceModel> createDevice(Map<String, dynamic> body) async {
    final res = await _dio.post('/devices', data: body);
    return DeviceModel.fromJson(res.data as Map<String, dynamic>);
  }

  Future<DeviceModel> updateDevice(String id, Map<String, dynamic> body) async {
    final res = await _dio.put('/devices/$id', data: body);
    return DeviceModel.fromJson(res.data as Map<String, dynamic>);
  }

  Future<void> deleteDevice(String id) async {
    await _dio.delete('/devices/$id');
  }

  // GET /api/devices/{id}/health
  Future<Map<String, dynamic>> getDeviceHealth(String id) async {
    final res = await _dio.get('/devices/$id/health');
    return Map<String, dynamic>.from(res.data as Map);
  }

  // POST /api/devices/{id}/simulate
  Future<void> simulateDevice(String deviceId) async {
    await _dio.post('/devices/$deviceId/simulate');
  }

  // GET/POST /api/patients
  Future<List<PatientModel>> getPatients({String? search}) async {
    final res = await _dio.get('/patients', queryParameters: {
      if (search != null && search.isNotEmpty) 'search': search,
    });
    return (res.data as List)
        .map((e) => PatientModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<PatientModel> savePatient(PatientModel p, {bool isUpdate = false}) async {
    final res = await _dio.post('/patients', data: p.toCreateJson(forUpdate: isUpdate));
    return PatientModel.fromJson(res.data as Map<String, dynamic>);
  }

  // POST /api/sessions/start
  Future<SessionModel> startSession(String deviceId, {String? patientId}) async {
    final res = await _dio.post('/sessions/start', data: {
      'deviceId': deviceId,
      if (patientId != null) 'patientId': patientId,
    });
    return SessionModel.fromJson(res.data as Map<String, dynamic>);
  }

  // POST /api/sessions/{id}/stop
  Future<SessionModel> stopSession(String sessionId) async {
    final res = await _dio.post('/sessions/$sessionId/stop');
    return SessionModel.fromJson(res.data as Map<String, dynamic>);
  }

  // POST /api/readings/batch
  Future<void> ingestReadingsBatch(Map<String, dynamic> body) async {
    await _dio.post('/readings/batch', data: body);
  }

  // GET /api/readings/{sessionId}
  Future<List<ReadingModel>> getReadings(
    String sessionId, {
    DateTime? from,
    DateTime? to,
    String? channel,
  }) async {
    final res = await _dio.get('/readings/$sessionId', queryParameters: {
      if (from != null) 'from': from.toUtc().toIso8601String(),
      if (to != null) 'to': to.toUtc().toIso8601String(),
      if (channel != null) 'channel': channel,
    });
    return (res.data as List)
        .map((e) => ReadingModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // GET /api/alerts
  Future<List<AlertModel>> getAlerts({bool? acknowledged}) async {
    final res = await _dio.get('/alerts', queryParameters: {
      if (acknowledged != null) 'acknowledged': acknowledged,
    });
    return (res.data as List)
        .map((e) => AlertModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> acknowledgeAlert(String alertId) async {
    await _dio.post('/alerts/$alertId/acknowledge', data: {'acknowledged': true});
  }
}

final apiServiceProvider = Provider<ApiService>((ref) {
  return ApiService(ref.watch(dioProvider));
});
