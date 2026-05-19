import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/course.dart';
import 'schedule_widget_snapshot.dart';

class WidgetSyncService {
  WidgetSyncService._();

  static final WidgetSyncService instance = WidgetSyncService._();
  static const MethodChannel _channel = MethodChannel(
    'heybuddy_schedule/widget',
  );
  static const _snapshotKey = 'widget_schedule_snapshot_v1';

  Future<void> sync({
    required CourseTable? currentTable,
    required List<Course> courses,
  }) async {
    if (kIsWeb) return;

    final snapshot = buildScheduleWidgetSnapshot(
      currentTable: currentTable,
      courses: courses,
    );

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_snapshotKey, jsonEncode(snapshot));
    } catch (_) {}

    if (defaultTargetPlatform != TargetPlatform.android) return;

    try {
      await _channel.invokeMethod('refreshWidgets');
    } catch (_) {
      try {
        await _channel.invokeMethod('updateWidgetData', snapshot);
      } catch (_) {}
    }
  }
}
