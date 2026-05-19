import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/constants.dart';
import '../models/course.dart';
import '../services/api_service.dart';
import '../services/local_course_store.dart';
import '../services/widget_sync_service.dart';

int estimateCurrentWeek([DateTime? date, CourseTable? table]) {
  final now = date ?? DateTime.now();

  // Priority 1: use table's startDate and totalWeeks
  if (table?.startDateTime != null) {
    final start = table!.startDateTime!;
    final diff = now.difference(start).inDays;
    final week = (diff / 7).floor() + 1;
    return week.clamp(1, table.totalWeeks);
  }

  // Priority 2: hardcoded fallback
  final semesterStart = DateTime(now.year, 2, 17);
  final diff = now.difference(semesterStart).inDays;
  return ((diff / 7).floor() + 1).clamp(1, 20);
}

class ScheduleState {
  final List<Course> courses;
  final List<Course> friendCourses;
  final Map<String, List<Course>> friendCoursesMap;
  final Map<String, List<TimeSlot>> friendTimeSlotsMap;
  final List<CourseTable> tables;
  final String currentTableId;
  final bool isLoading;
  final String? error;

  const ScheduleState({
    this.courses = const [],
    this.friendCourses = const [],
    this.friendCoursesMap = const {},
    this.friendTimeSlotsMap = const {},
    this.tables = const [],
    this.currentTableId = Course.defaultTableId,
    this.isLoading = false,
    this.error,
  });

  CourseTable? get currentTable {
    try {
      return tables.firstWhere((t) => t.id == currentTableId);
    } catch (_) {
      return null;
    }
  }

  ScheduleState copyWith({
    List<Course>? courses,
    List<Course>? friendCourses,
    Map<String, List<Course>>? friendCoursesMap,
    Map<String, List<TimeSlot>>? friendTimeSlotsMap,
    List<CourseTable>? tables,
    String? currentTableId,
    bool? isLoading,
    String? error,
  }) {
    return ScheduleState(
      courses: courses ?? this.courses,
      friendCourses: friendCourses ?? this.friendCourses,
      friendCoursesMap: friendCoursesMap ?? this.friendCoursesMap,
      friendTimeSlotsMap: friendTimeSlotsMap ?? this.friendTimeSlotsMap,
      tables: tables ?? this.tables,
      currentTableId: currentTableId ?? this.currentTableId,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  List<Course> coursesForDay(int day) {
    return courses.where((c) => c.day == day).toList()
      ..sort((a, b) => a.startSection.compareTo(b.startSection));
  }

  List<Course> coursesForSlot(int day, int startSection, int endSection) {
    return courses
        .where(
          (c) =>
              c.day == day &&
              c.startSection <= endSection &&
              c.endSection >= startSection,
        )
        .toList();
  }

  List<TimeSlot> get timeSlots =>
      AppConstants.resolveTimeSlots(currentTable?.timeSlots);

  List<TimeSlot> getFriendTimeSlots(String friendId) {
    final slots = friendTimeSlotsMap[friendId];
    if (slots != null && slots.isNotEmpty) return slots;
    return timeSlots;
  }
}

enum CourseImportMode { overwriteCurrent, createNewTable }

class ImportCoursesResult {
  final String message;
  final String targetTableId;
  final bool createdNewTable;
  final bool needsStartDatePrompt;

  const ImportCoursesResult({
    required this.message,
    required this.targetTableId,
    required this.createdNewTable,
    required this.needsStartDatePrompt,
  });

  bool get isSuccess => !message.contains('失败');
}

class ScheduleNotifier extends StateNotifier<ScheduleState> {
  final ApiService _api;
  final LocalCourseStore _localStore;
  final WidgetSyncService _widgetSyncService;

  ScheduleNotifier(
    this._api,
    this._localStore, {
    WidgetSyncService? widgetSyncService,
  }) : _widgetSyncService = widgetSyncService ?? WidgetSyncService.instance,
       super(const ScheduleState());

  Future<void> init() async {
    final tables = await _localStore.getTables();
    final activeId = await _localStore.getActiveTableId();
    state = state.copyWith(tables: tables, currentTableId: activeId);
    await loadMyCourses();
    _syncTimeSlotsToServer();
  }

  void _syncTimeSlotsToServer() {
    final table = state.currentTable;
    if (table == null) return;
    final timeSlots = table.timeSlots;
    if (timeSlots.isEmpty || _sameAsDefault(timeSlots)) return;
    _api.put('/user/profile', data: {
      'timeSlotsJson': jsonEncode(timeSlots.map((s) => s.toJson()).toList()),
    });
  }

  bool _sameAsDefault(List<TimeSlot> slots) {
    final def = AppConstants.defaultTimeSlots;
    if (slots.length != def.length) return false;
    for (var i = 0; i < slots.length; i++) {
      if (slots[i].period != def[i].period ||
          slots[i].start != def[i].start ||
          slots[i].end != def[i].end) return false;
    }
    return true;
  }

  Future<void> loadMyCourses() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final localCourses = await _localStore.getCourses(
        tableId: state.currentTableId,
      );
      state = state.copyWith(
        courses: localCourses,
        isLoading: false,
        error: null,
      );
      await _syncWidget();
    } catch (_) {
      state = state.copyWith(isLoading: false, error: '本地课表读取失败');
    }
  }

