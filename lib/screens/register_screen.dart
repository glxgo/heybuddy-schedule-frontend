import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../config/theme.dart';
import '../providers/auth_provider.dart';
import '../widgets/glass_card.dart';
import '../widgets/liquid_scaffold.dart';
import '../widgets/spring_button.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  String _channel = 'email'; // 'phone' or 'email'
  final _accountCtrl = TextEditingController();
  final _targetCtrl = TextEditingController();
  final _nicknameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  bool _obscure = true;
  bool _obscureConfirm = true;
  bool _sending = false;
  bool _registering = false;
  int _countdown = 0;
  Timer? _timer;

  @override
  void dispose() {
    _accountCtrl.dispose();
    _targetCtrl.dispose();
    _nicknameCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    _codeCtrl.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    setState(() => _countdown = 60);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() {
        if (_countdown <= 1) { _countdown = 0; t.cancel(); } else { _countdown--; }
      });
    });
  }

  Future<void> _sendCode() async {
    final target = _targetCtrl.text.trim();
    if (_channel == 'phone' && target.length != 11) {
      _showError('请输入正确的手机号');
      return;
    }
    if (_channel == 'email' && !target.contains('@')) {
      _showError('请输入正确的邮箱地址');
      return;
    }

    setState(() => _sending = true);
    final result = await ref.read(authProvider.notifier).sendVerificationCode(
      purpose: 'register',
      channel: _channel,
      target: target,
    );
    if (!mounted) return;
    setState(() => _sending = false);

    if (result.success) {
      _startCountdown();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message), backgroundColor: AppColorTokens.success));
    } else {
      _showError(result.message);
    }
  }

  Future<void> _register() async {
    final account = _accountCtrl.text.trim();
    final target = _targetCtrl.text.trim();
    final nickname = _nicknameCtrl.text.trim();
    final password = _passwordCtrl.text;
    final confirm = _confirmCtrl.text;
    final code = _codeCtrl.text.trim();

    if (account.isEmpty || target.isEmpty || nickname.isEmpty || password.isEmpty) {
      _showError('请填写所有必填项');
      return;
    }
    if (account.length < 4 || account.length > 32) {
      _showError('账号需要4-32个字符');
      return;
    }
    if (_channel == 'phone' && target.length != 11) {
      _showError('请输入正确的手机号');
      return;
    }
    if (_channel == 'email' && !target.contains('@')) {
      _showError('请输入正确的邮箱地址');
      return;
    }
    if (code.length != 6) {
      _showError('请输入6位验证码');
      return;
    }
    if (password.length < 6) {
      _showError('密码至少6位');
      return;
    }
    if (password != confirm) {
      _showError('两次输入的密码不一致');
      return;
    }

    setState(() => _registering = true);
    final result = await ref.read(authProvider.notifier).register(
      channel: _channel,
      target: target,
      code: code,
      account: account,
      password: password,
      nickname: nickname,
    );
    if (!mounted) return;
    setState(() => _registering = false);

    if (result.success) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message), backgroundColor: AppColorTokens.success));
      context.go('/daily');
    } else {
      _showError(result.message);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: AppColorTokens.error));
  }

  @override
  Widget build(BuildContext context) {
    final isPhone = _channel == 'phone';

    return LiquidScaffold(
      appBar: AppBar(title: const Text('注册账号')),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 34),
          child: GlassCard(
            borderRadius: 30,
            padding: const EdgeInsets.all(24),
            elevation: 1.4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('创建新账号', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppColorTokens.textPrimary)),
                const SizedBox(height: 8),
                const Text('注册后即可同步课表数据到云端', style: TextStyle(fontSize: 14, color: AppColorTokens.textSecondary, height: 1.5)),
                const SizedBox(height: 22),
                // Channel toggle
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(140),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.all(4),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _channel = 'phone'),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: isPhone ? AppColorTokens.authAction : Colors.transparent,
                              borderRadius: BorderRadius.circular(11),
                            ),
                            child: Center(
                              child: Text('手机号注册', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: isPhone ? Colors.white : AppColorTokens.textSecondary)),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _channel = 'email'),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: !isPhone ? AppColorTokens.authAction : Colors.transparent,
                              borderRadius: BorderRadius.circular(11),
                            ),
                            child: Center(
                              child: Text('邮箱注册', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: !isPhone ? Colors.white : AppColorTokens.textSecondary)),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                TextField(
                  controller: _accountCtrl,
                  textInputAction: TextInputAction.next,
                  maxLength: 32,
                  decoration: const InputDecoration(
                    labelText: '账号 *',
                    hintText: '4-32位字母/数字，登录时使用',
                    prefixIcon: Icon(Icons.person_outline),
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _targetCtrl,
                  keyboardType: isPhone ? TextInputType.phone : TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  maxLength: isPhone ? 11 : null,
                  decoration: InputDecoration(
                    labelText: isPhone ? '手机号 *' : '邮箱 *',
                    hintText: isPhone ? '请输入手机号' : '请输入邮箱地址',
                    prefixIcon: Icon(isPhone ? Icons.phone_iphone_outlined : Icons.email_outlined),
                    counterText: isPhone ? '' : null,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _codeCtrl,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        decoration: const InputDecoration(
                          labelText: '验证码 *',
                          hintText: '6位验证码',
                          prefixIcon: Icon(Icons.sms_outlined),
                          counterText: '',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 112,
                      child: SpringButton(
                        height: 52,
                        color: AppColorTokens.authAction,
                        gradient: AppColorTokens.authActionGradient,
                        enabled: _countdown == 0 && !_sending,
                        onTap: _countdown > 0 || _sending ? null : _sendCode,
                        child: _sending
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : Text(_countdown > 0 ? '${_countdown}s' : '获取验证码', style: const TextStyle(fontSize: 13)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _nicknameCtrl,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: '昵称 *',
                    hintText: '你想让大家怎么称呼你',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordCtrl,
                  obscureText: _obscure,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: '密码 *',
                    hintText: '至少6位',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _confirmCtrl,
                  obscureText: _obscureConfirm,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _register(),
                  decoration: InputDecoration(
                    labelText: '确认密码 *',
                    hintText: '再输入一次密码',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(_obscureConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                      onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                SpringButton(
                  enabled: !_registering,
                  color: AppColorTokens.authAction,
                  gradient: AppColorTokens.authActionGradient,
                  onTap: _registering ? null : _register,
                  child: _registering
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('注册', style: TextStyle(fontSize: 16)),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('已有账号？', style: TextStyle(color: AppColorTokens.textSecondary)),
                    TextButton(onPressed: () => context.pop(), child: const Text('去登录')),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
