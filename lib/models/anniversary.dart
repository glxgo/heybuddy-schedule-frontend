class Anniversary {
  final String id;
  final String name;
  final String friendId;
  final String ownerId;
  final bool canEdit;
  final DateTime targetDate;
  final DateTime createdAt;

  const Anniversary({
    required this.id,
    required this.name,
    required this.friendId,
    required this.ownerId,
    required this.canEdit,
    required this.targetDate,
    required this.createdAt,
  });

  factory Anniversary.fromJson(Map<String, dynamic> json, {String friendId = ''}) {
    return Anniversary(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      friendId: friendId,
      ownerId: json['owner_id'] as String? ?? json['ownerId'] as String? ?? '',
      canEdit: json['can_edit'] == true || json['canEdit'] == true,
      targetDate: DateTime.tryParse(json['target_date'] as String? ?? '') ?? DateTime.now(),
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toCreateJson() => {
    'name': name,
    'targetDate': targetDate.toIso8601String().substring(0, 10),
  };

  Map<String, dynamic> toUpdateJson() => {
    'name': name,
    'targetDate': targetDate.toIso8601String().substring(0, 10),
  };

  bool get isPast => targetDate.isBefore(DateTime.now()) || _isSameDay(targetDate, DateTime.now());

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  int get daysSince => DateTime.now().difference(targetDate).inDays;

  int get daysUntilNext {
    final today = DateTime.now();
    final next = DateTime(today.year, targetDate.month, targetDate.day);
    if (next.isBefore(today) || _isSameDay(next, today)) {
      return DateTime(today.year + 1, targetDate.month, targetDate.day).difference(today).inDays;
    }
    return next.difference(today).inDays;
  }

  String get yearsSinceFormatted {
    final years = (daysSince / 365.25).floor();
    return '$years';
  }
}
