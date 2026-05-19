import 'dart:convert';

import '../config/constants.dart';

class Course {
  final String id;
  final String name;
  final String teacher;
  final String position;
  final int day;
  final int startSection;
  final int endSection;
  final List<int> weekList;
  final String color;
  final String semester;
  final String tableId;
  final bool isCustomTime;
  final String? customStartTime;
  final String? customEndTime;
  final String? remark;

  static const defaultTableId = 'default';

  Course({
    required this.id,
    required this.name,
    this.teacher = '',
    this.position = '',
    this.day = 1,
    this.startSection = 1,
    this.endSection = 2,
    List<int>? weekList,
    this.color = '#5B6AF0',
    this.semester = AppConstants.defaultSemester,
    this.tableId = defaultTableId,
    this.isCustomTime = false,
    this.customStartTime,
    this.customEndTime,
    this.remark,
  }) : weekList = weekList ?? List.generate(20, (i) => i + 1);

  String get weeks {
    if (weekList.isEmpty) return '1-16';
    final sorted = weekList.toSet().toList()..sort();
    final ranges = <String>[];
    var start = sorted.first, prev = sorted.first;
    for (final w in sorted.skip(1)) {
      if (w > prev + 1) {
        ranges.add(start == prev ? '$start' : '$start-$prev');
        start = w;
      }
      prev = w;
    }
    ranges.add(start == prev ? '$start' : '$start-$prev');
    return ranges.join(',');
  }

  bool isActiveInWeek(int week) => weekList.contains(week);

  Course copyWith({
    String? id,
    String? name,
    String? teacher,
    String? position,
    int? day,
    int? startSection,
    int? endSection,
    List<int>? weekList,
    String? color,
    String? semester,
    String? tableId,
    bool? isCustomTime,
    String? customStartTime,
    String? customEndTime,
    String? remark,
  }) => Course(
    id: id ?? this.id,
    name: name ?? this.name,
    teacher: teacher ?? this.teacher,
    position: position ?? this.position,
    day: day ?? this.day,
    startSection: startSection ?? this.startSection,
    endSection: endSection ?? this.endSection,
    weekList: weekList ?? this.weekList,
    color: color ?? this.color,
    semester: semester ?? this.semester,
    tableId: tableId ?? this.tableId,
    isCustomTime: isCustomTime ?? this.isCustomTime,
    customStartTime: customStartTime ?? this.customStartTime,
    customEndTime: customEndTime ?? this.customEndTime,
    remark: remark ?? this.remark,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'teacher': teacher,
    'position': position,
    'day': day,
    'startSection': startSection,
    'endSection': endSection,
    'weeks': weekList,
    'color': color,
    'semester': semester,
    'tableId': tableId,
    if (isCustomTime) ...{
      'isCustomTime': true,
      'customStartTime': customStartTime,
      'customEndTime': customEndTime,
    },
    if (remark != null && remark!.isNotEmpty) 'remark': remark,
  };

  Map<String, dynamic> toApiJson() => {
    'id': id,
    'name': name,
    'teacher': teacher,
    'location': position,
    'dayOfWeek': day,
    'startPeriod': startSection,
    'endPeriod': endSection,
    'weeks': weeks,
    'color': color,
    'semester': semester,
  };

  factory Course.fromJson(Map<String, dynamic> json) {
    final wl = _parseWeekList(json['weekList'] ?? json['weeks']);
    final name = _stringValue(json['name'], '');
    final parsedColor = _stringValue(json['color'], '').trim();
    return Course(
      id: _stringValue(
        json['id'],
        DateTime.now().microsecondsSinceEpoch.toString(),
      ),
      name: name,
      teacher: _stringValue(json['teacher'], ''),
      position: _stringValue(json['position'] ?? json['location'], ''),
      day: _intValue(
        json['day'] ?? json['dayOfWeek'] ?? json['day_of_week'],
        1,
      ),
      startSection: _intValue(
        json['startSection'] ?? json['startPeriod'] ?? json['start_period'],
        1,
      ),
      endSection: _intValue(
        json['endSection'] ?? json['endPeriod'] ?? json['end_period'],
        2,
      ),
      weekList: wl,
      color: parsedColor.isNotEmpty
          ? parsedColor
          : AppConstants.stableCourseColor(name),
      semester: _stringValue(json['semester'], AppConstants.defaultSemester),
      tableId: _stringValue(
        json['tableId'] ?? json['table_id'],
        Course.defaultTableId,
      ),
      isCustomTime: json['isCustomTime'] == true,
      customStartTime: json['customStartTime']?.toString(),
      customEndTime: json['customEndTime']?.toString(),
      remark: json['remark']?.toString(),
    );
  }

  static String _stringValue(dynamic v, String f) {
    if (v is String) return v;
    if (v is num) return v.toString();
    return v?.toString() ?? f;
  }

