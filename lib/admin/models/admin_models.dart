int _readInt(dynamic value) {
  if (value is int) return value;
  return int.tryParse('${value ?? ''}') ?? 0;
}

String? _readString(dynamic value) {
  final text = '${value ?? ''}'.trim();
  if (text.isEmpty) return null;
  return text;
}

DateTime? _readDate(dynamic value) {
  final text = _readString(value);
  if (text == null) return null;
  return DateTime.tryParse(text);
}

class AdminSession {
  final String token;
  final String userId;
  final String phone;
  final String role;

  const AdminSession({
    required this.token,
    required this.userId,
    required this.phone,
    required this.role,
  });

  factory AdminSession.fromMeJson(
    Map<String, dynamic> data, {
    required String token,
    String? fallbackUserId,
  }) {
    return AdminSession(
      token: token,
      userId: _readString(data['userId']) ?? fallbackUserId ?? '',
      phone: _readString(data['phone']) ?? '',
      role: _readString(data['role']) ?? 'owner',
    );
  }
}

class AdminStats {
  final int registeredUsers;
  final int usersWithLastLogin;
  final int neverLoggedInUsers;

  const AdminStats({
    required this.registeredUsers,
    required this.usersWithLastLogin,
    required this.neverLoggedInUsers,
  });

  factory AdminStats.fromJson(Map<String, dynamic> json) {
    return AdminStats(
      registeredUsers: _readInt(json['registeredUsers']),
      usersWithLastLogin: _readInt(json['usersWithLastLogin']),
      neverLoggedInUsers: _readInt(json['neverLoggedInUsers']),
    );
  }
}

class AdminUserSummary {
  final String id;
  final String? account;
  final String? phone;
  final String? email;
  final String? nickname;
  final DateTime? registeredAt;
  final DateTime? lastLoginAt;

  const AdminUserSummary({
    required this.id,
    this.account,
    this.phone,
    this.email,
    this.nickname,
    this.registeredAt,
    this.lastLoginAt,
  });

  factory AdminUserSummary.fromJson(Map<String, dynamic> json) {
    return AdminUserSummary(
      id: _readString(json['id']) ?? '',
      account: _readString(json['account']),
      phone: _readString(json['phone']),
      email: _readString(json['email']),
      nickname: _readString(json['nickname']),
      registeredAt: _readDate(json['registeredAt']),
      lastLoginAt: _readDate(json['lastLoginAt']),
    );
  }
}

class AdminUsersPage {
  final List<AdminUserSummary> items;
  final int page;
  final int pageSize;
  final int total;

  const AdminUsersPage({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.total,
  });

  factory AdminUsersPage.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    final items = rawItems is List
        ? rawItems
              .whereType<Map>()
              .map(
                (item) => AdminUserSummary.fromJson(
                  item.map(
                    (key, value) => MapEntry(key.toString(), value),
                  ),
                ),
              )
              .toList()
        : <AdminUserSummary>[];

    return AdminUsersPage(
      items: items,
      page: _readInt(json['page']),
      pageSize: _readInt(json['pageSize']),
      total: _readInt(json['total']),
    );
  }
}
