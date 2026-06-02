import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/role_config.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({
    super.key,
    required this.child,
    required this.location,
  });

  final Widget child;
  final String location;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> with SingleTickerProviderStateMixin {
  late AnimationController _logoPulseController;
  late Animation<double> _logoScale;

  @override
  void initState() {
    super.initState();
    _logoPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _logoScale = Tween<double>(begin: 0.92, end: 1.08).animate(
      CurvedAnimation(parent: _logoPulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _logoPulseController.dispose();
    super.dispose();
  }

  LinearGradient _getAvatarGradient(String username) {
    final hash = username.hashCode;
    final index = hash.abs() % 4;
    final gradients = [
      AppTheme.primaryGradient,
      AppTheme.blueGradient,
      AppTheme.greenGradient,
      const LinearGradient(
        colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
      ),
    ];
    return gradients[index];
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider).valueOrNull;
    final role = auth?.role ?? '';
    final username = auth?.username ?? 'User';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final items = <_NavItem>[
      const _NavItem('/dashboard', Icons.dashboard_rounded, 'Dashboard'),
      if (RoleConfig.canManagePatients(role))
        const _NavItem('/patients', Icons.people_rounded, 'Patients'),
      const _NavItem('/history', Icons.history_rounded, 'History'),
      const _NavItem('/alerts', Icons.notifications_rounded, 'Alerts'),
    ];

    var selected = items.indexWhere((i) => widget.location.startsWith(i.route));
    if (selected < 0) selected = 0;

    final width = MediaQuery.sizeOf(context).width;
    final isLargeScreen = width > 768;

    if (isLargeScreen) {
      return Scaffold(
        body: Row(
          children: [
            // Elegant Glassmorphic Sidebar
            Container(
              width: 280,
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF0D1425).withValues(alpha: 0.85) // Obsidian Glass
                    : Colors.white,
                border: Border(
                  right: BorderSide(
                    color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFE2E8F0),
                    width: 1.5,
                  ),
                ),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 36),
                  // Header / Logo
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      children: [
                        ScaleTransition(
                          scale: _logoScale,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              gradient: AppTheme.primaryGradient,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: AppTheme.glowShadow(AppTheme.clinicalPrimary, opacity: 0.25, blur: 8),
                            ),
                            child: const Icon(
                              Icons.monitor_heart_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'CDMS HUB',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.5,
                              ),
                            ),
                            Text(
                              'v1.0 • ONLINE',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.clinicalGreen,
                                letterSpacing: 0.5,
                                shadows: [
                                  Shadow(
                                    color: AppTheme.clinicalGreen.withValues(alpha: 0.3),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 36),
                  // Navigation Items
                  Expanded(
                    child: ListView.builder(
                      itemCount: items.length,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemBuilder: (context, idx) {
                        final d = items[idx];
                        final isSelected = selected == idx;
                        final activeColor = isSelected
                            ? AppTheme.clinicalPrimary
                            : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: Stack(
                            children: [
                              ListTile(
                                leading: Icon(
                                  d.icon,
                                  color: activeColor,
                                  size: 22,
                                ),
                                title: Text(
                                  d.label,
                                  style: TextStyle(
                                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                    fontSize: 14,
                                    color: isSelected
                                        ? (isDark ? Colors.white : AppTheme.clinicalPrimary)
                                        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                                  ),
                                ),
                                selected: isSelected,
                                selectedTileColor: AppTheme.clinicalPrimary.withValues(alpha: isDark ? 0.08 : 0.06),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                onTap: () => context.go(d.route),
                              ),
                              if (isSelected)
                                Positioned(
                                  left: 0,
                                  top: 12,
                                  bottom: 12,
                                  child: Container(
                                    width: 4,
                                    decoration: BoxDecoration(
                                      color: AppTheme.clinicalPrimary,
                                      borderRadius: BorderRadius.circular(8),
                                      boxShadow: AppTheme.glowShadow(AppTheme.clinicalPrimary, opacity: 0.5, blur: 6),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  // User Profile Section
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.02)
                            : Colors.black.withValues(alpha: 0.02),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.04),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: _getAvatarGradient(username),
                              boxShadow: AppTheme.glowShadow(
                                _getAvatarGradient(username).colors.first,
                                opacity: 0.3,
                                blur: 8,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                username.isNotEmpty ? username[0].toUpperCase() : 'U',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  username,
                                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppTheme.clinicalPrimary.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    role.toUpperCase(),
                                    style: const TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w900,
                                      color: AppTheme.clinicalPrimary,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(child: widget.child),
          ],
        ),
      );
    }

    // Cleaned Mobile Shell layout
    return Scaffold(
      body: widget.child,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: NavigationBar(
          selectedIndex: selected,
          onDestinationSelected: (i) => context.go(items[i].route),
          height: 68,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          elevation: 0,
          backgroundColor: isDark ? const Color(0xFF0D1425) : Colors.white,
          indicatorColor: AppTheme.clinicalPrimary.withValues(alpha: 0.12),
          destinations: items
              .map((d) => NavigationDestination(
                    icon: Icon(d.icon),
                    label: d.label,
                  ))
              .toList(),
        ),
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
