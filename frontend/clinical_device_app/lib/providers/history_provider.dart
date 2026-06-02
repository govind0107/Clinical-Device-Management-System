import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../services/local_db.dart';

/// Completed sessions for History screen (sqflite + assignment flow after stop).
final historySessionsProvider = FutureProvider.autoDispose<List<SessionModel>>((ref) async {
  return LocalDb.getCompletedSessions();
});
