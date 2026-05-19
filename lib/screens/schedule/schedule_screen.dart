import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/constants.dart';
import '../../config/theme.dart';
import '../../models/course.dart';
import '../../providers/schedule_provider.dart';
import '../../providers/friends_provider.dart';
import '../../widgets/course_edit_sheet.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/import_fab.dart';
import '../../widgets/liquid_scaffold.dart';
import '../../widgets/weekly_grid.dart';

class ScheduleScreen extends ConsumerStatefulWidget {
  const ScheduleScreen({super.key});

  @override
  ConsumerState<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends ConsumerState<ScheduleScreen> {
  PageController? _pageController;
  int _currentWeek = 1;
  int _actualCurrentWeek = 1;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await ref.read(scheduleProvider.notifier).init();
      final table = ref.read(scheduleProvider).currentTable;
      _currentWeek = estimateCurrentWeek(null, table);
      _actualCurrentWeek = _currentWeek;
      _pageController = PageController(initialPage: _currentWeek - 1);
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _pageController?.dispose();
    super.dispose();
  }

  Future<void> _animateToWeek(int targetWeek) async {
    final maxWeeks = ref.read(scheduleProvider).currentTable?.totalWeeks ?? 20;
    final clamped = targetWeek.clamp(1, maxWeeks);
    if (_pageController == null || clamped == _currentWeek) return;
    await _pageController!.animateToPage(
      clamped - 1,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
    );
  }

