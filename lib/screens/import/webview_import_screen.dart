import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../config/constants.dart';
import '../../config/theme.dart';
import '../../models/course.dart';
import '../../providers/schedule_provider.dart';
import '../../services/adapter_service.dart';
import '../../widgets/import_target_sheet.dart';
import '../../widgets/liquid_scaffold.dart';
import 'import_start_date_helper.dart';

class WebViewImportScreen extends ConsumerStatefulWidget {
  final String schoolName;
  final String systemUrl;
  final String systemType;
  final String schoolId;

  const WebViewImportScreen({
    super.key,
    required this.schoolName,
    required this.systemUrl,
    required this.systemType,
    this.schoolId = '',
  });

  @override
  ConsumerState<WebViewImportScreen> createState() => _WebViewImportScreenState();
}

class _WebViewImportScreenState extends ConsumerState<WebViewImportScreen> {
  final AdapterService _adapterService = AdapterService();
  late final WebViewController _controller;
  late final Widget _webViewChild;

  bool _hasScheduleHtml = false;
  bool _importing = false;
  Completer<List<Map<String, dynamic>>>? _adapterCompleter;
  final List<String> _debugLogs = [];
  AdapterInfo? _adapter;
  String? _adapterJs;
  List<Map<String, dynamic>> _pendingAdapterCourses = const [];
  Map<String, dynamic>? _pendingCourseConfig;
  List<Map<String, dynamic>> _pendingPresetTimeSlots = const [];

  static const _bridgeShim = r'''
window._androidPromiseResolvers = {};
window._androidPromiseRejectors = {};
window._resolveAndroidPromise = function(promiseId, result) {
  if (window._androidPromiseResolvers[promiseId]) {
    window._androidPromiseResolvers[promiseId](result);
    delete window._androidPromiseResolvers[promiseId];
    delete window._androidPromiseRejectors[promiseId];
  }
};
window._rejectAndroidPromise = function(promiseId, error) {
  if (window._androidPromiseRejectors[promiseId]) {
    window._androidPromiseRejectors[promiseId](new Error(error));
    delete window._androidPromiseResolvers[promiseId];
    delete window._androidPromiseRejectors[promiseId];
  }
};
window.AndroidBridge = {
  showToast: function(msg) {
    FlutterBridge.postMessage(JSON.stringify({type:'debug',msg:'[Toast] '+msg}));
  },
  showAlert: function(title, content, confirmText, promiseId) {
    FlutterBridge.postMessage(JSON.stringify({
      type:'showAlert',
      title:title || '',
      content:content || '',
      confirmText:confirmText || '确定',
      promiseId:promiseId
    }));
  },
  showPrompt: function(title, tip, defaultText, validator, promiseId) {
    FlutterBridge.postMessage(JSON.stringify({
      type:'showPrompt',
      title:title || '',
      tip:tip || '',
      defaultText:defaultText || '',
      validator:validator || '',
      promiseId:promiseId
    }));
  },
  showSingleSelection: function(title, itemsJson, defaultIndex, promiseId) {
    FlutterBridge.postMessage(JSON.stringify({
      type:'showSingleSelection',
      title:title || '',
      itemsJson:itemsJson || '[]',
      defaultIndex:defaultIndex,
      promiseId:promiseId
    }));
  },
  saveImportedCourses: function(coursesJson, promiseId) {
    FlutterBridge.postMessage(JSON.stringify({
      type:'saveImportedCourses',
      coursesJson:coursesJson || '[]',
      promiseId:promiseId
    }));
  },
  saveCourseConfig: function(configJson, promiseId) {
    FlutterBridge.postMessage(JSON.stringify({
      type:'saveCourseConfig',
      configJson:configJson || '{}',
      promiseId:promiseId
    }));
  },
  savePresetTimeSlots: function(timeSlotsJson, promiseId) {
    FlutterBridge.postMessage(JSON.stringify({
      type:'savePresetTimeSlots',
      timeSlotsJson:timeSlotsJson || '[]',
      promiseId:promiseId
    }));
  },
  notifyTaskCompletion: function() {
    FlutterBridge.postMessage(JSON.stringify({type:'taskComplete'}));
  }
};
window.AndroidBridgePromise = {
  showAlert: function(title, content, confirmText) {
    return new Promise(function(resolve, reject) {
      var promiseId = 'alert_' + Date.now() + Math.random().toString(36).substring(2);
      window._androidPromiseResolvers[promiseId] = resolve;
      window._androidPromiseRejectors[promiseId] = reject;
      AndroidBridge.showAlert(title, content, confirmText, promiseId);
    });
  },
  showPrompt: function(title, tip, defaultText, validatorJsFunction) {
    return new Promise(function(resolve, reject) {
      var promiseId = 'prompt_' + Date.now() + Math.random().toString(36).substring(2);
      window._androidPromiseResolvers[promiseId] = resolve;
      window._androidPromiseRejectors[promiseId] = reject;
      AndroidBridge.showPrompt(title, tip, defaultText, validatorJsFunction, promiseId);
    });
  },
  showSingleSelection: function(title, itemsJsonString, defaultSelectedIndex) {
    return new Promise(function(resolve, reject) {
      var promiseId = 'singleSelect_' + Date.now() + Math.random().toString(36).substring(2);
      window._androidPromiseResolvers[promiseId] = resolve;
      window._androidPromiseRejectors[promiseId] = reject;
      AndroidBridge.showSingleSelection(title, itemsJsonString, defaultSelectedIndex, promiseId);
    });
  },
  saveImportedCourses: function(coursesJsonString) {
    return new Promise(function(resolve, reject) {
      var promiseId = 'saveCourses_' + Date.now() + Math.random().toString(36).substring(2);
      window._androidPromiseResolvers[promiseId] = resolve;
      window._androidPromiseRejectors[promiseId] = reject;
      AndroidBridge.saveImportedCourses(coursesJsonString, promiseId);
    });
  },
  saveCourseConfig: function(configJsonString) {
    return new Promise(function(resolve, reject) {
      var promiseId = 'saveConfig_' + Date.now() + Math.random().toString(36).substring(2);
      window._androidPromiseResolvers[promiseId] = resolve;
      window._androidPromiseRejectors[promiseId] = reject;
      AndroidBridge.saveCourseConfig(configJsonString, promiseId);
    });
  },
  savePresetTimeSlots: function(timeSlotsJsonString) {
    return new Promise(function(resolve, reject) {
      var promiseId = 'saveTimeSlots_' + Date.now() + Math.random().toString(36).substring(2);
      window._androidPromiseResolvers[promiseId] = resolve;
      window._androidPromiseRejectors[promiseId] = reject;
      AndroidBridge.savePresetTimeSlots(timeSlotsJsonString, promiseId);
    });
  }
};
''';

