import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/role_config.dart';
import '../providers/auth_provider.dart';

class AppShell extends ConsumerWidget {
  const AppShell({
    super.key,
    required this.child,
    required this.location,
  });

  final Widget child;
  final String location;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(authProvider).valueOrNull?.role ?? '';
    final items = <_NavItem>[
      const _NavItem('/dashboard', Icons.dashboard_outlined, 'Dashboard'),
      if (RoleConfig.canManagePatients(role))
        const _NavItem('/patients', Icons.people_outline, 'Patients'),
      const _NavItem('/history', Icons.history, 'History'),
      const _NavItem('/alerts', Icons.notifications_outlined, 'Alerts'),
    ];

    var selected = items.indexWhere((i) => location.startsWith(i.route));
    if (selected < 0) selected = 0;

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selected,
        onDestinationSelected: (i) => context.go(items[i].route),
        destinations: items
            .map((d) => NavigationDestination(icon: Icon(d.icon), label: d.label))
            .toList(),
      ),
    );
  }
}

class _NavItem {
  const _NavItem(this.route, this.icon, this.label);
  final String route;
  final IconData icon;
  final String label;
}
