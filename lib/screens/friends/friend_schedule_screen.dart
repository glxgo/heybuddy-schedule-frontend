import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/theme.dart';
import '../../providers/schedule_provider.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/liquid_scaffold.dart';
import '../../widgets/weekly_grid.dart';

class FriendScheduleScreen extends ConsumerStatefulWidget {
  final String friendId;
  final String friendName;

  const FriendScheduleScreen({
    super.key,
    required this.friendId,
    required this.friendName,
  });

  @override
  ConsumerState<FriendScheduleScreen> createState() =>
      _FriendScheduleScreenState();
}

class _FriendScheduleScreenState extends ConsumerState<FriendScheduleScreen> {
  int _currentWeek = 1;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      final notifier = ref.read(scheduleProvider.notifier);
      if (ref.read(scheduleProvider).currentTable == null) {
        await notifier.init();
      }
      final table = ref.read(scheduleProvider).currentTable;
      _currentWeek = estimateCurrentWeek(null, table);
      await notifier.hydrateCachedFriendCourses(widget.friendId);
      final cached = ref.read(scheduleProvider).friendCoursesMap[widget.friendId] ?? const [];
      if (mounted && cached.isNotEmpty) {
        setState(() => _loading = false);
      }
      await notifier.refreshFriendCourses(widget.friendId);
      if (mounted) {
        setState(() => _loading = false);
      }
    });
  }

  void _changeWeek(int delta) {
    final maxWeeks = ref.read(scheduleProvider).currentTable?.totalWeeks ?? 20;
    setState(() {
      _currentWeek = (_currentWeek + delta).clamp(1, maxWeeks);
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheduleState = ref.watch(scheduleProvider);
    final friendCourses = scheduleState.friendCoursesMap[widget.friendId] ?? const [];

    return LiquidScaffold(
      appBar: AppBar(title: Text('${widget.friendName}的课表')),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColorTokens.primary),
            )
          : friendCourses.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: GlassCard(
                  borderRadius: 28,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 34,
                  ),
                  elevation: 1.3,
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.calendar_view_week_rounded,
                        size: 42,
                        color: AppColorTokens.primary,
                      ),
                      SizedBox(height: 16),
                      Text(
                        '好友暂未导入课表',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        '等对方同步课表后，这里就会显示啦',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColorTokens.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          : GestureDetector(
              behavior: HitTestBehavior.translucent,
              onHorizontalDragEnd: (details) {
                final velocity = details.primaryVelocity ?? 0;
                if (velocity <= -120) {
                  _changeWeek(1);
                } else if (velocity >= 120) {
                  _changeWeek(-1);
                }
              },
              child: WeeklyGrid(
                courses: friendCourses,
                currentWeek: _currentWeek,
                onWeekChanged: (w) {
                  final maxWeeks =
                      ref.read(scheduleProvider).currentTable?.totalWeeks ?? 20;
                  setState(() => _currentWeek = w.clamp(1, maxWeeks));
                },
              ),
            ),
    );
  }
}
