import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../services/api_client.dart';
import '../services/local_db.dart';

final devicesProvider = FutureProvider.autoDispose<List<DeviceModel>>((ref) async {
  return ref.watch(apiServiceProvider).getDevices();
});

final patientsProvider =
    FutureProvider.autoDispose.family<List<PatientModel>, String?>((ref, search) async {
  return ref.watch(apiServiceProvider).getPatients(search: search);
});

final alertsProvider = FutureProvider.autoDispose<List<AlertModel>>((ref) async {
  try {
    return await ref.watch(apiServiceProvider).getAlerts();
  } catch (_) {
    return LocalDb.getCachedAlerts();
  }
});

final activeAlertsProvider = FutureProvider.autoDispose<List<AlertModel>>((ref) async {
  try {
    return await ref.watch(apiServiceProvider).getAlerts(acknowledged: false);
  } catch (_) {
    final cached = await LocalDb.getCachedAlerts();
    return cached.where((a) => !a.acknowledged).toList();
  }
});
