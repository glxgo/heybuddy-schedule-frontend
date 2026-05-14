import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/course.dart';
import 'course_tile.dart';
import 'glass_card.dart';

class WeeklyGrid extends StatefulWidget {
  final List<Course> courses;
  final List<Course> friendCourses;
  final int currentWeek;
  final ValueChanged<int>? onWeekChanged;
  final void Function(Course course)? onTapCourse;
  final void Function(int day, int startSection, int endSection)? onTapEmpty;

  const WeeklyGrid({
    super.key,
    this.courses = const [],
    this.friendCourses = const [],
    this.currentWeek = 1,
    this.onWeekChanged,
    this.onTapCourse,
    this.onTapEmpty,
  });

  @override
  State<WeeklyGrid> createState() => _WeeklyGridState();
}

class _WeeklyGridState extends State<WeeklyGrid> {
  static const _rowHeight = 54.0;
  static const _periodLabelWidth = 36.0;
  late final ScrollController _scrollCtrl;

  @override
  void initState() {
    super.initState();
    _scrollCtrl = ScrollController();
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  List<Course> _filtered(List<Course> source) {
    return source.where((c) => c.isActiveInWeek(widget.currentWeek)).toList();
  }

  List<Course> _mergedCourses(List<Course> source) {
    final sorted = [...source]
      ..sort((a, b) {
        final dayCompare = a.day.compareTo(b.day);
        if (dayCompare != 0) return dayCompare;
        return a.startSection.compareTo(b.startSection);
      });

    final merged = <Course>[];
    for (final course in sorted) {
      if (course.day < 1 || course.day > 7) continue;
      if (course.endSection < 1 || course.startSection > 12) continue;
      final normalized = course.copyWith(
        startSection: course.startSection.clamp(1, 12),
        endSection: course.endSection.clamp(1, 12),
      );
      if (merged.isEmpty) {
        merged.add(normalized);
        continue;
      }

      final last = merged.last;
      final sameCourse =
          last.day == normalized.day &&
          last.name == normalized.name &&
          last.teacher == normalized.teacher &&
          last.position == normalized.position &&
          last.color == normalized.color;
      final continuous = normalized.startSection <= last.endSection + 1;
      if (sameCourse && continuous) {
        merged[merged.length - 1] = last.copyWith(
          endSection: normalized.endSection > last.endSection
              ? normalized.endSection
              : last.endSection,
        );
      } else {
        merged.add(normalized);
      }
    }
    return merged;
  }

  @override
  Widget build(BuildContext context) {
    final mine = _mergedCourses(_filtered(widget.courses));
    final dayLabels = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    final today = DateTime.now().weekday;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 2, 14, 8),
          child: GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            borderRadius: 22,
            elevation: 0.8,
            blur: 18,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left_rounded, size: 22),
                  onPressed: () =>
                      widget.onWeekChanged?.call(widget.currentWeek - 1),
                  tooltip: '上一周',
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      '第 ${widget.currentWeek} 周',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right_rounded, size: 22),
                  onPressed: () =>
                      widget.onWeekChanged?.call(widget.currentWeek + 1),
                  tooltip: '下一周',
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              const SizedBox(width: _periodLabelWidth),
              ...List.generate(dayLabels.length, (index) {
                final day = index + 1;
                final active = today == day;
                return Expanded(
                  child: Center(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 4,
                      ),
                      decoration: active
                          ? BoxDecoration(
                              color: AppColorTokens.primary.withAlpha(
                                isDark ? 70 : 28,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColorTokens.primary.withAlpha(75),
                              ),
                            )
                          : null,
                      child: Text(
                        dayLabels[index],
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: active
                              ? FontWeight.w800
                              : FontWeight.w600,
                          color: active
                              ? AppColorTokens.primary
                              : (isDark
                                    ? AppColorTokens.darkTextSecondary
                                    : AppColorTokens.textSecondary),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 5),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 92),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final dayWidth =
                    (constraints.maxWidth - _periodLabelWidth) /
                    dayLabels.length;
                return SingleChildScrollView(
                  controller: _scrollCtrl,
                  child: SizedBox(
                    height: _rowHeight * 12,
                    child: Stack(
                      children: [
                        ...List.generate(12, (periodIdx) {
                          final period = periodIdx + 1;
                          return Positioned(
                            left: 0,
                            top: periodIdx * _rowHeight,
                            width: _periodLabelWidth,
                            height: _rowHeight,
                            child: Center(
                              child: Text(
                                '$period',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: isDark
                                      ? AppColorTokens.darkTextTertiary
                                      : AppColorTokens.textTertiary,
                                ),
                              ),
                            ),
                          );
                        }),
                        ...List.generate(12 * dayLabels.length, (index) {
                          final periodIdx = index ~/ dayLabels.length;
                          final dayIdx = index % dayLabels.length;
                          final activeColumn = today == dayIdx + 1;
                          return Positioned(
                            left: _periodLabelWidth + dayIdx * dayWidth,
                            top: periodIdx * _rowHeight,
                            width: dayWidth,
                            height: _rowHeight,
                            child: GestureDetector(
                              onTap: widget.onTapEmpty != null
                                  ? () => widget.onTapEmpty!(
                                      dayIdx + 1, periodIdx + 1, periodIdx + 1)
                                  : null,
                              child: Container(
                              margin: const EdgeInsets.all(1.4),
                              decoration: BoxDecoration(
                                color: activeColumn
                                    ? AppColorTokens.primary.withAlpha(
                                        isDark ? 18 : 10,
                                      )
                                    : (isDark
                                              ? AppColorTokens.darkSurfaceGlass
                                              : AppColorTokens.surfaceGlass)
                                          .withAlpha(isDark ? 90 : 115),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isDark
                                      ? AppColorTokens.darkGlassBorder
                                      : AppColorTokens.glassBorder.withAlpha(
                                          110,
                                        ),
                                  width: 0.45,
                                ),
                              ),
                            ),
                              ),
                          );
                        }),
                        ...mine.map((course) {
                          final height = _rowHeight * course.duration;
                          return Positioned(
                            left:
                                _periodLabelWidth + (course.day - 1) * dayWidth,
                            top: (course.startSection - 1) * _rowHeight,
                            width: dayWidth,
                            height: height,
                            child: CourseTile(
                              course: course,
                              height: height - 2,
                              onTap: widget.onTapCourse != null
                                  ? () => widget.onTapCourse!(course)
                                  : null,
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
