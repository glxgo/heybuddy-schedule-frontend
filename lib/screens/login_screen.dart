import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../config/theme.dart';
import '../providers/auth_provider.dart';
import '../widgets/glass_card.dart';
import '../widgets/liquid_scaffold.dart';
import '../widgets/spring_button.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
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
    final result = await ref.read(authProvider.notifier).login(account: account, password: password);
    if (!mounted) return;
    if (result.success) {
      context.go('/daily');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message), backgroundColor: AppColorTokens.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    return LiquidScaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: GlassCard(
              borderRadius: 30,
              padding: const EdgeInsets.all(28),
              elevation: 2,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppColorTokens.authAction.withAlpha(20),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Image.asset('assets/images/app_icon.png'),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text('欢迎回来', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text('登录你的账号', style: TextStyle(fontSize: 14, color: AppColorTokens.textSecondary)),
                  const SizedBox(height: 32),
                  TextField(
                    controller: _accountCtrl,
                    decoration: const InputDecoration(
                      labelText: '账号',
                      hintText: '请输入账号或手机号',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _passwordCtrl,
                    obscureText: _obscure,
                    decoration: InputDecoration(
                      labelText: '密码',
                      hintText: '请输入密码',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _login(),
                  ),
                  const SizedBox(height: 24),
                  SpringButton(
                    onTap: authState.isLoading ? null : _login,
                    color: AppColorTokens.authAction,
                    gradient: AppColorTokens.authActionGradient,
                    child: authState.isLoading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('登录', style: TextStyle(fontSize: 16)),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextButton(onPressed: () => context.push('/forgot-password'), child: const Text('忘记密码？')),
                      const SizedBox(width: 8),
                      const Text('还没有账号？', style: TextStyle(color: AppColorTokens.textSecondary)),
                      TextButton(onPressed: () => context.push('/register'), child: const Text('立即注册')),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
