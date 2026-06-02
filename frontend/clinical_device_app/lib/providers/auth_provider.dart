import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../services/api_client.dart';

class AuthNotifier extends AsyncNotifier<UserSession?> {
  static const _key = 'auth_session';

  @override
  Future<UserSession?> build() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return null;
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final session = UserSession.fromJson(json);
    if (session.expiresAt.isBefore(DateTime.now())) {
      await prefs.remove(_key);
      return null;
    }
    return session;
  }

  Future<void> login(String username, String password) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final session = await ref.read(apiServiceProvider).login(username, password);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode({
        'token': session.token,
        'username': session.username,
        'role': session.role,
        'expiresAt': session.expiresAt.toIso8601String(),
      }));
      return session;
    });
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
    state = const AsyncData(null);
  }
}

final authProvider = AsyncNotifierProvider<AuthNotifier, UserSession?>(AuthNotifier.new);
