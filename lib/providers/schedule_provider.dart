import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/constants.dart';
import '../models/course.dart';
import '../services/api_service.dart';
import '../services/local_course_store.dart';

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
  final List<CourseTable> tables;
  final String currentTableId;
  final bool isLoading;
  final String? error;

  const ScheduleState({
    this.courses = const [],
    this.friendCourses = const [],
    this.friendCoursesMap = const {},
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
    List<CourseTable>? tables,
    String? currentTableId,
    bool? isLoading,
    String? error,
  }) {
    return ScheduleState(
      courses: courses ?? this.courses,
      friendCourses: friendCourses ?? this.friendCourses,
      friendCoursesMap: friendCoursesMap ?? this.friendCoursesMap,
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
}

enum CourseImportMode { overwriteCurrent, createNewTable }

class ScheduleNotifier extends StateNotifier<ScheduleState> {
  final ApiService _api;
  final LocalCourseStore _localStore;

  ScheduleNotifier(this._api, this._localStore) : super(const ScheduleState());

  Future<void> init() async {
    final tables = await _localStore.getTables();
    final activeId = await _localStore.getActiveTableId();
    state = state.copyWith(tables: tables, currentTableId: activeId);
    await loadMyCourses();
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
    } catch (_) {
      state = state.copyWith(isLoading: false, error: '本地课表读取失败');
    }
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

  Future<void> refreshFriendCourses(String friendId) async {
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
        await _localStore.saveCachedFriendCourses(
          friendId,
          _currentSemester,
          courses,
        );
      }
    } catch (_) {
      state = state.copyWith(error: '好友课表加载失败');
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
  }

  Future<void> updateTable(String id, {
    String? startDate,
    bool clearStartDate = false,
    int? totalWeeks,
  }) async {
    await _localStore.updateTable(
      id,
      startDate: startDate,
      clearStartDate: clearStartDate,
      totalWeeks: totalWeeks,
    );
    final tables = await _localStore.getTables();
    state = state.copyWith(tables: tables);
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

  Future<String> importCourses(
    List<Course> courses, {
    CourseImportMode mode = CourseImportMode.overwriteCurrent,
    String? newTableName,
  }) async {
    var targetTableId = state.currentTableId;
    var targetSemester = _currentSemester;
    if (courses.isEmpty) {
      return '课程数据为空';
    }

    if (mode == CourseImportMode.createNewTable) {
      final created = await _localStore.createTable(
        (newTableName == null || newTableName.trim().isEmpty)
            ? '导入课表'
            : newTableName.trim(),
        semester: targetSemester,
      );
      await _localStore.setActiveTableId(created.id);
      final tables = await _localStore.getTables();
      state = state.copyWith(tables: tables, currentTableId: created.id);
      targetTableId = created.id;
      targetSemester = created.semester;
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
    await loadMyCourses();

    try {
      final res = await _api.post(
        '/courses/batch',
        data: {'courses': scopedCourses.map((c) => c.toApiJson()).toList()},
      );
      if (res.isSuccess) {
        if (mode == CourseImportMode.createNewTable) {
          return '已新建课表并导入 ${scopedCourses.length} 门课程';
        }
        return res.msg;
      }
      return '已保存到本地，同步失败：${res.msg}';
    } catch (_) {
      return '已保存到本地，同步失败';
    }
  }

  Future<String> addCourse(Course course) async {
    final res = await _api.post('/courses', data: course.toApiJson());
    if (res.isSuccess) await loadMyCourses();
    return res.msg;
  }

  Future<String> deleteCourse(String courseId) async {
    final res = await _api.delete('/courses/$courseId');
    if (res.isSuccess) await loadMyCourses();
    return res.msg;
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
