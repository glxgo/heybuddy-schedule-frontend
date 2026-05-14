import 'dart:convert';

import '../config/constants.dart';
import '../models/course.dart';
import 'course_parse_diagnostics.dart';
import 'course_parse_result.dart';
import 'normalized_schedule.dart';
import 'schedule_adapter_registry.dart';

class CourseParser {
  List<Course> parse(String systemType, String html) {
    return parseWithResult(systemType, html).courses;
  }

  CourseParseResult parseWithResult(String systemType, String html) {
    final courses = _parseInternal(systemType, html);
    final diagnostics = diagnose(systemType, html);
    return CourseParseResult(courses: courses, diagnostics: diagnostics);
  }

  List<Course> parseSafe(String systemType, String html) {
    final result = parseWithResult(systemType, html);
    return result.canImportDirectly ? result.courses : const [];
  }

  List<Course> _parseInternal(String systemType, String html) {
    final adapterResult = ScheduleAdapterRegistry().parseWithAdapter(
      systemType,
      html,
    );
    if (adapterResult != null) {
      return _dedupeCourses(
        adapterResult.courses.map(_courseFromNormalized).toList(),
      );
    }

    final jsonTables = _tryParseJsonTables(html);
    if (jsonTables != null) {
      return _dedupeCourses(_parseJsonTables(jsonTables));
    }

    return const [];
  }

  CourseParseDiagnostics diagnose(String systemType, String html) {
    final adapterResult = ScheduleAdapterRegistry().parseWithAdapter(
      systemType,
      html,
    );
    if (adapterResult != null) {
      final courses = _dedupeCourses(
        adapterResult.courses.map(_courseFromNormalized).toList(),
      );
      return CourseParseDiagnostics(
        inputType: 'adapter',
        adapterId: adapterResult.adapterId,
        parsedCourseCount: courses.length,
      );
    }

    final jsonTables = _tryParseJsonTables(html);
    if (jsonTables != null) {
      final stats = _diagnoseJsonTables(jsonTables);
      final courses = _dedupeCourses(_parseJsonTables(jsonTables));
      return CourseParseDiagnostics(
        inputType: 'jsonTable',
        tableCount: stats.tableCount,
        rowCount: stats.rowCount,
        candidateCellCount: stats.candidateCellCount,
        parsedCourseCount: courses.length,
        warnings: courses.isEmpty ? ['未从结构化表格中解析到课程'] : const [],
      );
    }

    final courses = _dedupeCourses(_parseInternal(systemType, html));
    return CourseParseDiagnostics(
      inputType: 'backend',
      parsedCourseCount: courses.length,
      warnings: courses.isEmpty ? ['本地未识别到课表，需发送到后端解析'] : const [],
    );
  }

