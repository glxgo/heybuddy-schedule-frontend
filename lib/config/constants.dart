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

  static const List<String> periodPairs = [
    '1-2',
    '3-4',
    '5-6',
    '7-8',
    '9-10',
    '11-12',
  ];

  static const List<({String start, String end})> periodPairTimes = [
    (start: '08:00', end: '09:35'),
    (start: '09:50', end: '11:25'),
    (start: '11:30', end: '12:15'),
    (start: '14:00', end: '15:35'),
    (start: '15:50', end: '17:25'),
    (start: '19:00', end: '21:25'),
  ];
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

  String get label => '第$period节';
  String get timeRange => '$start-$end';
}
