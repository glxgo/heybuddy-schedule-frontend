import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/theme.dart';
import '../../widgets/glass_card.dart';
import '../providers/admin_auth_provider.dart';
import '../providers/admin_dashboard_provider.dart';
import '../widgets/admin_shell.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(adminAuthProvider);
    final state = ref.watch(adminDashboardProvider);

    if (auth.isAuthenticated && !state.hasLoaded && !state.isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(adminDashboardProvider.notifier).load();
      });
    }

    return AdminShell(
      title: '后台总览',
      subtitle: '查看注册用户规模和登录记录覆盖情况',
      selectedIndex: 0,
      child: state.isLoading && state.stats == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (state.error != null) ...[
                    _MessageBanner(
                      message: state.error!,
                      actionLabel: '重试',
                      onTap: () => ref.read(adminDashboardProvider.notifier).load(),
                    ),
                    const SizedBox(height: 16),
                  ],
                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      _StatCard(
                        title: '总注册用户',
                        value: '${state.stats?.registeredUsers ?? 0}',
                        icon: Icons.people_alt_outlined,
                        color: AppColorTokens.primary,
                      ),
                      _StatCard(
                        title: '已记录登录',
                        value: '${state.stats?.usersWithLastLogin ?? 0}',
                        icon: Icons.login_rounded,
                        color: AppColorTokens.accent,
                      ),
                      _StatCard(
                        title: '历史未记录',
                        value: '${state.stats?.neverLoggedInUsers ?? 0}',
                        icon: Icons.history_toggle_off_rounded,
                        color: AppColorTokens.warning,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  GlassCard(
                    borderRadius: 24,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '说明',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColorTokens.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          '老用户在后台上线前没有保存过“上次登录时间”，因此会显示为“未记录”；之后的新注册和新登录都会开始准确统计。',
                          style: TextStyle(color: AppColorTokens.textSecondary, height: 1.55),
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            ElevatedButton.icon(
                              onPressed: () => context.go('/users'),
                              icon: const Icon(Icons.people_alt_outlined),
                              label: const Text('查看用户列表'),
                            ),
                            ElevatedButton.icon(
                              onPressed: () => context.go('/announcements'),
                              icon: const Icon(Icons.campaign_outlined),
                              label: const Text('公告管理'),
                            ),
                            OutlinedButton.icon(
                              onPressed: () => ref.read(adminDashboardProvider.notifier).load(),
                              icon: const Icon(Icons.refresh_rounded),
                              label: const Text('刷新统计'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 280,
      child: GlassCard(
        borderRadius: 24,
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: color.withAlpha(28),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColorTokens.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: AppColorTokens.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBanner extends StatelessWidget {
  final String message;
  final String actionLabel;
  final VoidCallback onTap;

  const _MessageBanner({
    required this.message,
    required this.actionLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColorTokens.error.withAlpha(18),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColorTokens.error.withAlpha(50)),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            message,
            style: const TextStyle(color: AppColorTokens.textPrimary),
          ),
          TextButton(onPressed: onTap, child: Text(actionLabel)),
        ],
      ),
    );
  }
}
