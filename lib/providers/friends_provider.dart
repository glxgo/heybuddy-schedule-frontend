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

class RelationshipRequestInfo {
  final String id;
  final String friendId;
  final String nickname;
  final String? avatarUrl;
  final String? schoolName;
  final String relationType;
  final String status;
  final bool isOutgoing;

  const RelationshipRequestInfo({
    required this.id,
    required this.friendId,
    required this.nickname,
    this.avatarUrl,
    this.schoolName,
    required this.relationType,
    required this.status,
    this.isOutgoing = false,
  });

  factory RelationshipRequestInfo.fromJson(Map<String, dynamic> json, {required bool isOutgoing}) => RelationshipRequestInfo(
    id: json['id'] as String,
    friendId: json['friend_id'] as String,
    nickname: json['nickname'] as String? ?? '',
    avatarUrl: json['avatar_url'] as String?,
    schoolName: json['school_name'] as String?,
    relationType: json['relation_type'] as String? ?? 'other',
    status: json['status'] as String? ?? 'pending',
    isOutgoing: isOutgoing,
  );

  String get relationLabel {
    switch (relationType) {
      case 'couple':
        return '情侣';
      case 'bestie':
        return '闺蜜';
      case 'roommate':
        return '室友';
      case 'classmate':
        return '同学';
      default:
        return '其他';
    }
  }
}

class FriendsState {
  final List<FriendInfo> friends;
  final List<FriendInfo> pendingRequests;
  final List<FriendInfo> outgoingRequests;
  final List<RelationshipRequestInfo> incomingRelationshipRequests;
  final List<RelationshipRequestInfo> outgoingRelationshipRequests;
  final bool isLoading;

  const FriendsState({
    this.friends = const [],
    this.pendingRequests = const [],
    this.outgoingRequests = const [],
    this.incomingRelationshipRequests = const [],
    this.outgoingRelationshipRequests = const [],
    this.isLoading = false,
  });

  FriendsState copyWith({
    List<FriendInfo>? friends,
    List<FriendInfo>? pendingRequests,
    List<FriendInfo>? outgoingRequests,
    List<RelationshipRequestInfo>? incomingRelationshipRequests,
    List<RelationshipRequestInfo>? outgoingRelationshipRequests,
    bool? isLoading,
  }) {
    return FriendsState(
      friends: friends ?? this.friends,
      pendingRequests: pendingRequests ?? this.pendingRequests,
      outgoingRequests: outgoingRequests ?? this.outgoingRequests,
      incomingRelationshipRequests: incomingRelationshipRequests ?? this.incomingRelationshipRequests,
      outgoingRelationshipRequests: outgoingRelationshipRequests ?? this.outgoingRelationshipRequests,
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
    final relationshipRes = await _api.get('/friend-relationships/requests');
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

      final incomingRelationshipRequests = <RelationshipRequestInfo>[];
      final outgoingRelationshipRequests = <RelationshipRequestInfo>[];
      if (relationshipRes.isSuccess && relationshipRes.data != null) {
        final data = relationshipRes.data as Map<String, dynamic>;
        final incoming = data['incoming'];
        final outgoing = data['outgoing'];
        if (incoming is List) {
          incomingRelationshipRequests.addAll(
            incoming.whereType<Map>().map(
              (item) => RelationshipRequestInfo.fromJson(
                item.map((key, value) => MapEntry(key.toString(), value)),
                isOutgoing: false,
              ),
            ),
          );
        }
        if (outgoing is List) {
          outgoingRelationshipRequests.addAll(
            outgoing.whereType<Map>().map(
              (item) => RelationshipRequestInfo.fromJson(
                item.map((key, value) => MapEntry(key.toString(), value)),
                isOutgoing: true,
              ),
            ),
          );
        }
      }

      state = state.copyWith(
        friends: all.where((f) => f.status == 'accepted').toList(),
        pendingRequests: all
            .where((f) => f.status == 'pending' && !f.isOutgoing)
            .toList(),
        outgoingRequests: all
            .where((f) => f.status == 'pending' && f.isOutgoing)
            .toList(),
        incomingRelationshipRequests: incomingRelationshipRequests,
        outgoingRelationshipRequests: outgoingRelationshipRequests,
        isLoading: false,
      );
    } else {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<String> addFriend(String account) async {
    if (account.isEmpty) return '请输入对方账号';
    final res = await _api.post('/friends/request', data: {'account': account});
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

  Future<String> acceptRelationshipRequest(String relationshipId) async {
    if (relationshipId.isEmpty) return '关系请求参数异常，请返回重试';
    final res = await _api.put('/friend-relationships/$relationshipId/accept');
    if (res.isSuccess) await loadFriends();
    return res.msg;
  }

  Future<String> rejectRelationshipRequest(String relationshipId) async {
    if (relationshipId.isEmpty) return '关系请求参数异常，请返回重试';
    final res = await _api.put('/friend-relationships/$relationshipId/reject');
    if (res.isSuccess) await loadFriends();
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