  List<dynamic>? _tryParseJsonTables(String text) {
    final trimmed = text.trim();
    if (!trimmed.startsWith('{') && !trimmed.startsWith('[')) return null;
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is Map<String, dynamic> && decoded['tables'] is List) {
        return decoded['tables'] as List<dynamic>;
      }
      if (decoded is List) return decoded;
    } catch (_) {}
    return null;
  }

  List<Course> _parseJsonTables(List<dynamic> tables) {
    final courses = <Course>[];
    for (final table in tables) {
      if (table is! Map<String, dynamic> || table['rows'] is! List) continue;
      final rows = (table['rows'] as List).whereType<List<dynamic>>().toList();
      final grid = _expandTableGrid(rows);
      courses.addAll(_parseGridRows(grid));
    }
    return courses;
  }

  List<List<_GridCell?>> _expandTableGrid(List<List<dynamic>> rows) {
    final grid = <List<_GridCell?>>[];
    for (var r = 0; r < rows.length; r++) {
      while (grid.length <= r) {
        grid.add(<_GridCell?>[]);
      }
      var c = 0;
      for (final rawCell in rows[r]) {
        while (grid[r].length > c && grid[r][c] != null) {
          c++;
        }
        final cell = _GridCell.fromJson(rawCell);
        final rowSpan = cell.rowSpan.clamp(1, 20).toInt();
        final colSpan = cell.colSpan.clamp(1, 20).toInt();
        for (var rr = r; rr < r + rowSpan; rr++) {
          while (grid.length <= rr) {
            grid.add(<_GridCell?>[]);
          }
          while (grid[rr].length < c + colSpan) {
            grid[rr].add(null);
          }
          for (var cc = c; cc < c + colSpan; cc++) {
            grid[rr][cc] = cell.copyWith(origin: rr == r && cc == c);
          }
        }
        c += colSpan;
      }
    }
    return grid;
  }

  List<Course> _parseGridRows(List<List<_GridCell?>> grid) {
    final courses = <Course>[];
    if (grid.length < 2) return courses;

    final dayByColumn = _dayMapFromHeader(grid.first);
    var fallbackRowIdx = 0;
    for (var r = 1; r < grid.length; r++) {
      final row = grid[r];
      if (row.isEmpty) continue;
      final rowLabel = row.first?.text ?? '';
      if (_looksLikeHeaderTexts(row.map((cell) => cell?.text ?? '').toList()))
        continue;
      if (_isBreakRow(rowLabel)) continue;

      final period =
          _parsePeriod(rowLabel) ?? _periodFromRow(rowIdx: fallbackRowIdx);
      final startCol = _hasRowHeader(rowLabel) ? 1 : 0;
      for (var c = startCol; c < row.length; c++) {
        final cell = row[c];
        if (cell == null || !cell.origin) continue;
        final text = cell.text.trim();
        if (text.length < 2) continue;
        final day = dayByColumn[c] ?? (startCol == 1 ? c : c + 1);
        if (day < 1 || day > 7) continue;
        courses.addAll(_parseCellText(text, day, period.$1, period.$2));
      }
      fallbackRowIdx++;
    }
    return courses;
  }

  Map<int, int> _dayMapFromHeader(List<_GridCell?> header) {
    final result = <int, int>{};
    for (var i = 0; i < header.length; i++) {
      final day = _parseDay(header[i]?.text ?? '');
      if (day != null) result[i] = day;
    }
    return result;
  }

  List<Course> _parseCellText(
    String text,
    int day,
    int startPeriod,
    int endPeriod,
  ) {
    final courses = <Course>[];
    final normalized = text.replaceAll(r'\n', '\n');
    final blocks = _splitCourseBlocks(normalized);

    for (final block in blocks) {
      final trimmed = block.trim();
      if (trimmed.isEmpty || trimmed.length < 2) continue;

      final lines = trimmed
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();
      if (lines.isEmpty) continue;

      final meaningful = lines
          .where((l) => !_isNoiseLine(l) && l.length >= 2)
          .toList();
      if (meaningful.isEmpty) continue;

      String name = meaningful[0];
      String teacher = '';
      String location = '';
      String weeks = _parseWeeks(trimmed) ?? '1-16';

      for (int i = 1; i < meaningful.length; i++) {
        final line = meaningful[i];
        if (_isChineseName(line) && teacher.isEmpty) {
          teacher = line;
        } else if (_isLocation(line) && location.isEmpty) {
          location = line;
        } else if (teacher.isEmpty &&
            line.length <= 6 &&
            RegExp(r'[一-龥]').hasMatch(line)) {
          teacher = line;
        } else if (location.isEmpty) {
          location = line;
        }
      }

      if (!RegExp(r'[一-龥a-zA-Z]').hasMatch(name)) continue;
      if (_isNoiseLine(name)) continue;
      if (name.length > 30) name = name.substring(0, 30);

      courses.add(
        Course(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          name: name,
          teacher: teacher,
          position: location,
          day: day.clamp(1, 7),
          startSection: startPeriod.clamp(1, 12),
          endSection: endPeriod.clamp(1, 12),
          weekList: _parseWeeksString(weeks),
          color: AppConstants.stableCourseColor(name),
        ),
      );
    }
    return courses;
  }

  List<String> _splitCourseBlocks(String text) {
    final normalized = text.replaceAll('；', ';;').replaceAll(';', ';;');
    final explicit = normalized
        .split(RegExp(r'\n{2,}|;;+'))
        .map((b) => b.trim())
        .where((b) => b.isNotEmpty)
        .toList();
    if (explicit.length > 1) return explicit;

    final lines = normalized
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    if (lines.length < 6) return explicit;

    final blocks = <String>[];
    var current = <String>[];
    for (final line in lines) {
      if (current.isNotEmpty &&
          _looksLikeCourseName(line) &&
          current.any(
            (item) => _parseWeeks(item) != null || _isLocation(item),
          )) {
        blocks.add(current.join('\n'));
        current = <String>[];
      }
      current.add(line);
    }
    if (current.isNotEmpty) blocks.add(current.join('\n'));
    return blocks.length > 1 ? blocks : explicit;
  }

  Course _courseFromNormalized(NormalizedScheduleCourse course) {
    final ws = course.weeks.trim().isEmpty ? '1-20' : course.weeks.trim();
    final name = course.name.trim();
    return Course(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name,
      teacher: course.teacher.trim(),
      position: course.position.trim(),
      day: course.day.clamp(1, 7),
      startSection: course.startSection.clamp(1, 12),
      endSection: course.endSection.clamp(1, 12),
      weekList: _parseWeeksString(ws),
      color: AppConstants.stableCourseColor(name),
    );
  }

  List<int> _parseWeeksString(String s) {
    final weeks = <int>[];
    final cleaned = s.replaceAll(RegExp(r'[单双周()（）]'), '');
    for (final part in cleaned.split(',')) {
      final range = part.split('-');
      if (range.length == 2) {
        final a = int.tryParse(range[0].trim()) ?? 1;
        final b = int.tryParse(range[1].trim()) ?? 20;
        for (var i = a; i <= b; i++) {
          weeks.add(i);
        }
      } else {
        final n = int.tryParse(range[0].trim());
        if (n != null) weeks.add(n);
      }
    }
    return weeks.isEmpty ? List.generate(20, (i) => i + 1) : weeks;
  }

  List<Course> _dedupeCourses(List<Course> courses) {
    final result = <Course>[];
    final seen = <String>{};
    for (final course in courses) {
      final key = [
        course.name.trim().toLowerCase(),
        course.day,
        course.startSection,
        course.endSection,
        course.weeks,
        course.position.trim().toLowerCase(),
      ].join('|');
      if (seen.add(key)) result.add(course);
    }
    return result;
  }

  bool _looksLikeHeaderTexts(List<String> cells) {
    final text = cells.join('|');
    final weekdayCount = RegExp(
      r'周[一二三四五六七日]|星期[一二三四五六七日]',
    ).allMatches(text).length;
    return weekdayCount >= 2 || text.contains('节次|') || text.contains('时间|');
  }

  bool _hasRowHeader(String text) {
    return _parsePeriod(text) != null ||
        _isBreakRow(text) ||
        text.contains('节') ||
        text.contains('时间') ||
        RegExp(r'^\d{1,2}$').hasMatch(text.trim());
  }

  bool _isBreakRow(String text) {
    final t = text.trim();
    return t == '午' ||
        t == '早晚' ||
        t.contains('午休') ||
        t.contains('休息') ||
        t.contains('上午') ||
        t.contains('下午') ||
        t.contains('晚上');
  }

  bool _isNoiseLine(String text) {
    final t = text.trim();
    if (t.isEmpty) return true;
    if (t.contains('�')) return true;
    if (t.contains('星期') || t.contains('节次') || t.contains('时间')) return true;
    if (RegExp(r'首页|当前位置|欢迎|退出|注销|学生之家|教工之家|我的信息|基本信息|修改密码|课程表$').hasMatch(t))
      return true;
    if (_isBreakRow(t)) return true;
    if (_parsePeriod(t) != null &&
        !RegExp(r'[一-龥a-zA-Z]').hasMatch(
          t.replaceAll(RegExp(r'第?\d{1,2}\s*[-~、,至]\s*\d{1,2}\s*节?'), ''),
        ))
      return true;
    return false;
  }

  String? _parseWeeks(String text) {
    final normalized = text.replaceAll('第', '').replaceAll(' ', '');
    final match = RegExp(
      r'(\d{1,2}(?:,\d{1,2})*(?:[-~—-]\d{1,2})?)周',
    ).firstMatch(normalized);
    if (match == null) return null;
    var weeks = match.group(1)!.replaceAll(RegExp(r'[~—-]'), '-');
    if (normalized.contains('单周') || normalized.contains('单'))
      weeks = '$weeks(单周)';
    if (normalized.contains('双周') || normalized.contains('双'))
      weeks = '$weeks(双周)';
    return weeks;
  }

  int? _parseDay(String text) {
    final trimmed = text.trim();
    final digit = RegExp(r'^[1-7]$').firstMatch(trimmed);
    if (digit != null) return int.parse(digit.group(0)!);

    final match = RegExp(r'(?:周|星期)?([一二三四五六七日天])').firstMatch(trimmed);
    if (match == null) return null;
    const map = {
      '一': 1,
      '二': 2,
      '三': 3,
      '四': 4,
      '五': 5,
      '六': 6,
      '七': 7,
      '日': 7,
      '天': 7,
    };
    return map[match.group(1)!];
  }

  (int, int)? _parsePeriod(String text) {
    final range = RegExp(
      r'第?\s*(\d{1,2})\s*[-~—-、,至]\s*(\d{1,2})\s*(?:节|课)?',
    ).firstMatch(text);
    if (range != null) {
      final start = int.tryParse(range.group(1)!);
      final end = int.tryParse(range.group(2)!);
      if (start != null && end != null) return (start, end);
    }

    final single = RegExp(r'第\s*(\d{1,2})\s*(?:节|课)').firstMatch(text);
    if (single != null) {
      final period = int.tryParse(single.group(1)!);
      if (period != null) return (period, period);
    }
    return null;
  }

  (int, int) _periodFromRow({int rowIdx = 0}) {
    const mapping = [(1, 2), (3, 4), (5, 6), (7, 8), (9, 10), (11, 12)];
    return rowIdx < mapping.length ? mapping[rowIdx] : mapping[0];
  }

  bool _looksLikeCourseName(String s) {
    if (_isNoiseLine(s) ||
        _isChineseName(s) ||
        _isLocation(s) ||
        _parseWeeks(s) != null ||
        _parsePeriod(s) != null)
      return false;
    return RegExp(r'[一-龥a-zA-Z]').hasMatch(s) &&
        s.length >= 2 &&
        s.length <= 30;
  }

  bool _isChineseName(String s) =>
      s.length >= 2 && s.length <= 4 && RegExp(r'^[一-龥]+$').hasMatch(s);
  bool _isLocation(String s) =>
      s.contains('教') ||
      s.contains('楼') ||
      s.contains('室') ||
      s.contains('实') ||
      s.contains('号') ||
      RegExp(r'[A-Za-z]\d').hasMatch(s) ||
      s.contains('-');

  _ParseStats _diagnoseJsonTables(List<dynamic> tables) {
    var tableCount = 0;
    var rowCount = 0;
    var candidateCellCount = 0;
    for (final table in tables) {
      if (table is! Map<String, dynamic> || table['rows'] is! List) continue;
      tableCount++;
      final rows = (table['rows'] as List).whereType<List<dynamic>>().toList();
      rowCount += rows.length;
      for (final row in rows) {
        for (final rawCell in row) {
          final cell = _GridCell.fromJson(rawCell);
          if (cell.text.trim().length >= 2) candidateCellCount++;
        }
      }
    }
    return _ParseStats(
      tableCount: tableCount,
      rowCount: rowCount,
      candidateCellCount: candidateCellCount,
    );
  }
}

