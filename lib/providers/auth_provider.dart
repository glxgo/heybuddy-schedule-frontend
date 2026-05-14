import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../services/device_service.dart';

class AuthResult {
  final bool success;
  final String message;
  const AuthResult({required this.success, required this.message});
}

class AuthState {
  final bool isLoggedIn;
  final bool isLoading;
  final String? token;
  final String? userId;
  const AuthState({
    this.isLoggedIn = false,
    this.isLoading = false,
    this.token,
    this.userId,
  });
  AuthState copyWith({
    bool? isLoggedIn,
    bool? isLoading,
    String? token,
    String? userId,
  }) {
    return AuthState(
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      isLoading: isLoading ?? this.isLoading,
      token: token ?? this.token,
      userId: userId ?? this.userId,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  static const _tokenKey = 'auth_token';
  static const _userIdKey = 'auth_user_id';

  AuthNotifier() : super(const AuthState()) {
    _loadSession();
  }

  Future<void> _loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    final userId = prefs.getString(_userIdKey);
    if (token != null) {
      ApiService.instance.setToken(token);
      state = state.copyWith(isLoggedIn: true, token: token, userId: userId);
    }
  }

  Future<void> _saveSession(String token, String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setString(_userIdKey, userId);
    ApiService.instance.setToken(token);
  }

  Future<AuthResult> login({
    required String phone,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true);

    final api = ApiService.instance;
    final res = await api.post(
      '/auth/login',
      data: {'phone': phone, 'password': password},
    );

    state = state.copyWith(isLoading: false);

    if (res.isSuccess && res.data != null) {
      final token = res.data['token'] as String;
      final userId = res.data['userId'] as String;
      await _saveSession(token, userId);
      state = state.copyWith(isLoggedIn: true, token: token, userId: userId);
      return const AuthResult(success: true, message: '登录成功');
    }

    return AuthResult(success: false, message: res.msg);
  }

  Future<AuthResult> register({
    required String phone,
    required String password,
    required String nickname,
  }) async {
    state = state.copyWith(isLoading: true);

    final api = ApiService.instance;
    final res = await api.post(
      '/auth/register',
      data: {'phone': phone, 'password': password, 'nickname': nickname},
    );

    state = state.copyWith(isLoading: false);

    if (res.isSuccess && res.data != null) {
      final token = res.data['token'] as String;
      final userId = res.data['userId'] as String;
      await _saveSession(token, userId);
      state = state.copyWith(isLoggedIn: true, token: token, userId: userId);
      return AuthResult(success: true, message: '注册成功，欢迎$nickname！');
    }

    return AuthResult(success: false, message: res.msg);
  }

  void applySession(String token, String userId) {
    _saveSession(token, userId);
    state = state.copyWith(isLoggedIn: true, token: token, userId: userId);
  }

  Future<AuthResult> sendForgotPasswordCode(String phone) async {
    final api = ApiService.instance;
    final res = await api.post(
      '/auth/forgot-password/send-code',
      data: {'phone': phone},
    );
    if (res.isSuccess) {
      return AuthResult(success: true, message: res.msg);
    }
    if (res.code == 404 || res.msg.contains('接口不存在')) {
      final deviceId = await DeviceService.getDeviceId();
      final fallback = await api.post(
        '/sms/send',
        data: {'phone': phone, 'deviceId': deviceId},
      );
      return AuthResult(success: fallback.isSuccess, message: fallback.msg);
    }
    return AuthResult(success: false, message: res.msg);
  }

  Future<AuthResult> resetPassword(
    String phone,
    String smsCode,
    String password,
  ) async {
    final api = ApiService.instance;
    final res = await api.post(
      '/auth/forgot-password/reset',
      data: {'phone': phone, 'smsCode': smsCode, 'password': password},
    );
    if (res.isSuccess) {
      return AuthResult(success: true, message: res.msg);
    }
    if (res.code == 404 || res.msg.contains('接口不存在')) {
      return const AuthResult(
        success: false,
        message: '密码重置服务暂不可用，请稍后重试',
      );
    }
    return AuthResult(success: false, message: res.msg);
  }

  Future<AuthResult> updateNickname(String nickname) async {
    final api = ApiService.instance;
    final res = await api.put('/user/profile', data: {'nickname': nickname});
    return AuthResult(success: res.isSuccess, message: res.msg);
  }

  Future<AuthResult> sendPhoneChangeCode(String phone) async {
    final deviceId = await DeviceService.getDeviceId();
    final api = ApiService.instance;
    final res = await api.post(
      '/sms/send',
      data: {'phone': phone, 'deviceId': deviceId},
    );
    return AuthResult(success: res.isSuccess, message: res.msg);
  }

  Future<AuthResult> updatePhone(String phone, String smsCode) async {
    final api = ApiService.instance;
    final res = await api.put(
      '/user/phone',
      data: {'phone': phone, 'smsCode': smsCode},
    );
    if (res.isSuccess && res.data != null) {
      final token = res.data['token'] as String;
      final userId = res.data['userId'] as String;
      await _saveSession(token, userId);
      state = state.copyWith(isLoggedIn: true, token: token, userId: userId);
      return const AuthResult(success: true, message: '手机号修改成功');
    }
    return AuthResult(success: false, message: res.msg);
  }

  Future<AuthResult> updatePassword(String oldPassword, String newPassword) async {
    final api = ApiService.instance;
    final res = await api.put(
      '/user/password',
      data: {'oldPassword': oldPassword, 'newPassword': newPassword},
    );
    return AuthResult(success: res.isSuccess, message: res.msg);
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userIdKey);
    ApiService.instance.setToken(null);
    state = const AuthState();
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(),
);
