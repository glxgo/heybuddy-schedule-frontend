import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/anniversary.dart';
import '../services/api_service.dart';

class AnniversaryState {
  final List<Anniversary> anniversaries;
  final String friendId;
  final bool isLoading;
  final String? error;

  const AnniversaryState({
    this.anniversaries = const [],
    this.friendId = '',
    this.isLoading = false,
    this.error,
  });

  AnniversaryState copyWith({
    List<Anniversary>? anniversaries,
    String? friendId,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return AnniversaryState(
      anniversaries: anniversaries ?? this.anniversaries,
      friendId: friendId ?? this.friendId,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class AnniversaryNotifier extends StateNotifier<AnniversaryState> {
  final ApiService _api;

  AnniversaryNotifier(this._api) : super(const AnniversaryState());

  Future<void> loadForFriend(String friendId) async {
    if (friendId.isEmpty) {
      state = state.copyWith(
        friendId: '',
        anniversaries: const [],
        isLoading: false,
        error: '纪念日参数异常',
      );
      return;
    }
    state = state.copyWith(
      friendId: friendId,
      anniversaries: const [],
      isLoading: true,
      clearError: true,
    );
    final res = await _api.get('/friends/$friendId/anniversaries');
    if (res.isSuccess && res.data != null) {
      final list = (res.data as List)
          .map((e) => Anniversary.fromJson(e, friendId: friendId))
          .toList();
      state = state.copyWith(
        anniversaries: list,
        isLoading: false,
        clearError: true,
      );
    } else {
      state = state.copyWith(
        anniversaries: const [],
        isLoading: false,
        error: res.msg,
      );
    }
  }

  Future<String> add(String friendId, String name, DateTime targetDate, {String visibility = 'shared'}) async {
    if (friendId.isEmpty) return '纪念日参数异常，请返回好友列表后重试';
    final res = await _api.post(
      '/friends/$friendId/anniversaries',
      data: {
        'name': name,
        'targetDate': targetDate.toIso8601String().substring(0, 10),
        'visibility': visibility,
      },
    );
    if (res.isSuccess) await loadForFriend(friendId);
    if (res.code == 404 || res.msg.contains('接口不存在')) {
      return '纪念日服务暂不可用，请稍后重试';
    }
    return res.msg;
  }

  Future<String> update(String friendId, String id, String name, DateTime targetDate, {String visibility = 'shared'}) async {
    if (friendId.isEmpty) return '纪念日参数异常，请返回好友列表后重试';
    final res = await _api.put(
      '/friends/$friendId/anniversaries/$id',
      data: {'name': name, 'targetDate': targetDate.toIso8601String().substring(0, 10), 'visibility': visibility},
    );
    if (res.isSuccess) await loadForFriend(friendId);
    if (res.code == 404 || res.msg.contains('接口不存在')) {
      return '纪念日服务暂不可用，请稍后重试';
    }
    return res.msg;
  }

  Future<String> delete(String friendId, String id) async {
    if (friendId.isEmpty) return '纪念日参数异常，请返回好友列表后重试';
    final res = await _api.delete('/friends/$friendId/anniversaries/$id');
    if (res.isSuccess) await loadForFriend(friendId);
    if (res.code == 404 || res.msg.contains('接口不存在')) {
      return '纪念日服务暂不可用，请稍后重试';
    }
    return res.msg;
  }
}

final anniversaryProvider =
    StateNotifierProvider<AnniversaryNotifier, AnniversaryState>((ref) {
  return AnniversaryNotifier(ref.read(apiServiceProvider));
});
