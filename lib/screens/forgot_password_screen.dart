import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../config/theme.dart';
import '../providers/auth_provider.dart';
import '../widgets/glass_card.dart';
import '../widgets/liquid_scaffold.dart';
import '../widgets/spring_button.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  // Step: 0=输入账号, 1=选择验证渠道, 2=验证+重置
  int _step = 0;
  String _account = '';
  List<Map<String, dynamic>> _channels = [];
  String _selectedChannel = '';
  String _selectedTarget = '';
  String _maskedTarget = '';
  bool _loading = false;
  bool _sending = false;
  int _countdown = 0;
  Timer? _timer;

  final _accountCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _accountCtrl.dispose();
    _codeCtrl.dispose();
    _passwordCtrl.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    setState(() { _countdown = 60; });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() {
        if (_countdown <= 1) { t.cancel(); _countdown = 0; return; }
        _countdown--;
      });
    });
  }

  Future<void> _identify() async {
    final account = _accountCtrl.text.trim();
    if (account.isEmpty) {
      _showError('请输入账号');
      return;
    }
    setState(() => _loading = true);
    final data = await ref.read(authProvider.notifier).identifyAccount(account);
    if (!mounted) return;
    setState(() => _loading = false);

    if (data == null) {
      _showError('账号不存在');
      return;
    }

    final channels = (data['channels'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    if (channels.isEmpty) {
      _showError('该账号未绑定手机号或邮箱，无法找回密码');
      return;
    }

    setState(() {
      _account = data['account'] as String;
      _channels = channels;
      _step = 1;
    });
  }

  Future<void> _selectChannel(Map<String, dynamic> channel) async {
    setState(() {
      _selectedChannel = channel['channel'] as String;
      _selectedTarget = channel['target'] as String;
      _maskedTarget = channel['maskedTarget'] as String;
      _loading = true;
    });

    final result = await ref.read(authProvider.notifier).sendVerificationCode(
      purpose: 'forgot_password',
      channel: _selectedChannel,
      target: _selectedTarget,
    );

    if (!mounted) return;
    setState(() => _loading = false);

    if (result.success) {
      setState(() => _step = 2);
      _startCountdown();
    } else {
      _showError(result.message);
    }
  }

  Future<void> _resendCode() async {
    setState(() => _sending = true);
    final result = await ref.read(authProvider.notifier).sendVerificationCode(
      purpose: 'forgot_password',
      channel: _selectedChannel,
      target: _selectedTarget,
    );
    if (!mounted) return;
    setState(() => _sending = false);

    if (result.success) {
      _startCountdown();
    } else {
      _showError(result.message);
    }
  }

  Future<void> _reset() async {
    final code = _codeCtrl.text.trim();
    final password = _passwordCtrl.text;

    if (code.length != 6) { _showError('请输入6位验证码'); return; }
    if (password.length < 6) { _showError('新密码至少6位'); return; }

    setState(() => _loading = true);
    final result = await ref.read(authProvider.notifier).resetPasswordV2(
      account: _account,
      channel: _selectedChannel,
      target: _selectedTarget,
      code: code,
      password: password,
    );
    if (!mounted) return;
    setState(() => _loading = false);

    if (result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('密码重置成功，请重新登录'),
          backgroundColor: AppColorTokens.success,
        ),
      );
      context.pop();
    } else {
      _showError(result.message);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColorTokens.error),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LiquidScaffold(
      appBar: AppBar(
        title: const Text('忘记密码'),
        leading: _step > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() {
                  if (_step == 2) { _step = 1; }
                  else if (_step == 1) { _step = 0; _channels = []; }
                }),
              )
            : null,
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 32),
          child: GlassCard(
            borderRadius: 30,
            padding: const EdgeInsets.all(24),
            elevation: 1.4,
            child: _step == 0 ? _buildIdentifyStep()
                : _step == 1 ? _buildChannelStep()
                : _buildResetStep(),
          ),
        ),
      ),
    );
  }

  Widget _buildIdentifyStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('重置密码', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppColorTokens.textPrimary)),
        const SizedBox(height: 8),
        const Text('请输入您的账号或手机号，我们将帮您找回密码', style: TextStyle(fontSize: 14, color: AppColorTokens.textSecondary, height: 1.5)),
        const SizedBox(height: 28),
        TextField(
          controller: _accountCtrl,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _identify(),
          decoration: const InputDecoration(
            labelText: '账号或手机号',
            hintText: '请输入账号或手机号',
            prefixIcon: Icon(Icons.person_outline),
          ),
        ),
        const SizedBox(height: 28),
        SpringButton(
          enabled: !_loading,
          color: AppColorTokens.authAction,
          gradient: AppColorTokens.authActionGradient,
          onTap: _loading ? null : _identify,
          child: _loading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('下一步', style: TextStyle(fontSize: 16)),
        ),
      ],
    );
  }

  Widget _buildChannelStep() {
    final iconMap = <String, IconData>{'phone': Icons.phone_iphone_outlined, 'email': Icons.email_outlined};
    final labelMap = <String, String>{'phone': '手机验证', 'email': '邮箱验证'};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('选择验证方式', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppColorTokens.textPrimary)),
        const SizedBox(height: 8),
        Text('账号 $_account 绑定了以下验证方式', style: const TextStyle(fontSize: 14, color: AppColorTokens.textSecondary, height: 1.5)),
        const SizedBox(height: 28),
        if (_loading)
          const Center(child: CircularProgressIndicator())
        else
          ..._channels.map((ch) {
            final channel = ch['channel'] as String;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Material(
                color: Colors.white.withAlpha(140),
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => _selectChannel(ch),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          width: 44, height: 44,
                          decoration: BoxDecoration(
                            gradient: AppColorTokens.authActionGradient,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(iconMap[channel] ?? Icons.verified_outlined, color: Colors.white),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(labelMap[channel] ?? channel, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColorTokens.textPrimary)),
                              const SizedBox(height: 2),
                              Text('发送至 ${ch['maskedTarget']}', style: const TextStyle(fontSize: 13, color: AppColorTokens.textSecondary)),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: AppColorTokens.textSecondary),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _buildResetStep() {
    final channelLabel = _selectedChannel == 'email' ? '邮箱' : '手机号';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('重置密码', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppColorTokens.textPrimary)),
        const SizedBox(height: 8),
        Text('验证码已发送至您的$channelLabel $_maskedTarget', style: const TextStyle(fontSize: 14, color: AppColorTokens.textSecondary, height: 1.5)),
        const SizedBox(height: 28),
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
                color: AppColorTokens.authAction,
                gradient: AppColorTokens.authActionGradient,
                enabled: _countdown == 0 && !_sending,
                onTap: _countdown > 0 || _sending ? null : _resendCode,
                child: _sending
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(_countdown > 0 ? '${_countdown}s' : '重新获取', style: const TextStyle(fontSize: 13)),
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
              icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
          ),
        ),
        const SizedBox(height: 28),
        SpringButton(
          enabled: !_loading,
          color: AppColorTokens.authAction,
          gradient: AppColorTokens.authActionGradient,
          onTap: _loading ? null : _reset,
          child: _loading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('重置密码', style: TextStyle(fontSize: 16)),
        ),
      ],
    );
  }
}
