import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_provider.dart';
import '../services/api_service.dart';

class FriendInfo {
  final String id;
  final String friendId;
  final String nickname;
  final String? originalNickname;
  final String? avatarUrl;
  final String? schoolName;
  final String status;
  final bool isOutgoing;

  const FriendInfo({
    required this.id,
    required this.friendId,
    required this.nickname,
    this.originalNickname,
    this.avatarUrl,
    this.schoolName,
    required this.status,
    this.isOutgoing = false,
  });

  factory FriendInfo.fromJson(Map<String, dynamic> json) => FriendInfo(
    id: json['id'] as String,
    friendId: json['friend_id'] as String,
    nickname: json['nickname'] as String? ?? '',
    originalNickname: json['original_nickname'] as String? ?? json['originalNickname'] as String?,
    avatarUrl: json['avatar_url'] as String?,
    schoolName: json['school_name'] as String?,
    status: json['status'] as String? ?? 'pending',
    isOutgoing: json['is_outgoing'] == true || json['isOutgoing'] == true,
  );
}

class FriendsState {
  final List<FriendInfo> friends;
  final List<FriendInfo> pendingRequests;
  final List<FriendInfo> outgoingRequests;
  final bool isLoading;

  const FriendsState({
    this.friends = const [],
    this.pendingRequests = const [],
    this.outgoingRequests = const [],
    this.isLoading = false,
  });

  FriendsState copyWith({
    List<FriendInfo>? friends,
    List<FriendInfo>? pendingRequests,
    List<FriendInfo>? outgoingRequests,
    bool? isLoading,
  }) {
    return FriendsState(
      friends: friends ?? this.friends,
      pendingRequests: pendingRequests ?? this.pendingRequests,
      outgoingRequests: outgoingRequests ?? this.outgoingRequests,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class FriendsNotifier extends StateNotifier<FriendsState> {
  final ApiService _api;
  final String? Function() _readCurrentUserId;

  FriendsNotifier(this._api, this._readCurrentUserId)
      : super(const FriendsState()) {
    loadFriends();
  }

  Future<void> loadFriends() async {
    state = state.copyWith(isLoading: true);
    final res = await _api.get('/friends');
    if (res.isSuccess && res.data != null) {
      final currentUserId = _readCurrentUserId();
      final byFriendshipId = <String, FriendInfo>{};
      for (final raw in (res.data as List)) {
        final friend = FriendInfo.fromJson(raw as Map<String, dynamic>);
        if (currentUserId != null && friend.friendId == currentUserId) {
          continue;
        }
        byFriendshipId[friend.id] = friend;
      }
      final all = byFriendshipId.values.toList();
      state = state.copyWith(
        friends: all.where((f) => f.status == 'accepted').toList(),
        pendingRequests: all
            .where((f) => f.status == 'pending' && !f.isOutgoing)
            .toList(),
        outgoingRequests: all
            .where((f) => f.status == 'pending' && f.isOutgoing)
            .toList(),
        isLoading: false,
      );
    } else {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<String> addFriend(String phone) async {
    final res = await _api.post('/friends/request', data: {'phone': phone});
    if (res.isSuccess) await loadFriends();
    return res.msg;
  }

  Future<String> acceptRequest(String friendshipId) async {
    if (friendshipId.isEmpty) return '好友请求参数异常，请返回重试';
    final res = await _api.put('/friends/$friendshipId/accept');
    if (res.isSuccess) await loadFriends();
    if (res.code == 404 || res.msg.contains('接口不存在')) {
      return '好友请求服务暂不可用，请稍后重试';
    }
    return res.msg;
  }

  Future<String> rejectRequest(String friendshipId) async {
    if (friendshipId.isEmpty) return '好友请求参数异常，请返回重试';
    final res = await _api.put('/friends/$friendshipId/reject');
    if (res.isSuccess) await loadFriends();
    if (res.code == 404 || res.msg.contains('接口不存在')) {
      return '拒绝好友请求服务暂不可用，请稍后重试';
    }
    return res.msg;
  }

  Future<String> updateRemark(String friendshipId, String remark) async {
    if (friendshipId.isEmpty) return '好友备注参数异常，请返回好友列表后重试';
    final res = await _api.put(
      '/friends/$friendshipId/remark',
      data: {'remark': remark},
    );
    if (res.isSuccess) await loadFriends();
    if (res.code == 404 || res.msg.contains('接口不存在')) {
      return '好友备注服务暂不可用，请稍后重试';
    }
    return res.msg;
  }

  Future<String> deleteFriend(String friendshipId) async {
    if (friendshipId.isEmpty) return '好友参数异常，请返回好友列表后重试';
    final res = await _api.delete('/friends/$friendshipId');
    if (res.isSuccess) await loadFriends();
    return res.msg;
  }
}

final friendsProvider = StateNotifierProvider<FriendsNotifier, FriendsState>((
  ref,
) {
  return FriendsNotifier(
    ref.read(apiServiceProvider),
    () => ref.read(authProvider).userId,
  );
});