  Future<void> _syncWidget() {
    return _widgetSyncService.sync(
      currentTable: state.currentTable,
      courses: state.courses,
    );
  }

  void _setFriendCourses(String friendId, List<Course> courses) {
    final map = Map<String, List<Course>>.from(state.friendCoursesMap);
    map[friendId] = courses;
    state = state.copyWith(friendCourses: courses, friendCoursesMap: map);
  }

  Future<void> hydrateCachedFriendCourses(String friendId) async {
    final cached = await _localStore.getCachedFriendCourses(
      friendId,
      _currentSemester,
    );
    if (cached.isNotEmpty) {
      _setFriendCourses(friendId, cached);
    }
  }

  Future<bool> refreshFriendCourses(String friendId) async {
    try {
      final res = await _api.get(
        '/friends/$friendId/courses',
        query: {'semester': _currentSemester},
      );
      if (res.isSuccess && res.data != null) {
        final courses = (res.data as List)
            .map((e) => Course.fromJson(e as Map<String, dynamic>))
            .map(
              (course) => course.copyWith(
                semester: _currentSemester,
                tableId: state.currentTableId,
              ),
            )
            .toList();
        _setFriendCourses(friendId, courses);

        // Parse friend's time slots from API response
        if (res.timeSlotsJson != null && res.timeSlotsJson!.isNotEmpty) {
          final parsed = TimeSlot.parseList(res.timeSlotsJson!);
          if (parsed.isNotEmpty) {
            final map = Map<String, List<TimeSlot>>.from(state.friendTimeSlotsMap);
            map[friendId] = AppConstants.resolveTimeSlots(parsed);
            state = state.copyWith(friendTimeSlotsMap: map);
          }
        }

        await _localStore.saveCachedFriendCourses(
          friendId,
          _currentSemester,
          courses,
        );
        state = state.copyWith(error: null);
        return true;
      }
      state = state.copyWith(error: res.msg);
      return false;
    } catch (_) {
      state = state.copyWith(error: '好友课表加载失败');
      return false;
    }
  }

  Future<void> loadFriendCourses(String friendId) async {
    await hydrateCachedFriendCourses(friendId);
    await refreshFriendCourses(friendId);
  }

  // ---- Table management ----

  Future<void> switchTable(String tableId) async {
    await _localStore.setActiveTableId(tableId);
    state = state.copyWith(currentTableId: tableId);
    await loadMyCourses();
  }

  Future<void> createTable(String name) async {
    final ct = await _localStore.createTable(name);
    final tables = await _localStore.getTables();
    state = state.copyWith(tables: tables);
    await switchTable(ct.id);
  }

  Future<void> deleteTable(String id) async {
    await _localStore.deleteTable(id);
    final tables = await _localStore.getTables();
    final activeId = await _localStore.getActiveTableId();
    state = state.copyWith(tables: tables, currentTableId: activeId);
    await loadMyCourses();
  }

  Future<void> renameTable(String id, String name) async {
    await _localStore.renameTable(id, name);
    final tables = await _localStore.getTables();
    state = state.copyWith(tables: tables);
    await _syncWidget();
  }

  Future<void> updateTable(String id, {
    String? startDate,
    bool clearStartDate = false,
    int? totalWeeks,
    List<TimeSlot>? timeSlots,
  }) async {
    await _localStore.updateTable(
      id,
      startDate: startDate,
      clearStartDate: clearStartDate,
      totalWeeks: totalWeeks,
      timeSlots: timeSlots,
    );
    final tables = await _localStore.getTables();
    state = state.copyWith(tables: tables);
    await _syncWidget();
  }

  // ---- Courses ----

  String get _currentSemester =>
      state.currentTable?.semester ?? AppConstants.defaultSemester;

