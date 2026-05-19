import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
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
  static const MethodChannel _nativeChannel = MethodChannel(
    'heybuddy_schedule/widget',
  );
  static Map<String, dynamic>? _cachedProfile;
  static DateTime? _cachedProfileAt;
  static int? _cachedUnreadCount;
  static DateTime? _cachedUnreadCountAt;
  static Future<Map<String, dynamic>?>? _profileRequest;
  static Future<int?>? _unreadCountRequest;
  static const _profileCacheTtl = Duration(minutes: 2);
  static const _unreadCountCacheTtl = Duration(seconds: 45);

  Map<String, dynamic>? _profile;
  bool _loading = true;
  int _unreadCount = 0;

  Color _solidThemeColor(Color color) {
    return color.withAlpha(255);
  }

  @override
  void initState() {
    super.initState();
    final currentUserId = ref.read(authProvider).userId;
    final cachedUserId = _cachedProfile?['id']?.toString();
    if (currentUserId != null && cachedUserId != null && cachedUserId != currentUserId) {
      _cachedProfile = null;
      _cachedProfileAt = null;
      _cachedUnreadCount = null;
      _cachedUnreadCountAt = null;
    }
    if (_cachedProfile != null) {
      _profile = Map<String, dynamic>.from(_cachedProfile!);
      _loading = false;
    }
    if (_cachedUnreadCount != null) {
      _unreadCount = _cachedUnreadCount!;
    }
    _loadProfile(forceRefresh: _cachedProfile == null);
    _loadUnreadCount(forceRefresh: _cachedUnreadCount == null);
  }

  bool get _hasFreshProfileCache =>
      _cachedProfile != null &&
      _cachedProfileAt != null &&
      DateTime.now().difference(_cachedProfileAt!) < _profileCacheTtl;

  bool get _hasFreshUnreadCountCache =>
      _cachedUnreadCount != null &&
      _cachedUnreadCountAt != null &&
      DateTime.now().difference(_cachedUnreadCountAt!) < _unreadCountCacheTtl;

  Future<void> _loadUnreadCount({bool forceRefresh = false}) async {
    if (!forceRefresh && _hasFreshUnreadCountCache) {
      if (mounted) {
        setState(() => _unreadCount = _cachedUnreadCount!);
      }
      return;
    }

    final request = _unreadCountRequest ??= () async {
      final api = ref.read(apiServiceProvider);
      final res = await api.get('/announcements/unread-count');
      if (res.isSuccess && res.data != null) {
        return (res.data['unreadCount'] ?? 0) as int;
      }
      return null;
    }();

    final unreadCount = await request;
    if (identical(_unreadCountRequest, request)) {
      _unreadCountRequest = null;
    }
    if (!mounted || unreadCount == null) return;

    _cachedUnreadCount = unreadCount;
    _cachedUnreadCountAt = DateTime.now();
    setState(() => _unreadCount = unreadCount);
  }

  Future<void> _loadProfile({bool forceRefresh = false}) async {
    if (!forceRefresh && _hasFreshProfileCache) {
      if (mounted) {
        setState(() {
          _profile = Map<String, dynamic>.from(_cachedProfile!);
          _loading = false;
        });
      }
      return;
    }

    if (_profile == null && mounted) {
      setState(() => _loading = true);
    }

    final request = _profileRequest ??= () async {
      final api = ref.read(apiServiceProvider);
      final res = await api.get('/user/profile');
      if (res.isSuccess && res.data != null) {
        return Map<String, dynamic>.from(res.data as Map);
      }
      return null;
    }();

    final profile = await request;
    if (identical(_profileRequest, request)) {
      _profileRequest = null;
    }
    if (!mounted) return;

    setState(() {
      if (profile != null) {
        _profile = profile;
        _cachedProfile = Map<String, dynamic>.from(profile);
        _cachedProfileAt = DateTime.now();
      }
      _loading = false;
    });
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
                                  ? theme.orbPrimary.withAlpha(255)
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
                            ? Icon(
                                Icons.check_circle_rounded,
                                color: theme.orbPrimary.withAlpha(255),
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
      await _loadProfile(forceRefresh: true);
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
                        await _loadProfile(forceRefresh: true);
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

  Future<void> _pickAndUploadAvatar() async {
    final picker = ImagePicker();
    final theme = AppBackgroundThemes.byId(
      ref.read(settingsProvider).backgroundThemeId,
    );
    final primary = _solidThemeColor(theme.orbPrimary);
    final secondary = _solidThemeColor(theme.orbSecondary);
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => buildAppBottomSheetFrame(
        ctx,
        alignment: Alignment.center,
        left: 16,
        right: 16,
        top: 56,
        maxWidth: 480,
        maxHeightFactor: 0.62,
        bottomNavClearance: 72,
        child: GlassCard(
          borderRadius: 32,
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: primary.withAlpha(100),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                '更换头像',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: primary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '你可以拍一张新的照片，或者从相册里选择一张喜欢的头像。',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColorTokens.textSecondary,
                  height: 1.55,
                ),
              ),
              const SizedBox(height: 18),
              _Tile(
                icon: Icons.camera_alt_outlined,
                title: '拍照',
                subtitle: '现在拍一张新的头像照片',
                accentColor: primary,
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              _Tile(
                icon: Icons.photo_library_outlined,
                title: '从相册选择',
                subtitle: '从手机相册里挑一张图片',
                accentColor: secondary,
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );

    if (source == null) return;

    final file = await picker.pickImage(source: source, maxWidth: 256, maxHeight: 256, imageQuality: 80);
    if (file == null || !mounted) return;

    setState(() => _loading = true);
    try {
      final bytes = await File(file.path).readAsBytes();
      final b64 = base64Encode(bytes);
      final ext = file.path.endsWith('.png') ? 'png' : 'jpg';
      final dataUri = 'data:image/$ext;base64,$b64';

      final api = ref.read(apiServiceProvider);
      final res = await api.post('/uploads/avatar', data: {'image': dataUri});
      if (mounted) {
        if (res.isSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('头像已更新')));
          await _loadProfile(forceRefresh: true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res.msg), backgroundColor: AppColorTokens.error));
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('上传失败: $e'), backgroundColor: AppColorTokens.error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _showAccountActions() async {
    final theme = AppBackgroundThemes.byId(
      ref.read(settingsProvider).backgroundThemeId,
    );
    final primary = _solidThemeColor(theme.orbPrimary);
    final secondary = _solidThemeColor(theme.orbSecondary);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return buildAppBottomSheetFrame(
          ctx,
          alignment: Alignment.center,
          left: 16,
          right: 16,
          top: 48,
          maxWidth: 500,
          maxHeightFactor: 0.76,
          bottomNavClearance: 72,
          child: GlassCard(
            borderRadius: 32,
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
            elevation: 1.5,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: primary.withAlpha(100),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    '编辑账号信息',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '在这里修改昵称、账号和密码，让账号信息保持最新。',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColorTokens.textSecondary,
                      height: 1.55,
                    ),
                  ),
                  const SizedBox(height: 18),
                  _Tile(
                    icon: Icons.badge_outlined,
                    title: '修改用户名',
                    subtitle: '更新你的昵称展示',
                    accentColor: primary,
                    onTap: () {
                      Navigator.pop(ctx);
                      _showEditNicknameDialog();
                    },
                  ),
                  _Tile(
                    icon: Icons.person_outline,
                    title: '修改账号',
                    subtitle: '修改登录使用的账号名',
                    accentColor: secondary,
                    onTap: () {
                      Navigator.pop(ctx);
                      _showChangeAccountDialog();
                    },
                  ),
                  _Tile(
                    icon: Icons.lock_outline_rounded,
                    title: '修改密码',
                    subtitle: '需要先输入旧密码',
                    accentColor: primary,
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

  Future<void> _showChangeAccountDialog() async {
    final ctrl = TextEditingController(text: (_profile?['account'] ?? '').toString());
    final account = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('修改账号'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLength: 32,
          decoration: const InputDecoration(
            hintText: '请输入新的账号（4-32位）',
            border: OutlineInputBorder(),
            counterText: '',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('保存')),
        ],
      ),
    );
    if (account == null || account.isEmpty) return;
    if (account.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('账号需要4-32个字符'), backgroundColor: AppColorTokens.error));
      return;
    }
    final result = await ref.read(authProvider.notifier).updateAccount(account);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message)));
    if (result.success) await _loadProfile(forceRefresh: true);
  }

  Widget _buildAvatarInitial(String nickname) {
    return Center(
      child: Text(
        nickname.isNotEmpty ? nickname[0].toUpperCase() : '?',
        style: const TextStyle(fontSize: 24, color: Colors.white, fontWeight: FontWeight.w900),
      ),
    );
  }

  Future<void> _saveRewardQrToGallery() async {
    try {
      final byteData = await rootBundle.load('assets/images/reward_qr.png');
      final bytes = byteData.buffer.asUint8List();
      final ok = await _nativeChannel.invokeMethod<bool>('saveImageToGallery', {
        'bytes': bytes,
        'name': 'heybuddy_reward_qr',
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok == true ? '二维码已保存到系统相册' : '保存失败，请稍后重试'),
          backgroundColor: ok == true ? AppColorTokens.success : AppColorTokens.error,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('保存失败，请稍后重试'),
          backgroundColor: AppColorTokens.error,
        ),
      );
    }
  }

  Future<void> _showRewardDialog() async {
    final settings = ref.read(settingsProvider);
    final theme = AppBackgroundThemes.byId(settings.backgroundThemeId);
    final primary = _solidThemeColor(theme.orbPrimary);

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => buildAppBottomSheetFrame(
        ctx,
        alignment: Alignment.center,
        left: 16,
        right: 16,
        top: 48,
        maxWidth: 500,
        maxHeightFactor: 0.82,
        bottomNavClearance: 72,
        child: GlassCard(
          borderRadius: 32,
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
          elevation: 1.5,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: primary.withAlpha(100),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  '赞赏支持',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: primary,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  '本APP由25级在校生开发，服务器、域名等都是一笔较大的支出，如果您认可我的项目，可以赞赏支持我，我将继续用于APP开发',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.65,
                    color: AppColorTokens.textSecondary,
                  ),
                ),
                const SizedBox(height: 20),
                ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Image.asset(
                    'assets/images/reward_qr.png',
                    width: 280,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 18),
                OutlinedButton.icon(
                  onPressed: _saveRewardQrToGallery,
                  icon: const Icon(Icons.download_rounded),
                  label: const Text('保存图片到相册'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认退出登录？'),
        content: const Text('退出后需要重新登录才能继续使用相伴课表。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColorTokens.error,
            ),
            child: const Text('退出登录'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await ref.read(authProvider.notifier).logout();
    if (!mounted) return;
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final currentTheme = AppBackgroundThemes.byId(settings.backgroundThemeId);
    final themePrimary = _solidThemeColor(currentTheme.orbPrimary);
    final themeSecondary = _solidThemeColor(currentTheme.orbSecondary);

    if (_loading && _profile == null) {
      return LiquidScaffold(
        appBar: AppBar(title: const Text('我的')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: themePrimary),
              const SizedBox(height: 14),
              const Text(
                '正在加载你的信息…',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColorTokens.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (!_loading && _profile == null) {
      return LiquidScaffold(
        appBar: AppBar(title: const Text('我的')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: GlassCard(
              borderRadius: 28,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.cloud_off_rounded, size: 40, color: themePrimary),
                  const SizedBox(height: 16),
                  const Text(
                    '个人信息加载失败',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '请稍后重试一下，或者检查网络连接。',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: AppColorTokens.textSecondary),
                  ),
                  const SizedBox(height: 18),
                  ElevatedButton.icon(
                    onPressed: () => _loadProfile(forceRefresh: true),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('重新加载'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final nickname = _profile?['nickname'] ?? '相伴用户';
    final phone = (_profile?['phone'] ?? '').toString();
    final school = _profile?['schoolName'];
    final avatarUrl = _profile?['avatarUrl'] as String?;
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
            gradient: LinearGradient(
              colors: [
                themePrimary.withAlpha(34),
                themeSecondary.withAlpha(34),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: _pickAndUploadAvatar,
                  child: Stack(
                    children: [
                      Container(
                        width: 68,
                        height: 68,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: avatarUrl == null
                              ? LinearGradient(
                                  colors: [themePrimary, themeSecondary],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                )
                              : null,
                          boxShadow: [
                            BoxShadow(
                              color: themePrimary.withAlpha(38),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: avatarUrl != null
                            ? ClipOval(child: Image.network(avatarUrl, width: 68, height: 68, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _buildAvatarInitial(nickname)))
                            : _buildAvatarInitial(nickname),
                      ),
                      Positioned(
                        right: 0, bottom: 0,
                        child: Container(
                          width: 22, height: 22,
                          decoration: BoxDecoration(
                            color: themePrimary,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(Icons.camera_alt, size: 12, color: Colors.white),
                        ),
                      ),
                    ],
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
                            color: themeSecondary.withAlpha(18),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: themeSecondary.withAlpha(45),
                            ),
                          ),
                          child: Text(
                            school.toString(),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: themeSecondary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (_loading)
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: themePrimary,
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
                accentColor: themePrimary,
                onTap: () => context.push('/table-manage'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _Section(
            title: '公告',
            children: [
              _Tile(
                icon: Icons.campaign_rounded,
                title: '系统公告',
                subtitle: _unreadCount > 0 ? '有 $_unreadCount 条未读公告' : '暂无新公告',
                accentColor: themeSecondary,
                trailing: _unreadCount > 0
                    ? Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: AppColorTokens.error, borderRadius: BorderRadius.circular(10)), child: Text('$_unreadCount', style: const TextStyle(color: Colors.white, fontSize: 12)))
                    : null,
                onTap: () async {
                  await context.push('/announcements');
                  if (mounted) {
                    await _loadUnreadCount(forceRefresh: true);
                  }
                },
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
                accentColor: themePrimary,
                onTap: _showThemePicker,
              ),
              _Tile(
                icon: Icons.groups_rounded,
                title: '加入 QQ 交流群',
                subtitle: '和大家一起交流课表适配与功能建议',
                accentColor: themeSecondary,
                onTap: () =>
                    launchUrl(Uri.parse('https://qm.qq.com/q/GEn92WE76k')),
              ),
              _Tile(
                icon: Icons.volunteer_activism_outlined,
                title: '赞赏支持',
                subtitle: '支持开发与服务器持续运行',
                accentColor: themeSecondary,
                onTap: _showRewardDialog,
              ),
              _Tile(
                icon: Icons.info_outline_rounded,
                title: '关于相伴课表',
                accentColor: themePrimary,
                onTap: () => context.push('/about'),
              ),
            ],
          ),
          const SizedBox(height: 28),
          OutlinedButton.icon(
            onPressed: _confirmLogout,
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
  final Widget? trailing;
  final Color accentColor;

  const _Tile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.trailing,
    this.accentColor = AppColorTokens.primary,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      minTileHeight: 56,
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: accentColor.withAlpha(18),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, size: 20, color: accentColor),
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
      trailing: trailing ?? const Icon(
        Icons.chevron_right_rounded,
        size: 20,
        color: AppColorTokens.textTertiary,
      ),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    );
  }
}