  Future<bool> _confirmDeleteCourse(Course course) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除课程'),
        content: Text('确定删除“${course.name}”吗？删除后无法恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColorTokens.error,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  String? _compareFriendId;
  String? _compareFriendName;

  Future<void> _showCompareFriendSheet() async {
    final friends = ref.read(friendsProvider).friends;
    if (friends.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('还没有好友，请先添加好友')),
      );
      return;
    }
    final result = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(padding: EdgeInsets.all(16), child: Text('选择对比好友', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
            ...friends.map((f) => ListTile(
              title: Text(f.nickname),
              subtitle: f.schoolName != null ? Text(f.schoolName!, style: const TextStyle(fontSize: 12)) : null,
              onTap: () => Navigator.pop(ctx, '${f.friendId}|${f.nickname}'),
            )),
            if (_compareFriendId != null)
              ListTile(
                leading: const Icon(Icons.close, color: AppColorTokens.error),
                title: const Text('取消对比', style: TextStyle(color: AppColorTokens.error)),
                onTap: () => Navigator.pop(ctx, ''),
              ),
          ],
        ),
      ),
    );
    if (result == null) return;
    if (result.isEmpty) {
      setState(() { _compareFriendId = null; _compareFriendName = null; });
      return;
    }
    final parts = result.split('|');
    setState(() {
      _compareFriendId = parts[0];
      _compareFriendName = parts[1];
    });
    final notifier = ref.read(scheduleProvider.notifier);
    await notifier.hydrateCachedFriendCourses(parts[0]);
    await notifier.refreshFriendCourses(parts[0]);
  }

  Future<void> _showCourseEdit(
    Course? course, {
    int prefillDay = 1,
    int prefillStart = 1,
    int prefillEnd = 1,
  }) async {
    final result = await showModalBottomSheet<dynamic>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => CourseEditSheet(
        course: course,
        prefillDay: prefillDay,
        prefillStartSection: prefillStart,
        prefillEndSection: prefillEnd,
      ),
    );

    if (result == CourseEditAction.delete && course != null) {
      final confirmed = await _confirmDeleteCourse(course);
      if (confirmed) {
        await ref.read(scheduleProvider.notifier).removeCourse(course.id);
      }
    } else if (result is CourseEditData) {
      final id = course?.id ?? DateTime.now().microsecondsSinceEpoch.toString();
      final currentTable = ref.read(scheduleProvider).currentTable;
      final newCourse = Course(
        id: id,
        name: result.name,
        teacher: result.teacher,
        position: result.position,
        day: result.day,
        startSection: result.startSection,
        endSection: result.endSection,
        weekList: _parseWeeks(result.weeks),
        color: result.color,
        tableId: ref.read(scheduleProvider).currentTableId,
        semester: currentTable?.semester ?? course?.semester ?? AppConstants.defaultSemester,
      );
      await ref.read(scheduleProvider.notifier).saveCourse(newCourse);
    }
  }

  List<int> _parseWeeks(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return List.generate(20, (i) => i + 1);

    final oddOnly = trimmed.contains('单周') || trimmed.contains('(单)');
    final evenOnly = trimmed.contains('双周') || trimmed.contains('(双)');
    bool matchesParity(int week) {
      if (oddOnly) return week.isOdd;
      if (evenOnly) return week.isEven;
      return true;
    }

    final normalized = trimmed
        .replaceAll('，', ',')
        .replaceAll('、', ',')
        .replaceAll('第', '')
        .replaceAll('周', '')
        .replaceAll('(单)', '')
        .replaceAll('(双)', '')
        .replaceAll('单周', '')
        .replaceAll('双周', '');
    final parts = normalized.split(',');
    final weeks = <int>[];
    for (final part in parts) {
      final range = part.trim().split('-');
      if (range.length == 2) {
        final start = int.tryParse(range[0].trim());
        final end = int.tryParse(range[1].trim());
        if (start != null && end != null) {
          for (var w = start; w <= end; w++) {
            if (matchesParity(w)) {
              weeks.add(w);
            }
          }
        }
      } else {
        final single = int.tryParse(range[0].trim());
        if (single != null && matchesParity(single)) weeks.add(single);
      }
    }
    if (weeks.isEmpty) {
      return List.generate(20, (i) => i + 1);
    }
    final deduped = weeks.toSet().toList()..sort();
    return deduped;
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: GlassCard(
          borderRadius: 28,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 34),
          elevation: 1.4,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [
                      AppColorTokens.primary,
                      AppColorTokens.primaryGradientEnd,
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColorTokens.primary.withAlpha(55),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.calendar_month_rounded,
                  size: 38,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                '还没有课表',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColorTokens.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '点击右下角导入课程，开始安排你的校园时间',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColorTokens.textSecondary,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(scheduleProvider);
    final maxWeeks = state.currentTable?.totalWeeks ?? 20;

    return LiquidScaffold(
      appBar: AppBar(
        title: Text(state.currentTable?.name ?? '课表'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Center(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: _showCompareFriendSheet,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(92),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColorTokens.primary.withAlpha(80)),
                    ),
                    child: Text(
                      _compareFriendName == null ? '对比' : '对比 · $_compareFriendName',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppColorTokens.primary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.table_chart_outlined, size: 20),
            onPressed: () => context.push('/table-manage'),
            tooltip: '管理课表',
          ),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 86),
        child: ImportFab(onPressed: () => context.push('/import')),
      ),
      body: state.isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColorTokens.primary),
            )
          : state.courses.isEmpty
              ? _buildEmptyState()
              : _pageController == null
                  ? const SizedBox.shrink()
                  : PageView.builder(
                      controller: _pageController,
                      itemCount: maxWeeks,
                      onPageChanged: (index) {
                        setState(() {
                          _currentWeek = index + 1;
                        });
                      },
                      itemBuilder: (context, index) {
                        final week = index + 1;
                        return WeeklyGrid(
                          courses: state.courses,
                          timeSlots: state.timeSlots,
                          currentWeek: week,
                          isCurrentWeek: week == _actualCurrentWeek,
                          onWeekChanged: (w) => _animateToWeek(w),
                          onTapCourse: (course) => _showCourseEdit(course),
                          onTapEmpty: (day, start, end) => _showCourseEdit(null, prefillDay: day, prefillStart: start, prefillEnd: end),
                          compareCourses: state.friendCoursesMap[_compareFriendId] ?? [],
                          compareName: _compareFriendName,
                        );
                      },
                    ),
    );
  }
}
