import 'dart:convert';

import 'course_parse_adapter.dart';
import 'normalized_schedule.dart';

class XiaoAiScheduleAdapter implements CourseParseAdapter {
  @override
  String get id => 'xiao_ai_compatible';

  @override
  bool canParse(String systemType, String input) {
    final type = systemType.toLowerCase();
    if (type.contains('xiaoai') || type.contains('小爱')) return true;
    final decoded = _decode(input);
    return _courseItems(decoded).any(_looksLikeCourseItem);
  }

  @override
  List<NormalizedScheduleCourse> parse(String input) {
    final decoded = _decode(input);
    final courses = <NormalizedScheduleCourse>[];
    for (final item in _courseItems(decoded)) {
      if (item is! Map) continue;
      final course = _parseCourse(item);
      if (course != null && course.isValid) courses.add(course);
    }
    return courses;
  }

  dynamic _decode(String input) {
    final trimmed = input.trim();
    if (!trimmed.startsWith('{') && !trimmed.startsWith('[')) return null;
    try {
      return jsonDecode(trimmed);
    } catch (_) {
      return null;
    }
  }

  Iterable<dynamic> _courseItems(dynamic decoded) {
    if (decoded is List) return decoded;
    if (decoded is Map) {
      for (final key in ['courses', 'courseInfos', 'data', 'schedule']) {
        final value = decoded[key];
        if (value is List) return value;
      }
    }
    return const [];
  }

  bool _looksLikeCourseItem(dynamic item) {
    if (item is! Map) return false;
    final name = _firstText(item, ['name', 'courseName', 'title']);
    final day = _firstInt(item, ['day', 'dayOfWeek', 'weekday', 'weekDay']);
    final sections = _sections(item['sections'] ?? item['section']);
    return name.isNotEmpty && day != null && sections.isNotEmpty;
  }

  NormalizedScheduleCourse? _parseCourse(Map item) {
    final name = _firstText(item, ['name', 'courseName', 'title']).trim();
    final day = _firstInt(item, ['day', 'dayOfWeek', 'weekday', 'weekDay']);
    final sections = _sections(item['sections'] ?? item['section']);
    if (name.isEmpty || day == null || sections.isEmpty) return null;

    return NormalizedScheduleCourse(
      name: name,
      day: day,
      sections: sections,
      weeks: _weeks(item['weeks'] ?? item['week'] ?? item['weekList']),
      teacher: _firstText(item, ['teacher', 'teachers']),
      position: _firstText(item, ['position', 'location', 'room', 'classroom']),
    );
  }

  String _firstText(Map item, List<String> keys) {
    for (final key in keys) {
      final value = item[key];
      if (value == null) continue;
      if (value is List) {
        final text = value
            .map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .join('、');
        if (text.isNotEmpty) return text;
      } else {
        final text = value.toString().trim();
        if (text.isNotEmpty) return text;
      }
    }
    return '';
  }

  int? _firstInt(Map item, List<String> keys) {
    for (final key in keys) {
      final value = item[key];
      final parsed = _intValue(value);
      if (parsed != null) return parsed;
    }
    return null;
  }

  int? _intValue(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }

  List<int> _sections(dynamic value) {
    final result = <int>{};
    if (value is List) {
      for (final item in value) {
        if (item is Map) {
          final section = _intValue(item['section'] ?? item['index']);
          final start = _intValue(item['start'] ?? item['startSection']);
          final end = _intValue(item['end'] ?? item['endSection']);
          if (section != null) result.add(section);
          if (start != null && end != null) {
            for (var i = start; i <= end; i++) {
              result.add(i);
            }
          }
        } else {
          final section = _intValue(item);
          if (section != null) result.add(section);
        }
      }
    } else if (value is Map) {
      final start = _intValue(value['start'] ?? value['startSection']);
      final end = _intValue(value['end'] ?? value['endSection']);
      final section = _intValue(value['section'] ?? value['index']);
      if (section != null) result.add(section);
      if (start != null && end != null) {
        for (var i = start; i <= end; i++) {
          result.add(i);
        }
      }
    } else {
      final section = _intValue(value);
      if (section != null) result.add(section);
    }
    final sorted =
        result.where((section) => section >= 1 && section <= 12).toList()
          ..sort();
    return sorted;
  }

  String _weeks(dynamic value) {
    if (value is String) {
      final text = value.trim().replaceAll('第', '').replaceAll('周', '');
      return text.isEmpty ? '1-16' : text;
    }
    if (value is List) {
      final weeks =
          value
              .map(_intValue)
              .whereType<int>()
              .where((week) => week >= 1 && week <= 30)
              .toList()
            ..sort();
      return weeks.isEmpty ? '1-16' : _compactRanges(weeks);
    }
    return '1-16';
  }

  String _compactRanges(List<int> values) {
    final unique = values.toSet().toList()..sort();
    final ranges = <String>[];
    var start = unique.first;
    var previous = unique.first;
    for (final value in unique.skip(1)) {
      if (value == previous + 1) {
        previous = value;
        continue;
      }
      ranges.add(start == previous ? '$start' : '$start-$previous');
      start = value;
      previous = value;
    }
    ranges.add(start == previous ? '$start' : '$start-$previous');
    return ranges.join(',');
  }
}
