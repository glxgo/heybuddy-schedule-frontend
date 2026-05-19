import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'api_service.dart';

class SocialRealtimeService {
  final Dio _dio;
  StreamSubscription<List<int>>? _subscription;
  CancelToken? _cancelToken;
  String _buffer = '';

  SocialRealtimeService({required String token})
      : _dio = Dio(
          BaseOptions(
            baseUrl: ApiService.baseUrl,
            headers: {
              'Authorization': 'Bearer $token',
              'Accept': 'text/event-stream',
            },
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(hours: 1),
          ),
        );

  Future<void> start({
    required void Function(String event, Map<String, dynamic> data) onEvent,
    VoidCallback? onDisconnected,
  }) async {
    if (kIsWeb) return;
    await stop();
    _cancelToken = CancelToken();

    try {
      final response = await _dio.get<ResponseBody>(
        '/social/stream',
        options: Options(responseType: ResponseType.stream),
        cancelToken: _cancelToken,
      );
      final stream = response.data?.stream.cast<List<int>>();
      if (stream == null) {
        onDisconnected?.call();
        return;
      }

      String currentEvent = 'message';
      String currentData = '';

      _subscription = stream.listen(
            (chunk) {
              _buffer += utf8.decode(chunk);
              while (true) {
                final lineBreak = _buffer.indexOf('\n');
                if (lineBreak < 0) break;
                final line = _buffer.substring(0, lineBreak).trimRight();
                _buffer = _buffer.substring(lineBreak + 1);

                if (line.isEmpty) {
                  if (currentData.isNotEmpty) {
                    try {
                      final decoded = jsonDecode(currentData);
                      final data = decoded is Map<String, dynamic>
                          ? decoded
                          : decoded is Map
                              ? decoded.map((key, value) => MapEntry(key.toString(), value))
                              : <String, dynamic>{};
                      onEvent(currentEvent, data);
                    } catch (_) {}
                  }
                  currentEvent = 'message';
                  currentData = '';
                  continue;
                }

                if (line.startsWith('event:')) {
                  currentEvent = line.substring(6).trim();
                } else if (line.startsWith('data:')) {
                  if (currentData.isNotEmpty) currentData += '\n';
                  currentData += line.substring(5).trim();
                }
              }
            },
            onDone: onDisconnected,
            onError: (_, __) => onDisconnected?.call(),
            cancelOnError: true,
          );
    } catch (_) {
      onDisconnected?.call();
    }
  }

  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
    _cancelToken?.cancel();
    _cancelToken = null;
    _buffer = '';
  }
}
