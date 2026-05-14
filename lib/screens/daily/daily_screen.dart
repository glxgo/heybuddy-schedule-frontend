import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/constants.dart';
import '../../config/theme.dart';
import '../../models/course.dart';
import '../../providers/friends_provider.dart';
import '../../providers/schedule_provider.dart';
import '../../widgets/course_tile.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/import_fab.dart';
import '../../widgets/liquid_scaffold.dart';

class DailyScreen extends ConsumerStatefulWidget {
  const DailyScreen({super.key});

  @override
  ConsumerState<DailyScreen> createState() => _DailyScreenState();
}

class _DailyScreenState extends ConsumerState<DailyScreen> {
  late final PageController _pageController;
  final Set<String> _requestedFriendCourseKeys = <String>{};
  int _dayOfWeek = DateTime.now().weekday;
  bool _checkedCloudRestore = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _dayOfWeek - 1);
    Future.microtask(() async {
      await ref.read(scheduleProvider.notifier).init();
      await _maybeRestoreCurrentSemester();
      _loadFriendCoursesIfNeeded();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _maybeRestoreCurrentSemester() async {
    if (_checkedCloudRestore || !mounted) return;
    _checkedCloudRestore = true;

    final scheduleState = ref.read(scheduleProvider);
    if (scheduleState.courses.isNotEmpty) return;

    final remoteCourses = await ref
        .read(scheduleProvider.notifier)
        .fetchRemoteCoursesForCurrentSemester();
    if (!mounted || remoteCourses.isEmpty) return;

    final shouldRestore = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('恢复云端课表'),
        content: Text(
          '检测到云端保存了 ${remoteCourses.length} 门当前学期课程，是否恢复到当前课表？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('暂不恢复'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('立即恢复'),
          ),
        ],
      ),
    );
    if (shouldRestore != true || !mounted) return;

    final msg = await ref
        .read(scheduleProvider.notifier)
        .restoreCurrentSemesterFromCloud(prefetchedCourses: remoteCourses);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  Future<void> _animateToDay(int targetDay) async {
    final clamped = targetDay.clamp(1, 7);
    if (clamped == _dayOfWeek) return;
    await _pageController.animateToPage(
      clamped - 1,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
    );
  }

  void _loadFriendCoursesIfNeeded() {
    final friends = ref.read(friendsProvider).friends;
    final semester =
        ref.read(scheduleProvider).currentTable?.semester ??
        AppConstants.defaultSemester;
    for (final f in friends.take(2)) {
      final key = '${f.friendId}::$semester';
      if (_requestedFriendCourseKeys.add(key)) {
        ref.read(scheduleProvider.notifier).hydrateCachedFriendCourses(f.friendId);
        ref.read(scheduleProvider.notifier).refreshFriendCourses(f.friendId);
      }
    }
  }

  String _dayLabel(int dayOfWeek) {
    if (dayOfWeek < 1 || dayOfWeek > 7) return AppConstants.weekDayLabels[0];
    return AppConstants.weekDayLabels[dayOfWeek - 1];
  }

  List<Course> _coursesForDay(
    List<Course> courses,
    int dayOfWeek,
    int currentWeek,
  ) {
    return courses
        .where((c) => c.day == dayOfWeek && c.isActiveInWeek(currentWeek))
        .toList()
      ..sort((a, b) => a.startSection.compareTo(b.startSection));
  }

  Widget _buildDayPage({
    required int dayOfWeek,
    required List<Course> myCourses,
    required List<FriendInfo> displayFriends,
    required ScheduleState scheduleState,
    required int currentWeek,
    required bool isDark,
  }) {
    final columnSources = <List<Course>>[myCourses];
    for (final f in displayFriends) {
      columnSources.add(
        _coursesForDay(
          scheduleState.friendCoursesMap[f.friendId] ?? const [],
          dayOfWeek,
          currentWeek,
        ),
      );
    }

    if (myCourses.isEmpty && columnSources.every((cs) => cs.isEmpty)) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: GlassCard(
            borderRadius: 28,
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 34),
            elevation: 1.3,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColorTokens.primary.withAlpha(isDark ? 55 : 28),
                    border: Border.all(
                      color: AppColorTokens.primary.withAlpha(70),
                    ),
                  ),
                  child: const Icon(
                    Icons.event_note_rounded,
                    size: 36,
                    color: AppColorTokens.primary,
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  '今天没有课程',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                const Text(
                  '点击右下角导入课表',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColorTokens.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 132),
      itemCount: AppConstants.defaultTimeSlots.length,
      itemBuilder: (context, rowIdx) {
        final slot = AppConstants.defaultTimeSlots[rowIdx];
        final period = slot.period;
        return SizedBox(
          height: 62,
          child: Row(
            children: [
              SizedBox(
                width: 54,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      period.toString().padLeft(2, '0'),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: isDark
                            ? AppColorTokens.darkTextSecondary
                            : AppColorTokens.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      slot.start,
                      style: TextStyle(
                        fontSize: 9,
                        color: isDark
                            ? AppColorTokens.darkTextTertiary
                            : AppColorTokens.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              for (final source in columnSources)
                Expanded(
                  child: (() {
                    final slotCourses = source
                        .where((c) => c.overlapsWithPeriod(period))
                        .toList();
                    final course = slotCourses.isNotEmpty ? slotCourses.first : null;
                    return course != null
                        ? CourseTile(course: course, height: 58, onTap: () {})
                        : Container(
                            margin: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppColorTokens.darkSurfaceGlass
                                  : AppColorTokens.surfaceGlass,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isDark
                                    ? AppColorTokens.darkGlassBorder
                                    : AppColorTokens.glassBorder.withAlpha(120),
                                width: 0.5,
                              ),
                            ),
                          );
                  })(),
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheduleState = ref.watch(scheduleProvider);
    final friendsState = ref.watch(friendsProvider);
    final currentWeek = estimateCurrentWeek(null, scheduleState.currentTable);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final displayFriends = friendsState.friends.take(2).toList();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || displayFriends.isEmpty) return;
      _loadFriendCoursesIfNeeded();
    });

    return LiquidScaffold(
      appBar: AppBar(title: const Text('每日')),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 86),
        child: ImportFab(onPressed: () => context.push('/import')),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 6),
            child: GlassCard(
              borderRadius: 24,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              elevation: 0.8,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: _dayOfWeek > 1 ? () => _animateToDay(_dayOfWeek - 1) : null,
                    icon: const Icon(Icons.chevron_left_rounded, size: 24),
                    tooltip: '前一天',
                  ),
                  Expanded(
                    child: Center(
                      child: Column(
                        children: [
                          Text(
                            _dayLabel(_dayOfWeek),
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            DateTime.now().weekday == _dayOfWeek
                                ? '今天的安排'
                                : '左右滑动查看这一天的课程',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark
                                  ? AppColorTokens.darkTextTertiary
                                  : AppColorTokens.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _dayOfWeek < 7 ? () => _animateToDay(_dayOfWeek + 1) : null,
                    icon: const Icon(Icons.chevron_right_rounded, size: 24),
                    tooltip: '后一天',
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(64, 6, 10, 4),
            child: Row(
              children: [
                Expanded(
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColorTokens.primary.withAlpha(28),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: const Text(
                        '我的',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppColorTokens.primary,
                        ),
                      ),
                    ),
                  ),
                ),
                for (final f in displayFriends)
                  Expanded(
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColorTokens.accent.withAlpha(22),
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Text(
                          '${f.nickname}的',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppColorTokens.accent,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: scheduleState.isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColorTokens.primary),
                  )
                : PageView.builder(
                    controller: _pageController,
                    itemCount: 7,
                    onPageChanged: (index) {
                      setState(() {
                        _dayOfWeek = index + 1;
                      });
                    },
                    itemBuilder: (context, index) {
                      final dayOfWeek = index + 1;
                      final myCourses = _coursesForDay(
                        scheduleState.courses,
                        dayOfWeek,
                        currentWeek,
                      );
                      return _buildDayPage(
                        dayOfWeek: dayOfWeek,
                        myCourses: myCourses,
                        displayFriends: displayFriends,
                        scheduleState: scheduleState,
                        currentWeek: currentWeek,
                        isDark: isDark,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
