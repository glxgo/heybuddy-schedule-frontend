import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/admin_models.dart';
import '../services/admin_api_service.dart';

Map<String, dynamic> _asMap(dynamic data) {
  if (data is Map<String, dynamic>) {
    return data;
  }
  if (data is Map) {
    return data.map((key, value) => MapEntry(key.toString(), value));
  }
  return const <String, dynamic>{};
}

class AdminAuthResult {
  final bool success;
  final String message;

  const AdminAuthResult({required this.success, required this.message});
}

class AdminAuthState {
  final bool isInitializing;
  final bool isLoading;
  final AdminSession? session;

  const AdminAuthState({
    this.isInitializing = true,
    this.isLoading = false,
    this.session,
  });

  bool get isAuthenticated => session != null;

  AdminAuthState copyWith({
    bool? isInitializing,
    bool? isLoading,
    AdminSession? session,
    bool clearSession = false,
  }) {
    return AdminAuthState(
      isInitializing: isInitializing ?? this.isInitializing,
      isLoading: isLoading ?? this.isLoading,
      session: clearSession ? null : (session ?? this.session),
    );
  }
}

class AdminAuthNotifier extends StateNotifier<AdminAuthState> {
  static const _tokenKey = 'admin_auth_token';
  static const _userIdKey = 'admin_auth_user_id';

  final AdminApiService _api;

  AdminAuthNotifier(this._api) : super(const AdminAuthState()) {
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    final userId = prefs.getString(_userIdKey);
    if (token == null || token.isEmpty) {
      _api.clearToken();
      state = state.copyWith(isInitializing: false, clearSession: true);
      return;
    }

    final session = await _loadAdminSession(token: token, fallbackUserId: userId);
    if (session == null) {
      await _clearSavedSession();
      state = state.copyWith(isInitializing: false, clearSession: true);
      return;
    }

    state = state.copyWith(
      isInitializing: false,
      isLoading: false,
      session: session,
    );
  }

  Future<AdminSession?> _loadAdminSession({
    required String token,
    String? fallbackUserId,
  }) async {
    try {
      return await _api.fetchMe(token: token, fallbackUserId: fallbackUserId);
    } on AdminApiException {
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveSession(String token, String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setString(_userIdKey, userId);
  }

  Future<void> _clearSavedSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userIdKey);
    _api.clearToken();
  }

  Future<AdminAuthResult> login({
    required String phone,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true);

    final response = await _api.login(phone: phone, password: password);
    if (!response.isSuccess || response.data == null) {
      state = state.copyWith(isLoading: false);
      return AdminAuthResult(success: false, message: response.msg);
    }

    final data = _asMap(response.data);
    final token = '${data['token'] ?? ''}'.trim();
    final userId = '${data['userId'] ?? ''}'.trim();
    if (token.isEmpty || userId.isEmpty) {
      await _clearSavedSession();
      state = state.copyWith(isLoading: false, clearSession: true);
      return const AdminAuthResult(success: false, message: '登录结果异常，请稍后重试');
    }

    final session = await _loadAdminSession(token: token, fallbackUserId: userId);
    if (session == null) {
      await _clearSavedSession();
      state = state.copyWith(isLoading: false, clearSession: true);
      return const AdminAuthResult(success: false, message: '该账号没有后台权限');
    }

    await _saveSession(token, session.userId);
    state = state.copyWith(
      isInitializing: false,
      isLoading: false,
      session: session,
    );
    return const AdminAuthResult(success: true, message: '登录成功');
  }

  Future<void> logout() async {
    await _clearSavedSession();
    state = const AdminAuthState(isInitializing: false);
  }
}

final adminAuthProvider = StateNotifierProvider<AdminAuthNotifier, AdminAuthState>(
  (ref) => AdminAuthNotifier(AdminApiService.instance),
);
