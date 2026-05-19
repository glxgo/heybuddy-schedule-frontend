import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/constants.dart';
import '../../config/theme.dart';
import '../../models/course.dart';
import '../../providers/friends_provider.dart';
import '../../providers/schedule_provider.dart';
import '../../providers/settings_provider.dart';
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
  int _dayOfWeek = DateTime.now().weekday;
  bool _checkedCloudRestore = false;
  final _friendScrollController = ScrollController();
  final _headerNameScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _friendScrollController.addListener(_syncHeaderScroll);
    Future.microtask(() async {
      await ref.read(scheduleProvider.notifier).init();
      await _maybeRestoreCurrentSemester();
      _loadAllFriendCourses();
    });
    // Watch for friends to load later (e.g. first app open)
    ref.listenManual(friendsProvider, (prev, next) {
      if (prev?.friends != next.friends) {
        _loadAllFriendCourses();
      }
    });
  }

  void _syncHeaderScroll() {
    if (_headerNameScrollController.hasClients) {
      _headerNameScrollController.jumpTo(_friendScrollController.offset);
    }
  }

  @override
  void dispose() {
    _friendScrollController.removeListener(_syncHeaderScroll);
    _friendScrollController.dispose();
    _headerNameScrollController.dispose();
    super.dispose();
  }

  Future<void> _maybeRestoreCurrentSemester() async {
    if (_checkedCloudRestore || !mounted) return;
    _checkedCloudRestore = true;
    final scheduleState = ref.read(scheduleProvider);
    if (scheduleState.courses.isNotEmpty) return;
    final remoteCourses =
        await ref.read(scheduleProvider.notifier).fetchRemoteCoursesForCurrentSemester();
    if (!mounted || remoteCourses.isEmpty) return;
    final shouldRestore = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('恢复云端课表'),
        content: Text('检测到云端保存了 ${remoteCourses.length} 门当前学期课程，是否恢复到当前课表？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('暂不恢复')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('立即恢复')),
        ],
      ),
    );
    if (shouldRestore != true || !mounted) return;
    final msg = await ref
        .read(scheduleProvider.notifier)
        .restoreCurrentSemesterFromCloud(prefetchedCourses: remoteCourses);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _loadAllFriendCourses() {
    final friends = ref.read(friendsProvider).friends;
    for (final f in friends) {
      ref.read(scheduleProvider.notifier).hydrateCachedFriendCourses(f.friendId);
      ref.read(scheduleProvider.notifier).refreshFriendCourses(f.friendId);
    }
  }

  String _dayLabel(int dayOfWeek) {
    if (dayOfWeek < 1 || dayOfWeek > 7) return AppConstants.weekDayLabels[0];
    return AppConstants.weekDayLabels[dayOfWeek - 1];
  }

  List<Course> _mergedCourses(List<Course> source) {
    final sorted = [...source]
      ..sort((a, b) {
        final startCompare = a.startSection.compareTo(b.startSection);
        if (startCompare != 0) return startCompare;
        return a.endSection.compareTo(b.endSection);
      });
    final merged = <Course>[];
    for (final course in sorted) {
      final normalized = course.copyWith(
        startSection: course.startSection.clamp(1, 12),
        endSection: course.endSection.clamp(1, 12),
      );
      if (merged.isEmpty) {
        merged.add(normalized);
        continue;
      }
      final last = merged.last;
      final sameCourse = last.name == normalized.name &&
          last.teacher == normalized.teacher &&
          last.position == normalized.position &&
          last.color == normalized.color;
      final continuous = normalized.startSection <= last.endSection + 1;
      if (sameCourse && continuous) {
        merged[merged.length - 1] = last.copyWith(
          endSection: normalized.endSection > last.endSection ? normalized.endSection : last.endSection,
        );
      } else {
        merged.add(normalized);
      }
    }
    return merged;
  }

  List<Course> _coursesForDay(List<Course> courses, int dayOfWeek, int currentWeek) {
    return _mergedCourses(
      courses.where((c) => c.day == dayOfWeek && c.isActiveInWeek(currentWeek)).toList(),
    );
  }

  List<FriendInfo> _applyOrder(List<FriendInfo> friends, List<String> order) {
    if (order.isEmpty) return friends;
    final map = <String, FriendInfo>{};
    for (final f in friends) {
      map[f.friendId] = f;
    }
    final ordered = <FriendInfo>[];
    for (final id in order) {
      if (map.containsKey(id)) {
        ordered.add(map[id]!);
        map.remove(id);
      }
    }
    ordered.addAll(map.values);
    return ordered;
  }

  void _showFriendOrderEditor(List<FriendInfo> currentOrder) {
    final items = List<FriendInfo>.from(currentOrder);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom + MediaQuery.of(ctx).padding.bottom,
              ),
              child: SizedBox(
                height: MediaQuery.of(ctx).size.height * 0.60,
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    Container(
                      width: 36, height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('调整好友顺序', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    const Text('拖动排序，每日页面的好友将按此顺序显示',
                      style: TextStyle(fontSize: 12, color: AppColorTokens.textSecondary)),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ReorderableListView.builder(
                        itemCount: items.length,
                        onReorder: (oldIndex, newIndex) {
                          setSheetState(() {
                            if (newIndex > oldIndex) newIndex--;
                            final item = items.removeAt(oldIndex);
                            items.insert(newIndex, item);
                          });
                        },
                        itemBuilder: (ctx, index) {
                          final friend = items[index];
                          return ListTile(
                            key: ValueKey(friend.friendId),
                            leading: CircleAvatar(
                              backgroundColor: AppColorTokens.accent.withAlpha(28),
                              child: Text(friend.nickname[0],
                                style: const TextStyle(color: AppColorTokens.accent, fontWeight: FontWeight.w700)),
                            ),
                            title: Text(friend.nickname, style: const TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Text(friend.schoolName ?? '', style: const TextStyle(fontSize: 11)),
                            trailing: const Icon(Icons.drag_handle, color: AppColorTokens.textTertiary),
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                ref.read(settingsProvider.notifier).setFriendOrder([]);
                                Navigator.pop(ctx);
                              },
                              child: const Text('恢复默认'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                ref.read(settingsProvider.notifier)
                                    .setFriendOrder(items.map((f) => f.friendId).toList());
                                Navigator.pop(ctx);
                              },
                              child: const Text('保存'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
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
    final timeSlots = scheduleState.timeSlots;
    final friends = friendsState.friends;
    final settings = ref.watch(settingsProvider);
    final friendOrder = settings.friendOrder;
    final showFriendSection = friends.isNotEmpty;

    // Apply saved friend order
    final orderedFriends = showFriendSection
        ? _applyOrder(friends, friendOrder)
        : <FriendInfo>[];

    final dayOfWeek = _dayOfWeek;
    final myCourses = _coursesForDay(scheduleState.courses, dayOfWeek, currentWeek);
    final friendData = showFriendSection
        ? orderedFriends.map((f) {
            final courses =
                _coursesForDay(scheduleState.friendCoursesMap[f.friendId] ?? const [], dayOfWeek, currentWeek);
            return (friend: f, courses: courses);
          }).toList()
        : <({FriendInfo friend, List<Course> courses})>[];

    final allEmpty = myCourses.isEmpty && friendData.every((d) => d.courses.isEmpty);

    return LiquidScaffold(
      appBar: AppBar(
        title: const Text('每日'),
        actions: [
          if (showFriendSection)
            TextButton(
              onPressed: () => _showFriendOrderEditor(orderedFriends),
              child: const Text('调整', style: TextStyle(fontSize: 13)),
            ),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 86),
        child: ImportFab(onPressed: () => context.push('/import')),
      ),
      body: Column(
        children: [
          // Date header (fixed)
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
                    onPressed: _dayOfWeek > 1 ? () => setState(() => _dayOfWeek--) : null,
                    icon: const Icon(Icons.chevron_left_rounded, size: 24),
                    tooltip: '前一天',
                  ),
                  Expanded(
                    child: Center(
                      child: Column(
                        children: [
                          Text(_dayLabel(dayOfWeek), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 2),
                          Text(
                            DateTime.now().weekday == dayOfWeek ? '今天的安排' : '其他日期的课程',
                            style: TextStyle(fontSize: 11, color: isDark ? AppColorTokens.darkTextTertiary : AppColorTokens.textTertiary),
                          ),
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _dayOfWeek < 7 ? () => setState(() => _dayOfWeek++) : null,
                    icon: const Icon(Icons.chevron_right_rounded, size: 24),
                    tooltip: '后一天',
                  ),
                ],
              ),
            ),
          ),
          // Column headers: "我的" + friend names (syncs with body scroll)
          Padding(
            padding: const EdgeInsets.fromLTRB(64, 6, 10, 4),
            child: Row(
              children: [
                SizedBox(
                  width: 79,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColorTokens.primary.withAlpha(28),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: const Text('我的', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColorTokens.primary)),
                    ),
                  ),
                ),
                if (showFriendSection)
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const NeverScrollableScrollPhysics(),
                      controller: _headerNameScrollController,
                      child: Row(
                        children: friendData
                            .map((d) => Container(
                                  width: 79,
                                  padding: const EdgeInsets.symmetric(horizontal: 2),
                                  child: Center(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: AppColorTokens.accent.withAlpha(22),
                                        borderRadius: BorderRadius.circular(11),
                                      ),
                                      child: Text(
                                        '${d.friend.nickname}的',
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColorTokens.accent),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                ))
                            .toList(),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Main body
          Expanded(
            child: scheduleState.isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColorTokens.primary))
                : allEmpty
                    ? Center(
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
                                  width: 70, height: 70,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppColorTokens.primary.withAlpha(isDark ? 55 : 28),
                                    border: Border.all(color: AppColorTokens.primary.withAlpha(70)),
                                  ),
                                  child: const Icon(Icons.event_note_rounded, size: 36, color: AppColorTokens.primary),
                                ),
                                const SizedBox(height: 18),
                                const Text('今天没有课程', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                                const SizedBox(height: 8),
                                const Text('点击右下角导入课表', style: TextStyle(fontSize: 13, color: AppColorTokens.textSecondary)),
                              ],
                            ),
                          ),
                        ),
                      )
                    : _buildScheduleBody(
                        timeSlots: timeSlots,
                        myCourses: myCourses,
                        friendData: friendData,
                        isDark: isDark,
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleBody({
    required List<TimeSlot> timeSlots,
    required List<Course> myCourses,
    required List<({FriendInfo friend, List<Course> courses})> friendData,
    required bool isDark,
  }) {
    final rowHeight = 62.0;
    final labelWidth = 48.0;
    final myColWidth = 82.0;
    final friendColWidth = 82.0;
    final totalFriendWidth = friendData.length * friendColWidth;

    return Stack(
      children: [
        // Vertical scroll for the whole schedule
        SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
          child: SizedBox(
            height: rowHeight * timeSlots.length,
            child: Stack(
              children: [
                // Time labels (fixed left) — show period number + time range
                ...List.generate(timeSlots.length, (rowIdx) {
                  final slot = timeSlots[rowIdx];
                  return Positioned(
                    left: 0,
                    top: rowIdx * rowHeight,
                    width: labelWidth,
                    height: rowHeight,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(slot.label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: isDark ? AppColorTokens.darkTextSecondary : AppColorTokens.textSecondary)),
                        const SizedBox(height: 1),
                        Text(slot.timeRange, style: TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: isDark ? AppColorTokens.darkTextTertiary : AppColorTokens.textTertiary)),
                      ],
                    ),
                  );
                }),
                // Grid backgrounds (full width)
                ...List.generate(timeSlots.length, (rowIdx) {
                  return Positioned(
                    left: labelWidth,
                    top: rowIdx * rowHeight,
                    right: 0,
                    height: rowHeight,
                    child: Container(
                      margin: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: isDark ? AppColorTokens.darkSurfaceGlass : AppColorTokens.surfaceGlass,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? AppColorTokens.darkGlassBorder : AppColorTokens.glassBorder.withAlpha(120),
                          width: 0.5,
                        ),
                      ),
                    ),
                  );
                }),
                // "我的" courses (fixed column)
                for (final course in myCourses)
                  Positioned(
                    left: labelWidth + 2,
                    top: (course.startSection - 1) * rowHeight,
                    width: myColWidth - 4,
                    height: rowHeight * course.duration,
                    child: CourseTile(course: course, height: rowHeight * course.duration - 4, onTap: () {}),
                  ),
                // Friend courses (scrollable horizontally)
                Positioned(
                  left: labelWidth + myColWidth,
                  top: 0,
                  bottom: 0,
                  right: 0,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    controller: _friendScrollController,
                    child: SizedBox(
                      width: totalFriendWidth > 0 ? totalFriendWidth : 1,
                      child: Stack(
                        children: [
                          for (var i = 0; i < friendData.length; i++)
                            for (final course in friendData[i].courses)
                              Positioned(
                                left: i * friendColWidth + 2,
                                top: (course.startSection - 1) * rowHeight,
                                width: friendColWidth - 4,
                                height: rowHeight * course.duration,
                                child: CourseTile(course: course, height: rowHeight * course.duration - 4, onTap: () {}),
                              ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Bottom padding overlay to avoid FAB overlap
        Positioned(
          left: 0, right: 0, bottom: 0,
          height: 100,
          child: IgnorePointer(child: Container()),
        ),
      ],
    );
  }
}