  static int _intValue(dynamic v, int f) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? f;
    return f;
  }

  static List<int> _parseWeekList(dynamic value) {
    if (value is List) {
      final parsed = value.map((e) => _intValue(e, 0)).where((e) => e > 0).toList();
      if (parsed.isNotEmpty) return parsed;
    }
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) {
        return List.generate(20, (i) => i + 1);
      }
      if (trimmed.startsWith('[') && trimmed.endsWith(']')) {
        final inner = trimmed.substring(1, trimmed.length - 1);
        final parsed = inner
            .split(',')
            .map((part) => int.tryParse(part.trim()) ?? 0)
            .where((e) => e > 0)
            .toList();
        if (parsed.isNotEmpty) return parsed;
      }

      final oddOnly = trimmed.contains('单周') || trimmed.contains('(单)');
      final evenOnly = trimmed.contains('双周') || trimmed.contains('(双)');
      bool matchesParity(int week) {
        if (oddOnly) return week.isOdd;
        if (evenOnly) return week.isEven;
        return true;
      }

      final weeks = <int>[];
      final normalized = trimmed
          .replaceAll('，', ',')
          .replaceAll('、', ',')
          .replaceAll('第', '')
          .replaceAll('单周', '')
          .replaceAll('双周', '')
          .replaceAll('周', '')
          .replaceAll('(单)', '')
          .replaceAll('(双)', '');
      for (final segment in normalized.split(',')) {
        final part = segment.trim();
        if (part.isEmpty) continue;
        if (part.contains('-')) {
          final bounds = part.split('-');
          if (bounds.length == 2) {
            final start = int.tryParse(bounds[0].trim()) ?? 0;
            final end = int.tryParse(bounds[1].trim()) ?? 0;
            if (start > 0 && end >= start) {
              for (var i = start; i <= end; i++) {
                if (matchesParity(i)) {
                  weeks.add(i);
                }
              }
            }
          }
        } else {
          final single = int.tryParse(part);
          if (single != null && single > 0 && matchesParity(single)) {
            weeks.add(single);
          }
        }
      }
      if (weeks.isNotEmpty) {
        final deduped = weeks.toSet().toList()..sort();
        return deduped;
      }
    }
    return List.generate(20, (i) => i + 1);
  }

  bool overlapsWithPeriod(int period) =>
      period >= startSection && period <= endSection;
  int get duration => endSection - startSection + 1;
}

class CourseTable {
  final String id;
  final String name;
  final String color;
  final String semester;
  final String? startDate;
  final int totalWeeks;
  final List<TimeSlot> timeSlots;

  static const defaultTotalWeeks = 20;

  const CourseTable({
    required this.id,
    required this.name,
    this.color = '#5B6AF0',
    this.semester = AppConstants.defaultSemester,
    this.startDate,
    this.totalWeeks = defaultTotalWeeks,
    this.timeSlots = AppConstants.defaultTimeSlots,
  });

  CourseTable copyWith({
    String? id,
    String? name,
    String? color,
    String? semester,
    String? startDate,
    bool clearStartDate = false,
    int? totalWeeks,
    List<TimeSlot>? timeSlots,
  }) => CourseTable(
    id: id ?? this.id,
    name: name ?? this.name,
    color: color ?? this.color,
    semester: semester ?? this.semester,
    startDate: clearStartDate ? null : (startDate ?? this.startDate),
    totalWeeks: totalWeeks ?? this.totalWeeks,
    timeSlots: timeSlots ?? this.timeSlots,
  );

  DateTime? get startDateTime {
    if (startDate == null || startDate!.isEmpty) return null;
    return DateTime.tryParse(startDate!);
  }

  factory CourseTable.fromJson(Map<String, dynamic> json) => CourseTable(
    id: json['id'] as String? ?? '',
    name: json['name'] as String? ?? '未命名',
    color: json['color'] as String? ?? '#5B6AF0',
    semester: json['semester'] as String? ?? AppConstants.defaultSemester,
    startDate: json['start_date'] as String? ?? json['startDate'] as String?,
    totalWeeks: (json['total_weeks'] as num?)?.toInt() ??
        (json['totalWeeks'] as num?)?.toInt() ??
        defaultTotalWeeks,
    timeSlots: TimeSlot.parseList(
      json['timeSlots'] ?? json['time_slots'] ?? json['time_slots_json'],
    ),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'color': color,
    'semester': semester,
    if (startDate != null && startDate!.isNotEmpty) 'start_date': startDate,
    if (totalWeeks != defaultTotalWeeks) 'total_weeks': totalWeeks,
    if (!_sameTimeSlots(timeSlots, AppConstants.defaultTimeSlots))
      'time_slots_json': jsonEncode(timeSlots.map((slot) => slot.toJson()).toList()),
  };

  static bool _sameTimeSlots(List<TimeSlot> a, List<TimeSlot> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].period != b[i].period ||
          a[i].start != b[i].start ||
          a[i].end != b[i].end) {
        return false;
      }
    }
    return true;
  }
}
