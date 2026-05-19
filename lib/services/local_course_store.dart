import 'dart:convert';

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../config/constants.dart';
import '../models/course.dart';

class LocalCourseStore {
  static final LocalCourseStore instance = LocalCourseStore._();
  static const _dbName = 'heybuddy_schedule.db';
  static const _tableName = 'courses';
  static const _tablesTableName = 'course_tables';
  static const _prefsKey = 'local_courses';
  static const _friendCacheKey = 'friend_course_cache';
  static const _activeTableKey = 'active_table_id';
  static const _friendCacheTableName = 'friend_course_cache';

  Database? _database;

  LocalCourseStore._();

  bool get _usePrefsFallback {
    return kIsWeb ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.linux;
  }

  // ---- Friend course cache ----

  Future<List<Course>> getCachedFriendCourses(String friendId, String semester) async {
    if (_usePrefsFallback) {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_friendCacheKey);
      if (raw == null || raw.isEmpty) return const [];
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final cacheKey = '$friendId::$semester';
      final list = decoded[cacheKey] as List<dynamic>?;
      if (list == null) return const [];
      return list
          .map((item) => Course.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    final db = await _getDatabase();
    final rows = await db.query(
      _friendCacheTableName,
      where: 'friendId = ? AND semester = ?',
      whereArgs: [friendId, semester],
      limit: 1,
    );
    if (rows.isEmpty) return const [];
    final rawCourses = rows.first['coursesJson'] as String?;
    if (rawCourses == null || rawCourses.isEmpty) return const [];
    final decoded = jsonDecode(rawCourses) as List<dynamic>;
    return decoded
        .map((item) => Course.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveCachedFriendCourses(
    String friendId,
    String semester,
    List<Course> courses,
  ) async {
    if (_usePrefsFallback) {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_friendCacheKey);
      final decoded = raw == null || raw.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(raw) as Map<String, dynamic>;
      decoded['$friendId::$semester'] =
          courses.map((course) => course.toJson()).toList();
      await prefs.setString(_friendCacheKey, jsonEncode(decoded));
      return;
    }

    final db = await _getDatabase();
    await db.insert(
      _friendCacheTableName,
      {
        'friendId': friendId,
        'semester': semester,
        'coursesJson': jsonEncode(courses.map((course) => course.toJson()).toList()),
        'updatedAt': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ---- Single course CRUD ----

  Future<void> upsertCourse(Course course) async {
    if (_usePrefsFallback) {
      final all = await _getAllCoursesFromPrefs();
      final idx = all.indexWhere((c) => c.id == course.id);
      if (idx >= 0) {
        all[idx] = course;
      } else {
        all.add(course);
      }
      return _saveCoursesToPrefs(all);
    }
    final db = await _getDatabase();
    await db.insert(
      _tableName,
      course.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteSingleCourse(String courseId) async {
    if (_usePrefsFallback) {
      final all = await _getAllCoursesFromPrefs();
      all.removeWhere((c) => c.id == courseId);
      return _saveCoursesToPrefs(all);
    }
    final db = await _getDatabase();
    await db.delete(_tableName, where: 'id = ?', whereArgs: [courseId]);
  }

  // ---- Courses ----

  Future<List<Course>> getCourses({String? tableId}) async {
    if (_usePrefsFallback) return _getCoursesFromPrefs(tableId: tableId);

    final db = await _getDatabase();
    final tid = tableId ?? await getActiveTableId();
    final rows = await db.query(
      _tableName,
      where: 'tableId = ?',
      whereArgs: [tid],
      orderBy: 'day, startSection',
    );
    return rows
        .map((row) => Course.fromJson(Map<String, dynamic>.from(row)))
        .toList();
  }

  Future<void> replaceCourses(List<Course> courses, {String? tableId}) async {
    final tid = tableId ?? Course.defaultTableId;
    if (_usePrefsFallback) {
      final existing = await _getAllCoursesFromPrefs();
      final kept = existing.where((course) => course.tableId != tid).toList();
      final scoped = courses.map((course) => course.copyWith(tableId: tid));
      return _saveCoursesToPrefs([...kept, ...scoped]);
    }

    final db = await _getDatabase();
    await db.transaction((txn) async {
      await txn.delete(_tableName, where: 'tableId = ?', whereArgs: [tid]);
      for (final course in courses) {
        await txn.insert(
          _tableName,
          course.copyWith(tableId: tid).toJson(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  // ---- Tables ----

  Future<List<CourseTable>> getTables() async {
    final db = await _getDatabase();
    final rows = await db.query(_tablesTableName, orderBy: 'name');
    if (rows.isEmpty) {
      await _ensureDefaultTable();
      return getTables();
    }
    return rows
        .map((r) => CourseTable.fromJson(Map<String, dynamic>.from(r)))
        .toList();
  }

  Future<void> _ensureDefaultTable() async {
    final db = await _getDatabase();
    final count =
        Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM $_tablesTableName'),
        ) ??
        0;
    if (count == 0) {
      await db.insert(_tablesTableName, {
        'id': Course.defaultTableId,
        'name': '我的课表',
        'color': '#5B6AF0',
        'semester': '2025-2026-2',
      });
    }
  }

  Future<CourseTable> createTable(
    String name, {
    String color = '#5B6AF0',
    String semester = '2025-2026-2',
    List<TimeSlot>? timeSlots,
  }) async {
    final db = await _getDatabase();
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final ct = CourseTable(
      id: id,
      name: name,
      color: color,
      semester: semester,
      timeSlots: timeSlots ?? AppConstants.defaultTimeSlots,
    );
    await db.insert(_tablesTableName, ct.toJson());
    return ct;
  }

  Future<void> updateTable(String id, {
    String? startDate,
    bool clearStartDate = false,
    int? totalWeeks,
    List<TimeSlot>? timeSlots,
  }) async {
    final db = await _getDatabase();
    final updates = <String, dynamic>{};
    if (clearStartDate) {
      updates['start_date'] = null;
    } else if (startDate != null) {
      updates['start_date'] = startDate;
    }
    if (totalWeeks != null) updates['total_weeks'] = totalWeeks;
    if (timeSlots != null) {
      updates['time_slots_json'] = jsonEncode(
        timeSlots.map((slot) => slot.toJson()).toList(),
      );
    }
    if (updates.isNotEmpty) {
      await db.update(
        _tablesTableName,
        updates,
        where: 'id = ?',
        whereArgs: [id],
      );
    }
  }

  Future<void> deleteTable(String id) async {
    if (id == Course.defaultTableId) return;
    final db = await _getDatabase();
    await db.transaction((txn) async {
      await txn.delete(_tablesTableName, where: 'id = ?', whereArgs: [id]);
      await txn.delete(_tableName, where: 'tableId = ?', whereArgs: [id]);
    });
  }

  Future<void> renameTable(String id, String name) async {
    final db = await _getDatabase();
    await db.update(
      _tablesTableName,
      {'name': name},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<String> getActiveTableId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_activeTableKey) ?? Course.defaultTableId;
  }

  Future<void> setActiveTableId(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activeTableKey, id);
  }

  // ---- DB Setup ----

  Future<Database> _getDatabase() async {
    final current = _database;
    if (current != null) return current;

    final dir = await getApplicationDocumentsDirectory();
    final dbPath = path.join(dir.path, _dbName);
    _database = await openDatabase(
      dbPath,
      version: 6,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_tableName (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            teacher TEXT NOT NULL,
            position TEXT NOT NULL,
            day INTEGER NOT NULL,
            startSection INTEGER NOT NULL,
            endSection INTEGER NOT NULL,
            weeks TEXT NOT NULL,
            color TEXT NOT NULL,
            semester TEXT NOT NULL,
            tableId TEXT NOT NULL DEFAULT '${Course.defaultTableId}',
            isCustomTime INTEGER NOT NULL DEFAULT 0,
            customStartTime TEXT,
            customEndTime TEXT,
            remark TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE $_tablesTableName (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            color TEXT NOT NULL,
            semester TEXT NOT NULL,
            start_date TEXT,
            total_weeks INTEGER NOT NULL DEFAULT ${CourseTable.defaultTotalWeeks},
            time_slots_json TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE $_friendCacheTableName (
            friendId TEXT NOT NULL,
            semester TEXT NOT NULL,
            coursesJson TEXT NOT NULL,
            updatedAt TEXT NOT NULL,
            PRIMARY KEY (friendId, semester)
          )
        ''');
        await db.insert(_tablesTableName, {
          'id': Course.defaultTableId,
          'name': '我的课表',
          'color': '#5B6AF0',
          'semester': '2025-2026-2',
        });
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            'ALTER TABLE $_tableName RENAME COLUMN location TO position',
          );
          await db.execute(
            'ALTER TABLE $_tableName RENAME COLUMN dayOfWeek TO day',
          );
          await db.execute(
            'ALTER TABLE $_tableName RENAME COLUMN startPeriod TO startSection',
          );
          await db.execute(
            'ALTER TABLE $_tableName RENAME COLUMN endPeriod TO endSection',
          );
          await db.execute(
            'ALTER TABLE $_tableName ADD COLUMN isCustomTime INTEGER NOT NULL DEFAULT 0',
          );
          await db.execute(
            'ALTER TABLE $_tableName ADD COLUMN customStartTime TEXT',
          );
          await db.execute(
            'ALTER TABLE $_tableName ADD COLUMN customEndTime TEXT',
          );
          await db.execute('ALTER TABLE $_tableName ADD COLUMN remark TEXT');
        }
        if (oldVersion < 3) {
          await db.execute(
            'ALTER TABLE $_tableName ADD COLUMN tableId TEXT NOT NULL DEFAULT \'${Course.defaultTableId}\'',
          );
          await db.execute('''
            CREATE TABLE IF NOT EXISTS $_tablesTableName (
              id TEXT PRIMARY KEY,
              name TEXT NOT NULL,
              color TEXT NOT NULL,
              semester TEXT NOT NULL
            )
          ''');
          final count =
              Sqflite.firstIntValue(
                await db.rawQuery('SELECT COUNT(*) FROM $_tablesTableName'),
              ) ??
              0;
          if (count == 0) {
            await db.insert(_tablesTableName, {
              'id': Course.defaultTableId,
              'name': '我的课表',
              'color': '#5B6AF0',
              'semester': '2025-2026-2',
            });
          }
        }
        if (oldVersion < 4) {
          await db.execute(
            'ALTER TABLE $_tablesTableName ADD COLUMN start_date TEXT',
          );
          await db.execute(
            'ALTER TABLE $_tablesTableName ADD COLUMN total_weeks INTEGER NOT NULL DEFAULT ${CourseTable.defaultTotalWeeks}',
          );
        }
        if (oldVersion < 5) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS $_friendCacheTableName (
              friendId TEXT NOT NULL,
              semester TEXT NOT NULL,
              coursesJson TEXT NOT NULL,
              updatedAt TEXT NOT NULL,
              PRIMARY KEY (friendId, semester)
            )
          ''');
        }
        if (oldVersion < 6) {
          await db.execute(
            'ALTER TABLE $_tablesTableName ADD COLUMN time_slots_json TEXT',
          );
        }
      },
    );
    return _database!;
  }

  // ---- Prefs fallback (web/desktop) ----

  Future<List<Course>> _getAllCoursesFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) return [];

    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((item) => Course.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<Course>> _getCoursesFromPrefs({String? tableId}) async {
    final courses = await _getAllCoursesFromPrefs();
    final tid = tableId ?? await getActiveTableId();
    return courses.where((c) => c.tableId == tid).toList();
  }

  Future<void> _saveCoursesToPrefs(List<Course> courses) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefsKey,
      jsonEncode(courses.map((course) => course.toJson()).toList()),
    );
  }
}
