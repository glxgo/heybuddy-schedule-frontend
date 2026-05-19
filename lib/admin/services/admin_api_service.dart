import '../../services/api_service.dart';
import '../models/admin_models.dart';

class AdminApiException implements Exception {
  final String message;

  const AdminApiException(this.message);

  @override
  String toString() => message;
}

class AdminApiService {
  AdminApiService._();

  static final AdminApiService instance = AdminApiService._();

  final ApiService _api = ApiService.instance;

  void setToken(String? token) {
    _api.setToken(token);
  }

  void clearToken() {
    _api.setToken(null);
  }

  Future<ApiResponse> login({
    required String phone,
    required String password,
  }) {
    return _api.post('/auth/login', data: {'phone': phone, 'password': password});
  }

  Future<AdminSession> fetchMe({
    required String token,
    String? fallbackUserId,
  }) async {
    _api.setToken(token);
    final data = _readData(await _api.get('/admin/me'));
    return AdminSession.fromMeJson(
      data,
      token: token,
      fallbackUserId: fallbackUserId,
    );
  }

  Future<AdminStats> fetchStats() async {
    final data = _readData(await _api.get('/admin/stats'));
    return AdminStats.fromJson(data);
  }

  Future<AdminUsersPage> fetchUsers({
    required int page,
    required int pageSize,
    String query = '',
  }) async {
    final payload = _readData(
      await _api.get(
        '/admin/users',
        query: {
          'page': page,
          'pageSize': pageSize,
          if (query.trim().isNotEmpty) 'query': query.trim(),
        },
      ),
    );
    return AdminUsersPage.fromJson(payload);
  }

  Map<String, dynamic> _readData(ApiResponse response) {
    if (!response.isSuccess) {
      throw AdminApiException(response.msg);
    }
    final data = response.data;
    if (data is Map<String, dynamic>) {
      return data;
    }
    if (data is Map) {
      return data.map((key, value) => MapEntry(key.toString(), value));
    }
    throw const AdminApiException('服务器返回格式不正确');
  }

  Future<Map<String, dynamic>> fetchAnnouncements({int page = 1, int pageSize = 20}) async {
    final res = await _api.get('/admin/announcements', query: {'page': page, 'pageSize': pageSize});
    return _readData(res);
  }

  Future<void> createAnnouncement(Map<String, dynamic> data) async {
    _readData(await _api.post('/admin/announcements', data: data));
  }

  Future<void> updateAnnouncement(String id, Map<String, dynamic> data) async {
    _readData(await _api.put('/admin/announcements/$id', data: data));
  }

  Future<void> deleteAnnouncement(String id) async {
    _readData(await _api.delete('/admin/announcements/$id'));
  }
}
