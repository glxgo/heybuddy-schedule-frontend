import 'normalized_schedule.dart';

abstract class CourseParseAdapter {
  String get id;

  bool canParse(String systemType, String input);

  List<NormalizedScheduleCourse> parse(String input);
}
