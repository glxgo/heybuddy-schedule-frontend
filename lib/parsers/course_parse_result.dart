import '../models/course.dart';
import 'course_parse_diagnostics.dart';

enum CourseParseConfidence { high, medium, low }

class CourseParseResult {
  final List<Course> courses;
  final CourseParseDiagnostics diagnostics;

  const CourseParseResult({required this.courses, required this.diagnostics});

  bool get hasCourses => courses.isNotEmpty;
  bool get requiresConfirmation =>
      hasCourses && confidence == CourseParseConfidence.low;
  bool get canImportDirectly => hasCourses && !requiresConfirmation;

  CourseParseConfidence get confidence {
    if (courses.isEmpty) return CourseParseConfidence.low;
    if (diagnostics.inputType == 'backend') return CourseParseConfidence.medium;
    if (diagnostics.warnings.isNotEmpty) return CourseParseConfidence.medium;
    return CourseParseConfidence.high;
  }

  Map<String, dynamic> toJson() => {
    'courseCount': courses.length,
    'confidence': confidence.name,
    'requiresConfirmation': requiresConfirmation,
    'canImportDirectly': canImportDirectly,
    'diagnostics': diagnostics.toJson(),
  };
}
