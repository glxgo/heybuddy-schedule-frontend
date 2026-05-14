import 'course_parse_adapter.dart';
import 'normalized_schedule.dart';
import 'xiao_ai_schedule_adapter.dart';

class ScheduleAdapterRegistry {
  ScheduleAdapterRegistry({List<CourseParseAdapter>? adapters})
    : adapters = adapters ?? [XiaoAiScheduleAdapter()];

  final List<CourseParseAdapter> adapters;

  List<NormalizedScheduleCourse> parse(String systemType, String input) {
    return parseWithAdapter(systemType, input)?.courses ?? const [];
  }

  ScheduleAdapterResult? parseWithAdapter(String systemType, String input) {
    for (final adapter in adapters) {
      if (!adapter.canParse(systemType, input)) continue;
      final courses = adapter.parse(input);
      if (courses.isNotEmpty) {
        return ScheduleAdapterResult(adapterId: adapter.id, courses: courses);
      }
    }
    return null;
  }
}

class ScheduleAdapterResult {
  final String adapterId;
  final List<NormalizedScheduleCourse> courses;

  const ScheduleAdapterResult({required this.adapterId, required this.courses});
}
