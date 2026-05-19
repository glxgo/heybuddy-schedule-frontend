import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ApiService {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.glxgo.xin/api',
  );
  final Dio _dio;
  String? _token;

  ApiService._()
    : _dio = Dio(
        BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
          headers: {'Content-Type': 'application/json'},
        ),
      ) {
    if (kDebugMode) {
      _dio.interceptors.add(
        LogInterceptor(requestBody: false, responseBody: false),
      );
    }
  }

  static final ApiService instance = ApiService._();

  void setToken(String? token) {
    _token = token;
  }

  Map<String, dynamic>? get _authHeader {
    if (_token == null) return null;
    return {'Authorization': 'Bearer $_token'};
  }

  Future<ApiResponse> get(String path, {Map<String, dynamic>? query}) async {
    try {
      final res = await _dio.get(
        path,
        queryParameters: query,
        options: Options(headers: _authHeader),
      );
      return ApiResponse.fromJson(res.data);
    } on DioException catch (e) {
      return _handleError(e);
    }
  }

  Future<ApiResponse> post(String path, {dynamic data}) async {
    try {
      final res = await _dio.post(
        path,
        data: data,
        options: Options(headers: _authHeader),
      );
      return ApiResponse.fromJson(res.data);
    } on DioException catch (e) {
      return _handleError(e);
    }
  }

  Future<ApiResponse> put(String path, {dynamic data}) async {
    try {
      final res = await _dio.put(
        path,
        data: data,
        options: Options(headers: _authHeader),
      );
      return ApiResponse.fromJson(res.data);
    } on DioException catch (e) {
      return _handleError(e);
    }
  }

  Future<ApiResponse> delete(String path) async {
    try {
      final res = await _dio.delete(
        path,
        options: Options(headers: _authHeader),
      );
      return ApiResponse.fromJson(res.data);
    } on DioException catch (e) {
      return _handleError(e);
    }
  }

  ApiResponse _handleError(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return const ApiResponse(code: -1, msg: '连接超时，请检查网络');
    }
    if (e.response != null) {
      return ApiResponse.fromJson(e.response!.data);
    }
    return const ApiResponse(code: -1, msg: '网络错误，请稍后重试');
  }
}

class ApiResponse {
  final int code;
  final String msg;
  final dynamic data;
  final String? timeSlotsJson;

  const ApiResponse({required this.code, required this.msg, this.data, this.timeSlotsJson});

  factory ApiResponse.fromJson(Map<String, dynamic> json) => ApiResponse(
    code: json['code'] as int? ?? -1,
    msg: json['msg'] as String? ?? '未知错误',
    data: json['data'],
    timeSlotsJson: json['timeSlotsJson'] as String?,
  );

  bool get isSuccess => code == 0;
}

final apiServiceProvider = Provider<ApiService>((ref) => ApiService.instance);
