import 'package:dio/dio.dart';
import 'api_service.dart';

class OcrService {
  static final OcrService instance = OcrService._();
  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: ApiService.baseUrl,
      connectTimeout: const Duration(seconds: 20),
      sendTimeout: const Duration(seconds: 60),
      receiveTimeout: const Duration(seconds: 120),
      headers: {'Content-Type': 'application/json'},
    ),
  );

  OcrService._();

  Future<OcrResult> recognize(
    String imageBase64,
    String authToken, {
    Map<String, dynamic>? config,
  }) async {
    DioException? lastError;
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final res = await _dio.post(
          '/ocr/recognize',
          data: {'imageBase64': imageBase64, 'config': config},
          options: Options(
            headers: {'Authorization': 'Bearer $authToken'},
          ),
        );

        final data = res.data;
        if (data is! Map<String, dynamic>) {
          return const OcrResult(success: false, msg: 'OCR 服务返回格式异常');
        }

        if (data['code'] == 0 && data['data'] != null) {
          final courses = (data['data'] as List)
              .map((c) => OcrCourse.fromJson(c as Map<String, dynamic>))
              .toList();
          return OcrResult(
            success: true,
            msg: data['msg']?.toString() ?? '识别成功，共 ${courses.length} 门课程',
            warning: data['warning']?.toString(),
            courses: courses,
          );
        }

        return OcrResult(success: false, msg: data['msg']?.toString() ?? '识别失败');
      } on DioException catch (e) {
        lastError = e;
        final retryable =
            e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.sendTimeout ||
            e.type == DioExceptionType.receiveTimeout ||
            e.type == DioExceptionType.connectionError;
        if (retryable && attempt == 0) {
          continue;
        }
        return OcrResult(success: false, msg: _messageFromDio(e));
      } catch (e) {
        return OcrResult(success: false, msg: '识别失败：$e');
      }
    }
    return OcrResult(
      success: false,
      msg: lastError != null ? _messageFromDio(lastError) : '识别失败，请稍后重试',
    );
  }

  String _messageFromDio(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return 'AI 识别超时了，请换一张更清晰的截图或稍后重试';
    }
    if (e.type == DioExceptionType.connectionError) {
      return '网络连接失败，请检查网络后重试';
    }
    final statusCode = e.response?.statusCode;
    final data = e.response?.data;
    if (data is Map<String, dynamic>) {
      final msg = data['msg']?.toString();
      if (msg != null && msg.isNotEmpty) return msg;
    }
    if (statusCode == 401) {
      return '登录状态已失效，请重新登录后再识别';
    }
    if (statusCode == 413) {
      return '图片太大了，请裁剪后再试';
    }
    if (statusCode != null && statusCode >= 500) {
      return 'OCR 服务暂时开小差了，请稍后重试';
    }
    return '网络错误，请稍后重试';
  }
}

class OcrResult {
  final bool success;
  final String msg;
  final String? warning;
  final List<OcrCourse> courses;

  const OcrResult({
    required this.success,
    required this.msg,
    this.warning,
    this.courses = const [],
  });
}

class OcrCourse {
  final String name;
  final String teacher;
  final String location;
  final int dayOfWeek;
  final int startPeriod;
  final int endPeriod;

  const OcrCourse({
    required this.name,
    this.teacher = '',
    this.location = '',
    required this.dayOfWeek,
    required this.startPeriod,
    required this.endPeriod,
  });

  factory OcrCourse.fromJson(Map<String, dynamic> json) => OcrCourse(
        name: json['name'] as String? ?? '',
        teacher: json['teacher'] as String? ?? '',
        location: json['location'] as String? ?? '',
        dayOfWeek: (json['dayOfWeek'] as num?)?.toInt() ?? 1,
        startPeriod: (json['startPeriod'] as num?)?.toInt() ?? 1,
        endPeriod: (json['endPeriod'] as num?)?.toInt() ?? 2,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'teacher': teacher,
        'location': location,
        'dayOfWeek': dayOfWeek,
        'startPeriod': startPeriod,
        'endPeriod': endPeriod,
      };
}
