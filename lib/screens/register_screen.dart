import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../config/theme.dart';
import '../services/api_service.dart';
import '../services/device_service.dart';
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

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _phoneCtrl = TextEditingController();
  final _nicknameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _smsCtrl = TextEditingController();
  bool _obscure = true;
  bool _obscureConfirm = true;
  bool _sendingSms = false;
  bool _registering = false;
  int _countdown = 0;
  Timer? _timer;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _nicknameCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    _smsCtrl.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    setState(() => _countdown = 60);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        if (_countdown <= 1) {
          _countdown = 0;
          t.cancel();
        } else {
          _countdown--;
        }
      });
    });
  }

  Future<void> _sendSms() async {
    final phone = _phoneCtrl.text.trim();
    if (phone.length != 11) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请输入正确的手机号')));
      return;
    }
    setState(() => _sendingSms = true);
    final deviceId = await DeviceService.getDeviceId();
    final api = ref.read(apiServiceProvider);
    final res = await api.post(
      '/sms/send',
      data: {'phone': phone, 'deviceId': deviceId},
    );
    if (!mounted) return;
    setState(() => _sendingSms = false);

    if (res.isSuccess) {
      _startCountdown();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.msg),
          backgroundColor: AppColorTokens.success,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res.msg), backgroundColor: AppColorTokens.error),
      );
    }
  }

  Future<void> _register() async {
    final phone = _phoneCtrl.text.trim();
    final nickname = _nicknameCtrl.text.trim();
    final password = _passwordCtrl.text;
    final confirm = _confirmCtrl.text;
    final smsCode = _smsCtrl.text.trim();

    if (phone.isEmpty || nickname.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请填写所有必填项')));
      return;
    }
    if (phone.length != 11) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请输入正确的手机号')));
      return;
    }
    if (smsCode.length != 6) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请输入6位验证码')));
      return;
    }
    if (password.length < 6) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('密码至少6位')));
      return;
    }
    if (password != confirm) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('两次输入的密码不一致')));
      return;
    }

    setState(() => _registering = true);
    final api = ref.read(apiServiceProvider);
    final res = await api.post(
      '/auth/register-sms',
      data: {
        'phone': phone,
        'password': password,
        'nickname': nickname,
        'smsCode': smsCode,
      },
    );
    if (!mounted) return;
    setState(() => _registering = false);

    if (res.isSuccess && res.data != null) {
      final token = res.data['token'] as String;
      final userId = res.data['userId'] as String;
      ref.read(authProvider.notifier).applySession(token, userId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.msg),
          backgroundColor: AppColorTokens.success,
        ),
      );
      context.go('/daily');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res.msg), backgroundColor: AppColorTokens.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
                const Text(
                  '创建新账号',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: AppColorTokens.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '注册后即可同步课表数据到云端',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColorTokens.textSecondary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 26),
                TextField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  maxLength: 11,
                  decoration: const InputDecoration(
                    labelText: '手机号 *',
                    hintText: '请输入手机号',
                    prefixIcon: Icon(Icons.phone_iphone_outlined),
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _smsCtrl,
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
                        color: _actionCyan,
                        gradient: _actionCyanGradient,
                        enabled: _countdown == 0 && !_sendingSms,
                        onTap: _countdown > 0 || _sendingSms ? null : _sendSms,
                        child: _sendingSms
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                _countdown > 0 ? '${_countdown}s' : '获取验证码',
                                style: const TextStyle(fontSize: 13),
                              ),
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
                      icon: Icon(
                        _obscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
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
                      icon: Icon(
                        _obscureConfirm
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () =>
                          setState(() => _obscureConfirm = !_obscureConfirm),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                SpringButton(
                  enabled: !_registering,
                  color: _actionCyan,
                  gradient: _actionCyanGradient,
                  onTap: _registering ? null : _register,
                  child: _registering
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('注册', style: TextStyle(fontSize: 16)),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      '已有账号？',
                      style: TextStyle(color: AppColorTokens.textSecondary),
                    ),
                    TextButton(
                      onPressed: () => context.pop(),
                      child: const Text('去登录'),
                    ),
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