  @override
  void initState() {
    super.initState();
    if (kIsWeb) return;

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..addJavaScriptChannel(
        'FlutterBridge',
        onMessageReceived: (msg) {
          unawaited(_handleBridgeMessage(msg.message));
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            unawaited(_checkForSchedule());
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.systemUrl));

    _webViewChild = RepaintBoundary(child: WebViewWidget(controller: _controller));
    unawaited(_warmupAdapter());
  }

  Future<void> _warmupAdapter() async {
    final lookupId = widget.schoolId.isNotEmpty ? widget.schoolId : widget.systemType;
    _adapter = await _adapterService.findAdapter(lookupId);
    if (_adapter != null) {
      _adapterJs = await _adapterService.loadAdapterJs(_adapter!);
    }
  }

  void _appendDebugLog(String message) {
    _debugLogs.add(message);
    if (_debugLogs.length > 40) {
      _debugLogs.removeRange(0, _debugLogs.length - 40);
    }
  }

  Future<void> _checkForSchedule() async {
    final result = await _controller.runJavaScriptReturningResult(
      "document.querySelector('table') !== null || document.querySelectorAll('iframe').length > 0",
    );
    final hasSchedule = result == true || result.toString() == 'true';
    if (!mounted || hasSchedule == _hasScheduleHtml) return;
    setState(() => _hasScheduleHtml = hasSchedule);
  }

