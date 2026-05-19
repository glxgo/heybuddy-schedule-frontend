import 'package:flutter/material.dart';

import '../config/constants.dart';
import '../config/theme.dart';
import '../models/course.dart';
import 'course_tile.dart';
import 'glass_card.dart';

class _CompareSegment {
  final int day;
  final int startSection;
  final int endSection;
  final String label;
  final Color color;

  const _CompareSegment({
    required this.day,
    required this.startSection,
    required this.endSection,
    required this.label,
    required this.color,
  });

  int get duration => endSection - startSection + 1;
}

class WeeklyGrid extends StatefulWidget {
  final List<Course> courses;
  final List<TimeSlot> timeSlots;
  final int currentWeek;
  final ValueChanged<int>? onWeekChanged;
  final void Function(Course course)? onTapCourse;
  final void Function(int day, int startSection, int endSection)? onTapEmpty;
  final List<Course> compareCourses;
  final String? compareName;
  final bool isCurrentWeek;

  const WeeklyGrid({
    super.key,
    this.courses = const [],
    this.timeSlots = const [],
    this.currentWeek = 1,
    this.onWeekChanged,
    this.onTapCourse,
    this.onTapEmpty,
    this.compareCourses = const [],
    this.compareName,
    this.isCurrentWeek = false,
  });

  @override
  State<WeeklyGrid> createState() => _WeeklyGridState();
}

class _WeeklyGridState extends State<WeeklyGrid> {
  static const _rowHeight = 54.0;
  static const _periodLabelWidth = 54.0;
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

  List<_CompareSegment> _buildCompareSegments({
    required int rowCount,
    required Set<int> mySlots,
    required Set<int> friendSlots,
  }) {
    final segments = <_CompareSegment>[];
    for (var day = 1; day <= 7; day++) {
      String? currentStatus;
      var startSection = 1;
      for (var section = 1; section <= rowCount + 1; section++) {
        final status = section <= rowCount
            ? _compareStatusForSlot(day, section, mySlots, friendSlots)
            : '__end__';
        if (currentStatus == null) {
          currentStatus = status;
          startSection = section;
          continue;
        }
        if (status != currentStatus) {
          segments.add(
            _CompareSegment(
              day: day,
              startSection: startSection,
              endSection: section - 1,
              label: _compareLabel(currentStatus),
              color: _compareColor(currentStatus),
            ),
          );
          currentStatus = status;
          startSection = section;
        }
      }
    }
    return segments;
  }

  String _compareStatusForSlot(
    int day,
    int section,
    Set<int> mySlots,
    Set<int> friendSlots,
  ) {
    final slotKey = day * 100 + section;
    final iHave = mySlots.contains(slotKey);
    final friendHas = friendSlots.contains(slotKey);
    if (iHave && friendHas) return 'both';
    if (!iHave && !friendHas) return 'none';
    if (iHave) return 'mine';
    return 'friend';
  }

  String _compareLabel(String status) {
    switch (status) {
      case 'both':
        return '两人都有课';
      case 'none':
        return '无课';
      case 'mine':
        return '我有课';
      case 'friend':
        return '${widget.compareName ?? '好友'}有课';
      default:
        return '';
    }
  }

  Color _compareColor(String status) {
    switch (status) {
      case 'both':
        return AppColorTokens.error;
      case 'none':
        return AppColorTokens.success;
      case 'mine':
      case 'friend':
        return AppColorTokens.warning;
      default:
        return AppColorTokens.warning;
    }
  }

