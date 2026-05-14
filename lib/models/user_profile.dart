class UserProfile {
  final String id;
  final String phone;
  final String nickname;
  final String? avatarUrl;
  final String? schoolName;
  final String? schoolId;

  const UserProfile({
    required this.id,
    required this.phone,
    required this.nickname,
    this.avatarUrl,
    this.schoolName,
    this.schoolId,
  });

  UserProfile copyWith({
    String? nickname,
    String? avatarUrl,
    String? schoolName,
    String? schoolId,
  }) {
    return UserProfile(
      id: id,
      phone: phone,
      nickname: nickname ?? this.nickname,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      schoolName: schoolName ?? this.schoolName,
      schoolId: schoolId ?? this.schoolId,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'phone': phone,
    'nickname': nickname,
    'avatar_url': avatarUrl,
    'school_name': schoolName,
    'school_id': schoolId,
  };

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    id: json['id'] as String,
    phone: json['phone'] as String,
    nickname: json['nickname'] as String,
    avatarUrl: json['avatar_url'] as String?,
    schoolName: json['school_name'] as String?,
    schoolId: json['school_id'] as String?,
  );
}