  Future<void> _handleBridgeMessage(String message) async {
    try {
      final decoded = jsonDecode(message);
      if (decoded is List) {
        _pendingAdapterCourses = decoded
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
        return;
      }
      if (decoded is! Map) return;
      final payload = Map<String, dynamic>.from(decoded);
      switch (payload['type']) {
        case 'debug':
          _appendDebugLog(payload['msg']?.toString() ?? '');
          return;
        case 'showAlert':
          await _handleBridgeAlert(payload);
          return;
        case 'showPrompt':
          await _handleBridgePrompt(payload);
          return;
        case 'showSingleSelection':
          await _handleBridgeSingleSelection(payload);
          return;
        case 'saveImportedCourses':
          await _handleBridgeSaveCourses(payload);
          return;
        case 'saveCourseConfig':
          await _handleBridgeSaveCourseConfig(payload);
          return;
        case 'savePresetTimeSlots':
          await _handleBridgeSaveTimeSlots(payload);
          return;
        case 'taskComplete':
          if (_adapterCompleter != null && !_adapterCompleter!.isCompleted) {
            _adapterCompleter!.complete(_pendingAdapterCourses);
          }
          return;
      }
    } catch (e) {
      _appendDebugLog('[Bridge] 消息解析失败: $e');
    }
  }

  Future<void> _resolveBridgePromise(String promiseId, dynamic result) async {
    await _controller.runJavaScript(
      'window._resolveAndroidPromise(${jsonEncode(promiseId)}, ${jsonEncode(result)});',
    );
  }

  Future<void> _rejectBridgePromise(String promiseId, String error) async {
    await _controller.runJavaScript(
      'window._rejectAndroidPromise(${jsonEncode(promiseId)}, ${jsonEncode(error)});',
    );
  }

