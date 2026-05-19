import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/theme.dart';
import '../../widgets/glass_card.dart';
import '../providers/admin_auth_provider.dart';

class AdminLoginScreen extends ConsumerStatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  ConsumerState<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends ConsumerState<AdminLoginScreen> {
  final _accountCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _accountCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final account = _accountCtrl.text.trim();
    final password = _passwordCtrl.text;
    if (account.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入账号和密码')),
      );
      return;
    }

    final result = await ref.read(adminAuthProvider.notifier).login(phone: account, password: password);
    if (!mounted) return;
    if (result.success) {
      context.go('/dashboard');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message), backgroundColor: AppColorTokens.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(adminAuthProvider);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColorTokens.backgroundGradientStart, AppColorTokens.backgroundGradientEnd],
            begin: Alignment.topLeft, end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: GlassCard(
                  borderRadius: 32,
                  padding: const EdgeInsets.fromLTRB(28, 30, 28, 28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 84, height: 84,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppColorTokens.primary, AppColorTokens.primaryGradientEnd],
                            begin: Alignment.topLeft, end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [BoxShadow(color: AppColorTokens.primary.withAlpha(70), blurRadius: 24, offset: const Offset(0, 12))],
                        ),
                        child: const Icon(Icons.admin_panel_settings_outlined, size: 42, color: Colors.white),
                      ),
                      const SizedBox(height: 22),
                      const Text('相伴课表后台', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: AppColorTokens.textPrimary)),
                      const SizedBox(height: 8),
                      const Text('仅管理员账号可以查看用户数据', style: TextStyle(fontSize: 14, color: AppColorTokens.textSecondary)),
                      const SizedBox(height: 28),
                      TextField(
                        controller: _accountCtrl,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: '管理员账号',
                          hintText: '请输入账号或手机号',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _passwordCtrl,
                        obscureText: _obscure,
                        onSubmitted: (_) => _login(),
                        decoration: InputDecoration(
                          labelText: '密码',
                          hintText: '请输入密码',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            onPressed: () => setState(() => _obscure = !_obscure),
                            icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: auth.isLoading ? null : _login,
                          icon: auth.isLoading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.login_rounded),
                          label: Text(auth.isLoading ? '正在登录…' : '登录后台'),
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text('登录成功后会再次校验管理员权限，普通用户账号无法进入。', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: AppColorTokens.textSecondary)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
