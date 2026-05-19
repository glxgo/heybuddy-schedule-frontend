import 'dart:convert';

class AppConstants {
  AppConstants._();

  static const String appName = '相伴课表';
  static const String appVersion = '1.0.0';
  static const String defaultSemester = '2025-2026-2';

  static const List<TimeSlot> defaultTimeSlots = [
    TimeSlot(period: 1, start: '08:00', end: '08:45'),
    TimeSlot(period: 2, start: '08:50', end: '09:35'),
    TimeSlot(period: 3, start: '09:50', end: '10:35'),
    TimeSlot(period: 4, start: '10:40', end: '11:25'),
    TimeSlot(period: 5, start: '11:30', end: '12:15'),
    TimeSlot(period: 6, start: '14:00', end: '14:45'),
    TimeSlot(period: 7, start: '14:50', end: '15:35'),
    TimeSlot(period: 8, start: '15:50', end: '16:35'),
    TimeSlot(period: 9, start: '16:40', end: '17:25'),
    TimeSlot(period: 10, start: '19:00', end: '19:45'),
    TimeSlot(period: 11, start: '19:50', end: '20:35'),
    TimeSlot(period: 12, start: '20:40', end: '21:25'),
  ];

  static const List<String> courseColors = [
    '#4DB6AC',
    '#64B5F6',
    '#7986CB',
    '#BA68C8',
    '#F06292',
    '#FF8A65',
    '#FFB74D',
    '#AED581',
    '#4FC3F7',
    '#81C784',
  ];

  static String stableCourseColor(String name) {
    final normalized = name.trim().toLowerCase();
    if (normalized.isEmpty) return courseColors.first;
    var hash = 0;
    for (final codeUnit in normalized.codeUnits) {
      hash = (hash * 31 + codeUnit) & 0x7fffffff;
    }
    return courseColors[hash % courseColors.length];
  }

  static const List<String> weekDayLabels = [
    '周一',
    '周二',
    '周三',
    '周四',
    '周五',
    '周六',
    '周日',
  ];

  static List<TimeSlot> resolveTimeSlots([List<TimeSlot>? customSlots]) {
    final byPeriod = <int, TimeSlot>{
      for (final slot in defaultTimeSlots) slot.period: slot,
    };
    if (customSlots != null) {
      for (final slot in customSlots) {
        if (slot.period > 0) {
          byPeriod[slot.period] = slot;
        }
      }
    }
    var maxPeriod = defaultTimeSlots.length;
    for (final period in byPeriod.keys) {
      if (period > maxPeriod) {
        maxPeriod = period;
      }
    }
    return List.generate(
      maxPeriod,
      (index) => byPeriod[index + 1] ??
          TimeSlot(period: index + 1, start: '--:--', end: '--:--'),
    );
  }
}

class TimeSlot {
  final int period;
  final String start;
  final String end;

  const TimeSlot({
    required this.period,
    required this.start,
    required this.end,
  });

  factory TimeSlot.fromJson(Map<String, dynamic> json) {
    return TimeSlot(
      period: _parseInt(json['number'] ?? json['period']) ?? 0,
      start: _normalizeTime(json['startTime'] ?? json['start']),
      end: _normalizeTime(json['endTime'] ?? json['end']),
    );
  }

  static List<TimeSlot> parseList(
    dynamic value, {
    List<TimeSlot> fallback = AppConstants.defaultTimeSlots,
  }) {
    dynamic decoded = value;
    if (decoded is String && decoded.trim().isNotEmpty) {
      try {
        decoded = jsonDecode(decoded);
      } catch (_) {
        return fallback;
      }
    }
    if (decoded is! List) return fallback;

    final byPeriod = <int, TimeSlot>{};
    for (final item in decoded) {
      if (item is! Map) continue;
      final slot = TimeSlot.fromJson(Map<String, dynamic>.from(item));
      if (slot.period <= 0 || slot.start.isEmpty || slot.end.isEmpty) continue;
      byPeriod[slot.period] = slot;
    }
    if (byPeriod.isEmpty) return fallback;

    final periods = byPeriod.keys.toList()..sort();
    return periods.map((period) => byPeriod[period]!).toList();
  }

  Map<String, dynamic> toJson() => {
        'number': period,
        'startTime': start,
        'endTime': end,
      };

  String get label => '第$period节';
  String get timeRange => '$start-$end';

  static int? _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  static String _normalizeTime(dynamic value) {
    final raw = value?.toString().trim() ?? '';
    if (raw.isEmpty) return '';
    final match = RegExp(r'^(\d{1,2}):(\d{1,2})').firstMatch(raw);
    if (match == null) return raw;
    final hour = int.tryParse(match.group(1) ?? '');
    final minute = int.tryParse(match.group(2) ?? '');
    if (hour == null || minute == null) return raw;
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }
}
