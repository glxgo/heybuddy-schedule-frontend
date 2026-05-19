import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/theme.dart';
import '../../widgets/glass_card.dart';
import '../providers/admin_auth_provider.dart';

class AdminShell extends ConsumerWidget {
  final String title;
  final String subtitle;
  final int selectedIndex;
  final Widget child;

  const AdminShell({
    super.key,
    required this.title,
    required this.subtitle,
    required this.selectedIndex,
    required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(adminAuthProvider);
    if (auth.isInitializing) {
      return const _AdminLoadingView(message: '正在恢复后台登录态…');
    }
    if (!auth.isAuthenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          context.go('/login');
        }
      });
      return const _AdminLoadingView(message: '正在跳转到登录页…');
    }

    final size = MediaQuery.sizeOf(context);
    final isWide = size.width >= 1024;
    final session = auth.session!;
    final contentCard = GlassCard(
      borderRadius: 28,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 24),
          Expanded(child: child),
        ],
      ),
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColorTokens.backgroundGradientStart,
              AppColorTokens.backgroundGradientEnd,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1440),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: isWide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(
                            width: 260,
                            child: _AdminNav(
                              selectedIndex: selectedIndex,
                              phone: session.phone,
                              onLogout: () async {
                                await ref.read(adminAuthProvider.notifier).logout();
                                if (context.mounted) {
                                  context.go('/login');
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(child: contentCard),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _AdminNav(
                            selectedIndex: selectedIndex,
                            phone: session.phone,
                            onLogout: () async {
                              await ref.read(adminAuthProvider.notifier).logout();
                              if (context.mounted) {
                                context.go('/login');
                              }
                            },
                          ),
                          const SizedBox(height: 16),
                          Expanded(child: contentCard),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AdminNav extends StatelessWidget {
  final int selectedIndex;
  final String phone;
  final Future<void> Function() onLogout;

  const _AdminNav({
    required this.selectedIndex,
    required this.phone,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final destinations = const [
      _AdminNavItem(label: '后台总览', icon: Icons.dashboard_outlined, route: '/dashboard'),
      _AdminNavItem(label: '用户列表', icon: Icons.people_alt_outlined, route: '/users'),
      _AdminNavItem(label: '公告管理', icon: Icons.campaign_outlined, route: '/announcements'),
    ];

    return GlassCard(
      borderRadius: 28,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.admin_panel_settings_outlined, color: AppColorTokens.primary),
              SizedBox(width: 10),
              Text(
                '相伴课表后台',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColorTokens.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            '仅管理员可访问',
            style: TextStyle(color: AppColorTokens.textSecondary),
          ),
          const SizedBox(height: 20),
          for (var i = 0; i < destinations.length; i++) ...[
            _AdminNavButton(
              label: destinations[i].label,
              icon: destinations[i].icon,
              selected: selectedIndex == i,
              onTap: () => context.go(destinations[i].route),
            ),
            const SizedBox(height: 10),
          ],
          const Spacer(),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(110),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '当前管理员',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColorTokens.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  phone,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColorTokens.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: onLogout,
            icon: const Icon(Icons.logout_rounded),
            label: const Text('退出登录'),
          ),
        ],
      ),
    );
  }
}

class _AdminNavButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _AdminNavButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? Colors.white : AppColorTokens.textPrimary;
    final background = selected ? AppColorTokens.primary : Colors.white.withAlpha(110);

    return Material(
      color: background,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, color: foreground),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  color: foreground,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminNavItem {
  final String label;
  final IconData icon;
  final String route;

  const _AdminNavItem({
    required this.label,
    required this.icon,
    required this.route,
  });
}

class _AdminLoadingView extends StatelessWidget {
  final String message;

  const _AdminLoadingView({required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColorTokens.backgroundGradientStart,
              AppColorTokens.backgroundGradientEnd,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(message, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      ),
    );
  }
}
