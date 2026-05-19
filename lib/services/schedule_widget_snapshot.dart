import '../config/constants.dart';
import '../models/course.dart';

Map<String, dynamic> buildScheduleWidgetSnapshot({
  required CourseTable? currentTable,
  required List<Course> courses,
  DateTime? now,
}) {
  final timestamp = now ?? DateTime.now();
  final currentWeek = currentTable == null
      ? 1
      : estimateScheduleWidgetWeek(currentTable, timestamp);
  final sortedCourses = [...courses]..sort(_compareCourses);

  return {
    'version': 1,
    'table': currentTable == null
        ? null
        : {
            'id': currentTable.id,
            'name': currentTable.name,
            'semester': currentTable.semester,
            'startDate': currentTable.startDate,
            'totalWeeks': currentTable.totalWeeks,
          },
    'weekLabel': currentTable == null ? '' : '第$currentWeek周',
    'subtitle': currentTable == null
        ? '打开相伴课表后会自动同步'
        : (currentTable.semester.isEmpty ? '桌面周课表' : currentTable.semester),
    'currentWeek': currentWeek,
    'updatedAt': timestamp.toIso8601String(),
    'days': List.generate(7, (index) {
      final day = index + 1;
      final dayCourses = sortedCourses
          .where(
            (course) =>
                course.day == day &&
                (currentTable == null || course.isActiveInWeek(currentWeek)),
          )
          .map(_toWidgetCourseJson)
          .toList();
      return {
        'day': day,
        'label': AppConstants.weekDayLabels[index],
        'courses': dayCourses,
      };
    }),
  };
}

int estimateScheduleWidgetWeek(CourseTable table, [DateTime? date]) {
  final now = date ?? DateTime.now();
  final start = table.startDateTime;
  if (start != null) {
    final diff = now.difference(start).inDays;
    final week = (diff / 7).floor() + 1;
    return week.clamp(1, table.totalWeeks);
  }
  final semesterStart = DateTime(now.year, 2, 17);
  final diff = now.difference(semesterStart).inDays;
  return ((diff / 7).floor() + 1).clamp(1, 20);
}

Map<String, dynamic> _toWidgetCourseJson(Course course) {
  final location = course.position.trim();
  final summary = location.isEmpty
      ? '${course.name} ${course.startSection}-${course.endSection}节'
      : '${course.name} ${course.startSection}-${course.endSection}节 @ $location';

  return {
    'id': course.id,
    'name': course.name,
    'teacher': course.teacher,
    'location': location,
    'startSection': course.startSection,
    'endSection': course.endSection,
    'weeks': course.weekList,
    'summary': summary,
  };
}

int _compareCourses(Course a, Course b) {
  final dayCompare = a.day.compareTo(b.day);
  if (dayCompare != 0) return dayCompare;

  final startCompare = a.startSection.compareTo(b.startSection);
  if (startCompare != 0) return startCompare;

  final endCompare = a.endSection.compareTo(b.endSection);
  if (endCompare != 0) return endCompare;

  return a.name.compareTo(b.name);
}