  @override
  Widget build(BuildContext context) {
    final mine = _mergedCourses(_filtered(widget.courses));
    final timeSlots = AppConstants.resolveTimeSlots(widget.timeSlots);
    final rowCount = timeSlots.length;
    final dayLabels = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    final today = DateTime.now().weekday;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isCompare = widget.compareName != null && widget.compareCourses.isNotEmpty;

    // Build slot occupation maps for compare mode
    Set<int> mySlots = {};
    Set<int> friendSlots = {};
    List<_CompareSegment> compareSegments = const [];
    if (isCompare) {
      final friendMerged = _mergedCourses(_filtered(widget.compareCourses));
      for (final c in mine) {
        for (int p = c.startSection; p <= c.endSection; p++) {
          mySlots.add(c.day * 100 + p);
        }
      }
      for (final c in friendMerged) {
        for (int p = c.startSection; p <= c.endSection; p++) {
          friendSlots.add(c.day * 100 + p);
        }
      }
      compareSegments = _buildCompareSegments(
        rowCount: rowCount,
        mySlots: mySlots,
        friendSlots: friendSlots,
      );
    }

    return Column(
      children: [
        // Compare banner
        if (widget.compareName != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            color: AppColorTokens.warning.withAlpha(25),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.compare_arrows, size: 16, color: AppColorTokens.warning),
                const SizedBox(width: 8),
                Text('正在对比: ${widget.compareName}', style: const TextStyle(fontSize: 12, color: AppColorTokens.warning, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
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
                      '第 ${widget.currentWeek} 周${widget.isCurrentWeek ? " · 本周" : ""}',
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
                    height: _rowHeight * rowCount,
                    child: Stack(
                      children: [
                        ...List.generate(rowCount, (periodIdx) {
                          final slot = timeSlots[periodIdx];
                          return Positioned(
                            left: 0,
                            top: periodIdx * _rowHeight,
                            width: _periodLabelWidth,
                            height: _rowHeight,
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    slot.label,
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      color: isDark
                                          ? AppColorTokens.darkTextSecondary
                                          : AppColorTokens.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 1),
                                  Text(
                                    slot.start,
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w800,
                                      color: isDark
                                          ? AppColorTokens.darkTextSecondary
                                          : AppColorTokens.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 1),
                                  Text(
                                    slot.end,
                                    style: TextStyle(
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.w700,
                                      color: isDark
                                          ? AppColorTokens.darkTextTertiary
                                          : AppColorTokens.textTertiary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                        ...List.generate(rowCount * dayLabels.length, (index) {
                          final periodIdx = index ~/ dayLabels.length;
                          final dayIdx = index % dayLabels.length;
                          final activeColumn = today == dayIdx + 1;

                          return Positioned(
                            left: _periodLabelWidth + dayIdx * dayWidth,
                            top: periodIdx * _rowHeight,
                            width: dayWidth,
                            height: _rowHeight,
                            child: GestureDetector(
                              onTap: !isCompare && widget.onTapEmpty != null
                                  ? () => widget.onTapEmpty!(dayIdx + 1, periodIdx + 1, periodIdx + 1)
                                  : null,
                              child: Container(
                                margin: const EdgeInsets.all(1.4),
                                decoration: BoxDecoration(
                                  color: activeColumn
                                      ? AppColorTokens.primary.withAlpha(isDark ? 18 : 10)
                                      : (isDark ? AppColorTokens.darkSurfaceGlass : AppColorTokens.surfaceGlass)
                                          .withAlpha(isDark ? 90 : 115),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isDark ? AppColorTokens.darkGlassBorder : AppColorTokens.glassBorder.withAlpha(110),
                                    width: 0.45,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                        if (isCompare)
                          ...compareSegments.map((segment) {
                            final height = _rowHeight * segment.duration;
                            return Positioned(
                              left: _periodLabelWidth + (segment.day - 1) * dayWidth,
                              top: (segment.startSection - 1) * _rowHeight,
                              width: dayWidth,
                              height: height,
                              child: Container(
                                margin: const EdgeInsets.all(1.4),
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                                decoration: BoxDecoration(
                                  color: segment.color.withAlpha(25),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: segment.color.withAlpha(80),
                                    width: 1,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    segment.label,
                                    textAlign: TextAlign.center,
                                    maxLines: segment.duration >= 2 ? 2 : 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      color: segment.color,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                        if (!isCompare)
                          ...mine.map((course) {
                            final height = _rowHeight * course.duration;
                            return Positioned(
                              left: _periodLabelWidth + (course.day - 1) * dayWidth,
                              top: (course.startSection - 1) * _rowHeight,
                              width: dayWidth,
                              height: height,
                              child: CourseTile(
                                course: course,
                                height: height - 2,
                                onTap: widget.onTapCourse != null ? () => widget.onTapCourse!(course) : null,
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
