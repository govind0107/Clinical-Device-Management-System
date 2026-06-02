import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'providers/auth_provider.dart';
import 'screens/alerts_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/device_detail_screen.dart';
import 'screens/history_screen.dart';
import 'screens/login_screen.dart';
import 'screens/patients_screen.dart';
import 'widgets/alert_sync.dart';
import 'widgets/app_shell.dart';

class _AuthRefresh extends ChangeNotifier {
  _AuthRefresh(this._ref) {
    _ref.listen(authProvider, (_, __) => notifyListeners());
  }
  final Ref _ref;
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _AuthRefresh(ref);

  return GoRouter(
    initialLocation: '/login',
    refreshListenable: refresh,
    redirect: (context, state) {
      final loggedIn = ref.read(authProvider).valueOrNull != null;
      final onLogin = state.matchedLocation == '/login';
      if (!loggedIn && !onLogin) return '/login';
      if (loggedIn && onLogin) return '/dashboard';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(
        path: '/devices/:id',
        builder: (_, state) => AlertSync(
          child: DeviceDetailScreen(deviceId: state.pathParameters['id']!),
        ),
      ),
      ShellRoute(
        builder: (context, state, child) {
          return AlertSync(
            child: AppShell(location: state.matchedLocation, child: child),
          );
        },
        routes: [
          GoRoute(path: '/dashboard', builder: (_, __) => const DashboardScreen()),
          GoRoute(path: '/patients', builder: (_, __) => const PatientsScreen()),
          GoRoute(path: '/history', builder: (_, __) => const HistoryScreen()),
          GoRoute(path: '/alerts', builder: (_, __) => const AlertsScreen()),
        ],
      ),
    ],
  );
});
