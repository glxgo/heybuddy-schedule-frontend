import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/bottom_sheet_helper.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/liquid_scaffold.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  Map<String, dynamic>? _profile;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final api = ref.read(apiServiceProvider);
    final res = await api.get('/user/profile');
    if (mounted) {
      setState(() {
        if (res.isSuccess) _profile = res.data;
        _loading = false;
      });
    }
  }

  Future<void> _showThemePicker() async {
    final currentId = ref.read(settingsProvider).backgroundThemeId;
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withAlpha(38),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: GlassCard(
              borderRadius: 28,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              elevation: 1.6,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Center(
                      child: Text(
                        '背景主题',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(height: 14),
                    ...AppBackgroundThemes.themes.map((theme) {
                      final selected = theme.id == currentId;
                      return ListTile(
                        minTileHeight: 56,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                        leading: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [theme.start, theme.end],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: selected
                                  ? AppColorTokens.primary
                                  : Colors.white.withAlpha(140),
                              width: selected ? 1.8 : 0.8,
                            ),
                          ),
                        ),
                        title: Text(
                          theme.label,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        trailing: selected
                            ? const Icon(
                                Icons.check_circle_rounded,
                                color: AppColorTokens.primary,
                              )
                            : null,
                        onTap: () async {
                          await ref
                              .read(settingsProvider.notifier)
                              .setBackgroundTheme(theme.id);
                          if (ctx.mounted) Navigator.pop(ctx);
                        },
                      );
                    }),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showEditNicknameDialog() async {
    final ctrl = TextEditingController(text: (_profile?['nickname'] ?? '').toString());
    final nickname = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('修改用户名'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLength: 30,
          decoration: const InputDecoration(
            hintText: '请输入新的用户名',
            border: OutlineInputBorder(),
            counterText: '',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (nickname == null || nickname.isEmpty) return;
    final result = await ref.read(authProvider.notifier).updateNickname(nickname);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.message)),
    );
    if (result.success) {
      await _loadProfile();
    }
  }

  Future<void> _showChangePhoneDialog() async {
    final phoneCtrl = TextEditingController(text: (_profile?['phone'] ?? '').toString());
    final codeCtrl = TextEditingController();
    var sending = false;
    var saving = false;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('修改绑定手机号'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  maxLength: 11,
                  decoration: const InputDecoration(
                    labelText: '新手机号',
                    border: OutlineInputBorder(),
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: codeCtrl,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        decoration: const InputDecoration(
                          labelText: '验证码',
                          border: OutlineInputBorder(),
                          counterText: '',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      height: 52,
                      child: OutlinedButton(
                        onPressed: sending
                            ? null
                            : () async {
                                final phone = phoneCtrl.text.trim();
                                if (phone.length != 11) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('请输入正确的手机号')),
                                  );
                                  return;
                                }
                                setDialogState(() => sending = true);
                                final result = await ref
                                    .read(authProvider.notifier)
                                    .sendPhoneChangeCode(phone);
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(result.message)),
                                );
                                if (ctx.mounted) {
                                  setDialogState(() => sending = false);
                                }
                              },
                        child: Text(sending ? '发送中' : '发送验证码'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: saving
                  ? null
                  : () async {
                      final phone = phoneCtrl.text.trim();
                      final code = codeCtrl.text.trim();
                      if (phone.length != 11) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('请输入正确的手机号')),
                        );
                        return;
                      }
                      if (code.length != 6) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('请输入6位验证码')),
                        );
                        return;
                      }
                      setDialogState(() => saving = true);
                      final result = await ref
                          .read(authProvider.notifier)
                          .updatePhone(phone, code);
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(result.message)),
                      );
                      if (result.success && ctx.mounted) {
                        Navigator.pop(ctx);
                        await _loadProfile();
                      } else if (ctx.mounted) {
                        setDialogState(() => saving = false);
                      }
                    },
              child: Text(saving ? '保存中...' : '确认修改'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showChangePasswordDialog() async {
    final oldCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    var saving = false;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('修改密码'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: oldCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: '旧密码',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: newCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: '新密码',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: confirmCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: '确认新密码',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: saving
                  ? null
                  : () async {
                      final oldPassword = oldCtrl.text.trim();
                      final newPassword = newCtrl.text.trim();
                      final confirmPassword = confirmCtrl.text.trim();
                      if (oldPassword.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('请输入旧密码')),
                        );
                        return;
                      }
                      if (newPassword.length < 6) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('新密码至少 6 位')),
                        );
                        return;
                      }
                      if (newPassword != confirmPassword) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('两次输入的新密码不一致')),
                        );
                        return;
                      }
                      setDialogState(() => saving = true);
                      final result = await ref
                          .read(authProvider.notifier)
                          .updatePassword(oldPassword, newPassword);
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(result.message)),
                      );
                      if (result.success && ctx.mounted) {
                        Navigator.pop(ctx);
                      } else if (ctx.mounted) {
                        setDialogState(() => saving = false);
                      }
                    },
              child: Text(saving ? '提交中...' : '确认修改'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAccountActions() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return buildAppBottomSheetFrame(
          ctx,
          alignment: Alignment.center,
          left: 16,
          right: 16,
          top: 80,
          maxWidth: 460,
          maxHeightFactor: 0.68,
          bottomNavClearance: 72,
          child: GlassCard(
            borderRadius: 28,
            padding: const EdgeInsets.fromLTRB(10, 16, 10, 10),
            elevation: 1.5,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColorTokens.primary.withAlpha(90),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '编辑账号信息',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  _Tile(
                    icon: Icons.badge_outlined,
                    title: '修改用户名',
                    subtitle: '更新你的昵称展示',
                    onTap: () {
                      Navigator.pop(ctx);
                      _showEditNicknameDialog();
                    },
                  ),
                  _Tile(
                    icon: Icons.phone_android_rounded,
                    title: '修改绑定手机号',
                    subtitle: '更换当前登录账号绑定的手机号',
                    onTap: () {
                      Navigator.pop(ctx);
                      _showChangePhoneDialog();
                    },
                  ),
                  _Tile(
                    icon: Icons.lock_outline_rounded,
                    title: '修改密码',
                    subtitle: '需要先输入旧密码',
                    onTap: () {
                      Navigator.pop(ctx);
                      _showChangePasswordDialog();
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final currentTheme = AppBackgroundThemes.byId(settings.backgroundThemeId);
    final nickname = _profile?['nickname'] ?? '相伴用户';
    final phone = (_profile?['phone'] ?? '').toString();
    final school = _profile?['schoolName'];
    final maskedPhone = phone.length >= 11
        ? '${phone.substring(0, 3)}****${phone.substring(7)}'
        : phone;

    return LiquidScaffold(
      appBar: AppBar(title: const Text('我的')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 118),
        children: [
          GlassCard(
            borderRadius: 30,
            padding: const EdgeInsets.all(22),
            onTap: _showAccountActions,
            elevation: 1.4,
            gradient: const LinearGradient(
              colors: [Color(0x332563EB), Color(0x33FB7185)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            child: Row(
              children: [
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [
                        AppColorTokens.accent,
                        AppColorTokens.primaryGradientEnd,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColorTokens.accent.withAlpha(38),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      nickname.isNotEmpty ? nickname[0].toUpperCase() : '?',
                      style: const TextStyle(
                        fontSize: 24,
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nickname,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: AppColorTokens.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 5),
                      if (maskedPhone.isNotEmpty)
                        Text(
                          maskedPhone,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColorTokens.textSecondary,
                          ),
                        ),
                      if (school != null &&
                          school.toString().trim().isNotEmpty) ...[
                        const SizedBox(height: 7),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColorTokens.accent.withAlpha(18),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColorTokens.accent.withAlpha(45),
                            ),
                          ),
                          child: Text(
                            school.toString(),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColorTokens.accent,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (_loading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColorTokens.primary,
                    ),
                  )
                else
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(120),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColorTokens.glassBorder.withAlpha(100),
                      ),
                    ),
                    child: const Icon(
                      Icons.edit_outlined,
                      size: 18,
                      color: AppColorTokens.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _Section(
            title: '课表',
            children: [
              _Tile(
                icon: Icons.settings_outlined,
                title: '课表设置',
                onTap: () => context.push('/table-manage'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _Section(
            title: '通用',
            children: [
              _Tile(
                icon: Icons.palette_outlined,
                title: '背景主题',
                subtitle: currentTheme.label,
                onTap: _showThemePicker,
              ),
              _Tile(
                icon: Icons.groups_rounded,
                title: '加入 QQ 交流群',
                subtitle: '和大家一起交流课表适配与功能建议',
                onTap: () =>
                    launchUrl(Uri.parse('https://qm.qq.com/q/GEn92WE76k')),
              ),
              _Tile(
                icon: Icons.info_outline_rounded,
                title: '关于相伴课表',
                onTap: () => context.push('/about'),
              ),
            ],
          ),
          const SizedBox(height: 28),
          OutlinedButton.icon(
            onPressed: () async {
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) context.go('/login');
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColorTokens.error,
              side: const BorderSide(color: AppColorTokens.error),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            icon: const Icon(Icons.logout_rounded, size: 18),
            label: const Text('退出登录'),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColorTokens.textTertiary,
            ),
          ),
        ),
        GlassCard(
          borderRadius: 24,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  const _Tile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      minTileHeight: 56,
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppColorTokens.primary.withAlpha(18),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, size: 20, color: AppColorTokens.primary),
      ),
      title: Text(
        title,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle!,
              style: const TextStyle(
                fontSize: 12,
                color: AppColorTokens.textTertiary,
              ),
            ),
      trailing: const Icon(
        Icons.chevron_right_rounded,
        size: 20,
        color: AppColorTokens.textTertiary,
      ),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    );
  }
}
