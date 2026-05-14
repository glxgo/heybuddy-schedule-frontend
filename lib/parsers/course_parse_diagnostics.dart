class CourseParseDiagnostics {
  final String inputType;
  final String? adapterId;
  final int tableCount;
  final int rowCount;
  final int candidateCellCount;
  final int parsedCourseCount;
  final List<String> warnings;

  const CourseParseDiagnostics({
    required this.inputType,
    this.adapterId,
    this.tableCount = 0,
    this.rowCount = 0,
    this.candidateCellCount = 0,
    required this.parsedCourseCount,
    this.warnings = const [],
  });

  bool get isSuccess => parsedCourseCount > 0;

  Map<String, dynamic> toJson() => {
    'inputType': inputType,
    'adapterId': adapterId,
    'tableCount': tableCount,
    'rowCount': rowCount,
    'candidateCellCount': candidateCellCount,
    'parsedCourseCount': parsedCourseCount,
    'warnings': warnings,
  };
}