  Future<List<Course>> fetchRemoteCoursesForCurrentSemester() async {
    final res = await _api.get(
      '/courses',
      query: {'semester': _currentSemester},
    );
    if (!res.isSuccess || res.data == null) return const [];
    return (res.data as List)
        .map((e) => Course.fromJson(e as Map<String, dynamic>))
        .map(
          (course) => course.copyWith(
            tableId: state.currentTableId,
            semester: _currentSemester,
          ),
        )
        .toList();
  }

  Future<String> restoreCurrentSemesterFromCloud({
    List<Course>? prefetchedCourses,
  }) async {
    final courses = prefetchedCourses ?? await fetchRemoteCoursesForCurrentSemester();
    if (courses.isEmpty) {
      return '云端当前学期还没有可恢复的课表';
    }
    await _localStore.replaceCourses(courses, tableId: state.currentTableId);
    await loadMyCourses();
    return '已从云端恢复 ${courses.length} 门当前学期课程';
  }

  Future<ImportCoursesResult> importCourses(
    List<Course> courses, {
    CourseImportMode mode = CourseImportMode.overwriteCurrent,
    String? newTableName,
    String? startDate,
    int? totalWeeks,
    List<TimeSlot>? timeSlots,
  }) async {
    var targetTableId = state.currentTableId;
    var targetSemester = _currentSemester;
    var createdNewTable = false;
    if (courses.isEmpty) {
      return ImportCoursesResult(
        message: '课程数据为空',
        targetTableId: targetTableId,
        createdNewTable: false,
        needsStartDatePrompt: false,
      );
    }

    if (mode == CourseImportMode.createNewTable) {
      final created = await _localStore.createTable(
        (newTableName == null || newTableName.trim().isEmpty)
            ? '导入课表'
            : newTableName.trim(),
        semester: targetSemester,
      );
      await _localStore.setActiveTableId(created.id);
      targetTableId = created.id;
      targetSemester = created.semester;
      createdNewTable = true;
    }

    final scopedCourses = courses
        .map(
          (course) => course.copyWith(
            tableId: targetTableId,
            semester: targetSemester,
          ),
        )
        .toList();

    await _localStore.replaceCourses(scopedCourses, tableId: targetTableId);
    if (startDate != null || totalWeeks != null || timeSlots != null) {
      await _localStore.updateTable(
        targetTableId,
        startDate: startDate,
        totalWeeks: totalWeeks,
        timeSlots: timeSlots,
      );
    }

    final tables = await _localStore.getTables();
    state = state.copyWith(tables: tables, currentTableId: targetTableId);
    await loadMyCourses();

    CourseTable? targetTable;
    try {
      targetTable = tables.firstWhere((table) => table.id == targetTableId);
    } catch (_) {
      targetTable = null;
    }
    final needsStartDatePrompt = targetTable?.startDateTime == null;

    try {
      final res = await _api.post(
        '/courses/batch',
        data: {'courses': scopedCourses.map((c) => c.toApiJson()).toList()},
      );
      if (res.isSuccess) {
        return ImportCoursesResult(
          message: createdNewTable
              ? '已新建课表并导入 ${scopedCourses.length} 门课程'
              : res.msg,
          targetTableId: targetTableId,
          createdNewTable: createdNewTable,
          needsStartDatePrompt: needsStartDatePrompt,
        );
      }
      return ImportCoursesResult(
        message: '已保存到本地，同步失败：${res.msg}',
        targetTableId: targetTableId,
        createdNewTable: createdNewTable,
        needsStartDatePrompt: needsStartDatePrompt,
      );
    } catch (_) {
      return ImportCoursesResult(
        message: '已保存到本地，同步失败',
        targetTableId: targetTableId,
        createdNewTable: createdNewTable,
        needsStartDatePrompt: needsStartDatePrompt,
      );
    }
  }

  Future<void> saveCourse(Course course) async {
    await _localStore.upsertCourse(course);
    await loadMyCourses();
    try {
      await _api.post('/courses', data: course.toApiJson());
    } catch (_) {}
  }

  Future<void> removeCourse(String courseId) async {
    await _localStore.deleteSingleCourse(courseId);
    await loadMyCourses();
    try {
      await _api.delete('/courses/$courseId');
    } catch (_) {}
  }
}

final scheduleProvider = StateNotifierProvider<ScheduleNotifier, ScheduleState>(
  (ref) {
    return ScheduleNotifier(
      ref.read(apiServiceProvider),
      LocalCourseStore.instance,
    );
  },
);
