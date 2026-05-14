import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../config/theme.dart';
import '../providers/auth_provider.dart';
import '../widgets/glass_card.dart';
import '../widgets/liquid_scaffold.dart';
import '../widgets/spring_button.dart';

const _actionCyan = Color(0xFF7BA5B8);
const _actionCyanLight = Color(0xFF9EC5D4);
const _actionCyanGradient = LinearGradient(
  colors: [_actionCyan, _actionCyanLight],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _phoneCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;
  bool _codeSent = false;
  bool _sending = false;
  int _countdown = 0;
  Timer? _timer;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _codeCtrl.dispose();
    _passwordCtrl.dispose();
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final phone = _phoneCtrl.text.trim();
    if (phone.length != 11) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请输入正确的手机号')));
      return;
    }
    setState(() => _sending = true);
    try {
      final result = await ref
          .read(authProvider.notifier)
          .sendForgotPasswordCode(phone);
      if (!mounted) return;
      if (result.success) {
        setState(() {
          _codeSent = true;
          _countdown = 60;
        });
        _timer?.cancel();
        _timer = Timer.periodic(const Duration(seconds: 1), (t) {
          if (!mounted) {
            t.cancel();
            return;
          }
          setState(() {
            if (_countdown <= 1) {
              t.cancel();
              _countdown = 0;
              return;
            }
            _countdown--;
          });
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: AppColorTokens.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _reset() async {
    final phone = _phoneCtrl.text.trim();
    final code = _codeCtrl.text.trim();
    final password = _passwordCtrl.text;

    if (phone.length != 11) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请输入正确的手机号')));
      return;
    }
    if (code.length != 6) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请输入6位验证码')));
      return;
    }
    if (password.length < 6) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('新密码至少6位')));
      return;
    }

    setState(() => _sending = true);
    final result = await ref
        .read(authProvider.notifier)
        .resetPassword(phone, code, password);
    if (!mounted) return;
    setState(() => _sending = false);

    if (result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('密码重置成功，请重新登录'),
          backgroundColor: AppColorTokens.success,
        ),
      );
      context.pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: AppColorTokens.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return LiquidScaffold(
      appBar: AppBar(title: const Text('忘记密码')),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 32),
          child: GlassCard(
            borderRadius: 30,
            padding: const EdgeInsets.all(24),
            elevation: 1.4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  '重置密码',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: AppColorTokens.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '输入注册手机号，获取验证码后设置新密码',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColorTokens.textSecondary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 28),
                TextField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  maxLength: 11,
                  enabled: !_codeSent,
                  decoration: const InputDecoration(
                    labelText: '手机号',
                    hintText: '请输入注册手机号',
                    prefixIcon: Icon(Icons.phone_iphone_outlined),
                    counterText: '',
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
                          labelText: '验证码',
                          hintText: '请输入验证码',
                          prefixIcon: Icon(Icons.message_outlined),
                          counterText: '',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 104,
                      child: SpringButton(
                        height: 52,
                        color: _actionCyan,
                        gradient: _actionCyanGradient,
                        enabled: _countdown == 0 && !_sending,
                        onTap: _countdown > 0 || _sending ? null : _sendCode,
                        child: _sending
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                _countdown > 0 ? '${_countdown}s' : '获取',
                                style: const TextStyle(fontSize: 13),
                              ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordCtrl,
                  obscureText: _obscure,
                  decoration: InputDecoration(
                    labelText: '新密码',
                    hintText: '请输入新密码（至少6位）',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                SpringButton(
                  enabled: !_sending,
                  color: _actionCyan,
                  gradient: _actionCyanGradient,
                  onTap: _sending ? null : _reset,
                  child: _sending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('重置密码', style: TextStyle(fontSize: 16)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
