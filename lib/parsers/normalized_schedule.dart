class NormalizedScheduleCourse {
  final String name;
  final int day;
  final List<int> sections;
  final String weeks;
  final String teacher;
  final String position;

  const NormalizedScheduleCourse({
    required this.name,
    required this.day,
    required this.sections,
    this.weeks = '1-16',
    this.teacher = '',
    this.position = '',
  });

  bool get isValid =>
      name.trim().isNotEmpty && day >= 1 && day <= 7 && sections.isNotEmpty;

  int get startSection => sections.reduce((a, b) => a < b ? a : b);
  int get endSection => sections.reduce((a, b) => a > b ? a : b);
}