class _ParseStats {
  final int tableCount;
  final int rowCount;
  final int candidateCellCount;

  const _ParseStats({
    this.tableCount = 0,
    this.rowCount = 0,
    this.candidateCellCount = 0,
  });
}

class _GridCell {
  final String text;
  final int rowSpan;
  final int colSpan;
  final String tag;
  final bool origin;

  const _GridCell({
    required this.text,
    required this.rowSpan,
    required this.colSpan,
    required this.tag,
    this.origin = true,
  });

  factory _GridCell.fromJson(dynamic json) {
    if (json is Map<String, dynamic>) {
      return _GridCell(
        text: (json['text'] ?? '').toString(),
        rowSpan: _intValue(json['rowSpan'] ?? json['rowspan'], 1),
        colSpan: _intValue(json['colSpan'] ?? json['colspan'], 1),
        tag: (json['tag'] ?? 'TD').toString().toUpperCase(),
      );
    }
    return _GridCell(
      text: json?.toString() ?? '',
      rowSpan: 1,
      colSpan: 1,
      tag: 'TD',
    );
  }

  _GridCell copyWith({bool? origin}) {
    return _GridCell(
      text: text,
      rowSpan: rowSpan,
      colSpan: colSpan,
      tag: tag,
      origin: origin ?? this.origin,
    );
  }

  static int _intValue(dynamic value, int fallback) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }
}
