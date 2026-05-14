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
  showToast: function(msg) { FlutterBridge.postMessage(JSON.stringify({type:'debug',msg:'[Toast] '+msg})); },
  showAlert: function(title, content, confirmText, promiseId) {
    FlutterBridge.postMessage(JSON.stringify({type:'debug',msg:'[Alert] '+title+': '+(content||'').substring(0,200)}));
    window._resolveAndroidPromise(promiseId, 'true');
  },
  showPrompt: function(title, tip, defaultText, validator, promiseId) {
    FlutterBridge.postMessage(JSON.stringify({type:'debug',msg:'[Prompt] '+title+' → 默认值:'+defaultText}));
    window._resolveAndroidPromise(promiseId, defaultText);
  },
  showSingleSelection: function(title, itemsJson, defaultIndex, promiseId) {
    window._resolveAndroidPromise(promiseId, defaultIndex.toString());
  },
  saveImportedCourses: function(coursesJson, promiseId) {
    FlutterBridge.postMessage(coursesJson);
    window._resolveAndroidPromise(promiseId, 'true');
  },
  saveCourseConfig: function(configJson, promiseId) {
    window._resolveAndroidPromise(promiseId, 'true');
  },
  savePresetTimeSlots: function(timeSlotsJson, promiseId) {
    window._resolveAndroidPromise(promiseId, 'true');
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
          try {
            final decoded = jsonDecode(msg.message);
            if (decoded is Map && decoded['type'] == 'debug') {
              _appendDebugLog(decoded['msg'] as String);
            } else if (decoded is Map &&
                decoded['type'] == 'taskComplete' &&
                _adapterCompleter != null &&
                !_adapterCompleter!.isCompleted) {
              _adapterCompleter!.complete(const <Map<String, dynamic>>[]);
            } else if (decoded is List &&
                _adapterCompleter != null &&
                !_adapterCompleter!.isCompleted) {
              _adapterCompleter!.complete(decoded.cast<Map<String, dynamic>>());
            }
          } catch (_) {}
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
      _adapterJs = await _adapterService.loadAdapterJs(_adapter!.jsFile);
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

  Future<void> _captureAndParse() async {
    if (_importing) return;
    setState(() => _importing = true);
    _debugLogs.clear();
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

      final msg = await ref.read(scheduleProvider.notifier).importCourses(
            courses,
            mode: choice.mode,
            newTableName: choice.newTableName,
          );
      if (!mounted) return;
      setState(() => _importing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$msg\n$parseSource'),
          backgroundColor: msg.contains('失败')
              ? AppColorTokens.warning
              : AppColorTokens.success,
          duration: const Duration(seconds: 5),
        ),
      );
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
    final weeks = _parseWeeks(json['weeks'] ?? json['weekList']);
    final name = (json['name'] ?? '').toString();
    return Course(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name,
      teacher: (json['teacher'] ?? '').toString(),
      position: (json['position'] ?? json['location'] ?? '').toString(),
      day: ((json['day'] ?? json['dayOfWeek'] ?? 1) as num).toInt().clamp(1, 7),
      startSection: ((json['startSection'] ?? json['startPeriod'] ?? 1) as num).toInt().clamp(1, 12),
      endSection: ((json['endSection'] ?? json['endPeriod'] ?? 2) as num).toInt().clamp(1, 12),
      weekList: weeks,
      color: AppConstants.stableCourseColor(name),
    );
  }

  List<int> _parseWeeks(dynamic value) {
    if (value is List) {
      final parsed = value
          .map((e) => int.tryParse(e.toString()) ?? 0)
          .where((e) => e > 0)
          .toList();
      if (parsed.isNotEmpty) return parsed;
    }
    if (value is String && value.trim().isNotEmpty) {
      final weeks = <int>[];
      for (final part in value.split(',')) {
        final item = part.trim().replaceAll('周', '');
        if (item.contains('-')) {
          final range = item.split('-');
          if (range.length == 2) {
            final start = int.tryParse(range[0].trim()) ?? 0;
            final end = int.tryParse(range[1].trim()) ?? 0;
            if (start > 0 && end >= start) {
              for (var i = start; i <= end; i++) {
                weeks.add(i);
              }
            }
          }
        } else {
          final single = int.tryParse(item);
          if (single != null && single > 0) weeks.add(single);
        }
      }
      if (weeks.isNotEmpty) {
        final deduped = weeks.toSet().toList()..sort();
        return deduped;
      }
    }
    return List.generate(20, (i) => i + 1);
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