  Future<void> _handleBridgeAlert(Map<String, dynamic> payload) async {
    final promiseId = payload['promiseId']?.toString() ?? '';
    if (promiseId.isEmpty || !mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(payload['title']?.toString() ?? '提示'),
        content: Text(payload['content']?.toString() ?? ''),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(payload['confirmText']?.toString() ?? '确定'),
          ),
        ],
      ),
    );
    await _resolveBridgePromise(promiseId, true);
  }

  Future<void> _handleBridgePrompt(Map<String, dynamic> payload) async {
    final promiseId = payload['promiseId']?.toString() ?? '';
    if (promiseId.isEmpty || !mounted) return;

    final title = payload['title']?.toString() ?? '请输入';
    final tip = payload['tip']?.toString() ?? '';
    final defaultText = payload['defaultText']?.toString() ?? '';
    final validator = payload['validator']?.toString() ?? '';
    final controller = TextEditingController(text: defaultText);
    String? errorText;

    final value = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (tip.isNotEmpty) ...[
                Text(
                  tip,
                  style: const TextStyle(color: AppColorTokens.textSecondary),
                ),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: controller,
                autofocus: true,
                decoration: InputDecoration(errorText: errorText),
                onSubmitted: (_) {
                  final validationMessage = _validatePromptValue(
                    title,
                    validator,
                    controller.text,
                  );
                  if (validationMessage != null) {
                    setSheetState(() => errorText = validationMessage);
                    return;
                  }
                  Navigator.pop(ctx, controller.text.trim());
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () {
                final validationMessage = _validatePromptValue(
                  title,
                  validator,
                  controller.text,
                );
                if (validationMessage != null) {
                  setSheetState(() => errorText = validationMessage);
                  return;
                }
                Navigator.pop(ctx, controller.text.trim());
              },
              child: const Text('确定'),
            ),
          ],
        ),
      ),
    );

    if (value == null) {
      await _resolveBridgePromise(promiseId, null);
      return;
    }
    await _resolveBridgePromise(promiseId, value);
  }

  String? _validatePromptValue(String title, String validator, String rawValue) {
    final value = rawValue.trim();
    if (validator == 'validateYearInput' || title.contains('学年')) {
      if (!RegExp(r'^\d{4}$').hasMatch(value)) {
        return '请输入四位数字的学年';
      }
      return null;
    }
    if (value.isEmpty) {
      return '请输入内容';
    }
    return null;
  }

  Future<void> _handleBridgeSingleSelection(Map<String, dynamic> payload) async {
    final promiseId = payload['promiseId']?.toString() ?? '';
    if (promiseId.isEmpty || !mounted) return;

    final title = payload['title']?.toString() ?? '请选择';
    final items = _parseSelectionItems(payload['itemsJson']);
    final selectedIndex = await showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(title),
        children: [
          for (var i = 0; i < items.length; i++)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, i),
              child: Text(items[i]),
            ),
        ],
      ),
    );

    await _resolveBridgePromise(promiseId, selectedIndex ?? -1);
  }

  List<String> _parseSelectionItems(dynamic value) {
    if (value is List) {
      return value.map((item) => item.toString()).toList();
    }
    if (value is String && value.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is List) {
          return decoded.map((item) => item.toString()).toList();
        }
      } catch (_) {}
    }
    return const [];
  }

  Future<void> _handleBridgeSaveCourses(Map<String, dynamic> payload) async {
    final promiseId = payload['promiseId']?.toString() ?? '';
    final parsed = _decodeMapList(payload['coursesJson']);
    if (promiseId.isEmpty) return;
    if (parsed == null) {
      await _rejectBridgePromise(promiseId, '课程数据格式不正确');
      return;
    }
    _pendingAdapterCourses = parsed;
    _appendDebugLog('[Bridge] 收到 ${parsed.length} 门课程');
    await _resolveBridgePromise(promiseId, true);
  }

  Future<void> _handleBridgeSaveCourseConfig(Map<String, dynamic> payload) async {
    final promiseId = payload['promiseId']?.toString() ?? '';
    final parsed = _decodeMap(payload['configJson']);
    if (promiseId.isEmpty) return;
    if (parsed == null) {
      await _rejectBridgePromise(promiseId, '课表配置格式不正确');
      return;
    }
    _pendingCourseConfig = {...?_pendingCourseConfig, ...parsed};
    await _resolveBridgePromise(promiseId, true);
  }

  Future<void> _handleBridgeSaveTimeSlots(Map<String, dynamic> payload) async {
    final promiseId = payload['promiseId']?.toString() ?? '';
    final parsed = _decodeMapList(payload['timeSlotsJson']);
    if (promiseId.isEmpty) return;
    if (parsed == null) {
      await _rejectBridgePromise(promiseId, '作息时间格式不正确');
      return;
    }
    _pendingPresetTimeSlots = parsed;
    _appendDebugLog('[Bridge] 收到 ${parsed.length} 条作息时间');
    await _resolveBridgePromise(promiseId, true);
  }

  Map<String, dynamic>? _decodeMap(dynamic value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    if (value is String && value.trim().isNotEmpty) {
      final decoded = jsonDecode(value);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    }
    return null;
  }

  List<Map<String, dynamic>>? _decodeMapList(dynamic value) {
    if (value is List) {
      return value
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }
    if (value is String && value.trim().isNotEmpty) {
      final decoded = jsonDecode(value);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
      }
    }
    return null;
  }

  String? _pendingStartDate() {
    final raw = (_pendingCourseConfig?['semesterStartDate'] ??
            _pendingCourseConfig?['startDate'] ??
            _pendingCourseConfig?['semester_start_date'])
        ?.toString()
        .trim();
    if (raw == null || raw.isEmpty) return null;
    final normalized = raw.replaceAll('/', '-').replaceAll('.', '-');
    final parsed = DateTime.tryParse(normalized);
    if (parsed == null) return normalized;
    return _formatDate(parsed);
  }

  int? _pendingTotalWeeks() {
    final raw = _pendingCourseConfig?['semesterTotalWeeks'] ??
        _pendingCourseConfig?['totalWeeks'] ??
        _pendingCourseConfig?['semester_total_weeks'];
    if (raw is num) return raw.toInt();
    return int.tryParse(raw?.toString() ?? '');
  }

  String _formatDate(DateTime value) {
    final year = value.year.toString().padLeft(4, '0');
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  Future<void> _captureAndParse() async {
    if (_importing) return;
    setState(() => _importing = true);
    _debugLogs.clear();
    _pendingAdapterCourses = const [];
    _pendingCourseConfig = null;
    _pendingPresetTimeSlots = const [];
    var parseSource = '';

    try {
      if (_adapter == null || _adapterJs == null) {
        await _warmupAdapter();
      }
      var courses = <Course>[];

      if (_adapter != null && _adapterJs != null) {
        final diagResult = await _controller.runJavaScriptReturningResult(
          r'''JSON.stringify({
            url: location.href,
            title: document.title,
            tableCount: document.querySelectorAll('table').length,
            mondayInPage: document.body ? document.body.innerText.includes('星期一') : false,
            iframeCount: document.querySelectorAll('iframe').length,
            bodyLen: document.body ? document.body.innerText.length : 0
          })''',
        );
        if (diagResult is String && diagResult.isNotEmpty) {
          _appendDebugLog('[页面状态] $diagResult');
        }

        _adapterCompleter = Completer<List<Map<String, dynamic>>>();
        await _controller.runJavaScript('$_bridgeShim$_adapterJs');
        try {
          final result = await _adapterCompleter!.future.timeout(
            const Duration(seconds: 15),
          );
          courses = result.map(_adapterCourseToCourse).toList();
          parseSource = '拾光适配器：${_adapter!.adapterName} (${courses.length}门)';
        } on TimeoutException {
          _adapterCompleter = null;
          parseSource = '拾光适配器超时';
        }
      } else {
        parseSource = '无适配器';
      }

      if (!mounted) return;

      if (courses.isEmpty) {
        setState(() => _importing = false);
        final debugInfo = _debugLogs.isNotEmpty ? '\n调试: ${_debugLogs.join(' | ')}' : '';
        final msg = _adapter != null
            ? '${_adapter!.adapterName} 解析失败。请确认已登录教务系统并进入课表页面后重试。$debugInfo'
            : '该学校暂无适配器，欢迎参与适配。';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: AppColorTokens.warning,
            duration: const Duration(seconds: 20),
          ),
        );
        return;
      }

      final choice = await showImportTargetSheet(
        context,
        currentTable: ref.read(scheduleProvider).currentTable,
        courseCount: courses.length,
      );
      if (choice == null) {
        if (mounted) setState(() => _importing = false);
        return;
      }
      if (!mounted) return;

      final importedTimeSlots = TimeSlot.parseList(
        _pendingPresetTimeSlots,
        fallback: const [],
      );
      final importResult = await ref.read(scheduleProvider.notifier).importCourses(
            courses,
            mode: choice.mode,
            newTableName: choice.newTableName,
            startDate: _pendingStartDate(),
            totalWeeks: _pendingTotalWeeks(),
            timeSlots: importedTimeSlots.isEmpty ? null : importedTimeSlots,
          );
      if (!mounted) return;
      setState(() => _importing = false);

      final notes = <String>[
        if (parseSource.isNotEmpty) parseSource,
        if (_pendingPresetTimeSlots.isNotEmpty) '已自动应用学校作息时间。',
      ];
      final snackMessage = [importResult.message, ...notes].join('\n');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(snackMessage),
          backgroundColor: importResult.message.contains('失败')
              ? AppColorTokens.warning
              : AppColorTokens.success,
          duration: const Duration(seconds: 5),
        ),
      );
      if (!importResult.isSuccess) return;

      await promptForMissingStartDateIfNeeded(context, ref, importResult);
      if (!mounted) return;
      context.go('/schedule');
    } catch (e) {
      if (!mounted) return;
      setState(() => _importing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('解析失败: $e'),
          backgroundColor: AppColorTokens.error,
        ),
      );
    }
  }

  Course _adapterCourseToCourse(Map<String, dynamic> json) {
    final parsed = Course.fromJson(json);
    return parsed.copyWith(
      id: '${DateTime.now().microsecondsSinceEpoch}_${parsed.day}_${parsed.startSection}',
      color: AppConstants.stableCourseColor(parsed.name),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LiquidScaffold(
      appBar: AppBar(
        title: Text(widget.schoolName, style: const TextStyle(fontSize: 16)),
        actions: [
          TextButton(
            onPressed: _hasScheduleHtml && !_importing ? _captureAndParse : null,
            child: _importing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('解析导入'),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: AppColorTokens.warning.withAlpha(25),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline,
                  size: 16,
                  color: AppColorTokens.warning,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _importing
                        ? '正在调用适配器解析当前页面，请稍等...'
                        : '在学校官网找到教务系统 → 登录 → 进入课表页面 → 点“解析导入”',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: kIsWeb
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.web_outlined,
                            size: 48,
                            color: AppColorTokens.textTertiary,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            '教务系统导入需要在手机上使用',
                            style: TextStyle(
                              fontSize: 15,
                              color: AppColorTokens.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            '当前在 Web 模式下运行，无法使用 WebView。请在真机或模拟器上运行 App。',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColorTokens.textTertiary,
                            ),
                          ),
                          const SizedBox(height: 24),
                          OutlinedButton(
                            onPressed: () => context.pop(),
                            child: const Text('返回'),
                          ),
                        ],
                      ),
                    ),
                  )
                : _webViewChild,
          ),
        ],
      ),
    );
  }
}
