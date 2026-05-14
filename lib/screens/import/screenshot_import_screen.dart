import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../config/constants.dart';
import '../../config/theme.dart';
import '../../models/course.dart';
import '../../providers/auth_provider.dart';
import '../../providers/schedule_provider.dart';
import '../../services/ocr_service.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/import_target_sheet.dart';
import '../../widgets/liquid_scaffold.dart';

class ScreenshotImportScreen extends ConsumerStatefulWidget {
  const ScreenshotImportScreen({super.key});

  @override
  ConsumerState<ScreenshotImportScreen> createState() =>
      _ScreenshotImportScreenState();
}

class _ScreenshotImportScreenState extends ConsumerState<ScreenshotImportScreen> {
  static const _warnImageBytes = 700 * 1024;
  static const _maxImageBytes = 1500 * 1024;

  File? _image;
  bool _recognizing = false;
  bool _importing = false;
  bool _hasWeekdayAnomaly = false;
  int _imageBytesLength = 0;
  List<OcrCourse> _courses = [];
  String _statusText = '请选择或拍摄课表截图';

  int _periodMinutes = 45;
  String _morningStart = '08:00';
  String _afternoonStart = '14:00';
  String _eveningStart = '19:00';
  int _morningCount = 5;
  int _afternoonCount = 4;
  int _eveningCount = 2;
  bool _hasConfig = false;

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      maxWidth: 1280,
      maxHeight: 1280,
      imageQuality: 70,
    );
    if (picked != null) {
      final file = File(picked.path);
      final bytesLength = await file.length();
      setState(() {
        _image = file;
        _imageBytesLength = bytesLength;
        _courses = [];
        _hasWeekdayAnomaly = false;
        _statusText = bytesLength > _warnImageBytes
            ? '图片已选择（约 ${_formatBytes(bytesLength)}），建议先裁剪到课表区域再识别，会更快更准。'
            : '图片已选择，点击“开始识别”';
      });
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  bool _detectWeekdayAnomaly(List<OcrCourse> courses) {
    if (courses.length < 6) return false;
    final counts = <int, int>{};
    for (final course in courses) {
      counts[course.dayOfWeek] = (counts[course.dayOfWeek] ?? 0) + 1;
    }
    final maxCount = counts.values.fold<int>(0, (max, value) => value > max ? value : max);
    return maxCount / courses.length >= 0.8;
  }

  Future<void> _showConfigDialog() async {
    final result = await showDialog<_TimeConfigResult>(
      context: context,
      builder: (ctx) => _TimeConfigDialog(
        periodMinutes: _periodMinutes,
        morningStart: _morningStart,
        afternoonStart: _afternoonStart,
        eveningStart: _eveningStart,
        morningCount: _morningCount,
        afternoonCount: _afternoonCount,
        eveningCount: _eveningCount,
      ),
    );
    if (result == null) return;
    setState(() {
      _periodMinutes = result.periodMinutes;
      _morningStart = result.morningStart;
      _afternoonStart = result.afternoonStart;
      _eveningStart = result.eveningStart;
      _morningCount = result.morningCount;
      _afternoonCount = result.afternoonCount;
      _eveningCount = result.eveningCount;
      _hasConfig = true;
    });
    await _recognize();
  }

  Future<void> _recognize() async {
    if (_image == null || _recognizing) return;
    setState(() {
      _recognizing = true;
      _statusText = '正在压缩并上传截图给 AI...';
      _courses = [];
      _hasWeekdayAnomaly = false;
    });

    try {
      final bytes = await _image!.readAsBytes();
      if (bytes.length > _maxImageBytes) {
        if (!mounted) return;
        setState(() {
          _recognizing = false;
          _statusText = '图片太大了（${_formatBytes(bytes.length)}），请先裁剪到课表区域后再试。';
        });
        return;
      }
      if (!mounted) return;
      setState(() {
        _statusText = bytes.length > _warnImageBytes
            ? '正在上传较大的截图（${_formatBytes(bytes.length)}），这可能需要 30-60 秒...'
            : 'AI 正在识别课程、教室和节次...';
      });

      final base64 = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      final authState = ref.read(authProvider);
      final token = authState.token ?? '';

      final result = await OcrService.instance.recognize(
        base64,
        token,
        config: {
          'morningStart': _morningStart,
          'afternoonStart': _afternoonStart,
          'eveningStart': _eveningStart,
          'periodMinutes': _periodMinutes,
          'morningCount': _morningCount,
          'afternoonCount': _afternoonCount,
          'eveningCount': _eveningCount,
        },
      );

      if (!mounted) return;
      final anomaly = result.success && _detectWeekdayAnomaly(result.courses);
      setState(() {
        _recognizing = false;
        _courses = result.success ? result.courses : const [];
        _hasWeekdayAnomaly = anomaly;
        _statusText = [
          result.msg,
          if (result.warning != null && result.warning!.isNotEmpty) result.warning,
          if (anomaly) '检测到大部分课程落在同一天，导入前请仔细核对。',
        ].join('\n');
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _recognizing = false;
        _statusText = '识别失败：$e';
      });
    }
  }

  Future<void> _importToSchedule() async {
    if (_courses.isEmpty || _importing) return;
    if (_hasWeekdayAnomaly) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('识别结果可能异常'),
          content: const Text(
            '检测到大部分课程被识别到了同一天，这通常说明截图表头不够清晰。你可以先返回重新裁剪，也可以继续导入后手动修改。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('返回检查'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('仍然导入'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    setState(() => _importing = true);
    final courses = _courses.asMap().entries.map((entry) {
      final c = entry.value;
      return Course(
        id: 'ocr_${DateTime.now().microsecondsSinceEpoch}_${entry.key}',
        name: c.name,
        teacher: c.teacher,
        position: c.location,
        day: c.dayOfWeek,
        startSection: c.startPeriod,
        endSection: c.endPeriod,
        color: AppConstants.stableCourseColor(c.name),
      );
    }).toList();
    if (!mounted) return;
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: msg.contains('失败')
            ? AppColorTokens.warning
            : AppColorTokens.success,
      ),
    );
    setState(() => _importing = false);
    context.go('/schedule');
  }

  @override
  Widget build(BuildContext context) {
    final statusIsSuccess = _courses.isNotEmpty;
    return LiquidScaffold(
      appBar: AppBar(title: const Text('AI 拍照识图')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GlassCard(
              borderRadius: 24,
              padding: const EdgeInsets.all(14),
              elevation: 1.0,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    height: 250,
                    decoration: BoxDecoration(
                      color: AppColorTokens.background,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColorTokens.divider),
                    ),
                    child: _image != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(17),
                            child: Image.file(_image!, fit: BoxFit.contain),
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.image_outlined,
                                size: 48,
                                color: AppColorTokens.textTertiary.withAlpha(100),
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                '选择课表截图',
                                style: TextStyle(
                                  color: AppColorTokens.textSecondary,
                                ),
                              ),
                            ],
                          ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _recognizing
                              ? null
                              : () => _pickImage(ImageSource.gallery),
                          icon: const Icon(Icons.photo_library_outlined, size: 18),
                          label: const Text('相册'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _recognizing
                              ? null
                              : () => _pickImage(ImageSource.camera),
                          icon: const Icon(Icons.camera_alt_outlined, size: 18),
                          label: const Text('拍照'),
                        ),
                      ),
                    ],
                  ),
                  if (_imageBytesLength > 0) ...[
                    const SizedBox(height: 10),
                    Text(
                      '当前图片大小：${_formatBytes(_imageBytesLength)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: _imageBytesLength > _warnImageBytes
                            ? AppColorTokens.warning
                            : AppColorTokens.textTertiary,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _image != null && !_recognizing
                          ? (_hasConfig ? _recognize : _showConfigDialog)
                          : null,
                      icon: _recognizing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.auto_awesome, size: 18),
                      label: Text(
                        _recognizing
                            ? '识别中...'
                            : _hasConfig
                                ? '开始识别'
                                : '设置时间并开始识别',
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            GlassCard(
              borderRadius: 20,
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    _recognizing
                        ? Icons.hourglass_top_rounded
                        : statusIsSuccess
                            ? Icons.check_circle_outline_rounded
                            : Icons.info_outline_rounded,
                    size: 18,
                    color: _recognizing
                        ? AppColorTokens.primary
                        : statusIsSuccess
                            ? AppColorTokens.success
                            : AppColorTokens.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_statusText, style: const TextStyle(fontSize: 13)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '当前作息：$_morningStart / $_afternoonStart / $_eveningStart，每节 $_periodMinutes 分钟',
              style: const TextStyle(
                fontSize: 12,
                color: AppColorTokens.textTertiary,
              ),
            ),
            if (_courses.isNotEmpty) ...[
              if (_hasWeekdayAnomaly) ...[
                const SizedBox(height: 14),
                GlassCard(
                  borderRadius: 18,
                  padding: const EdgeInsets.all(12),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        size: 18,
                        color: AppColorTokens.warning,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '识别结果的星期分布看起来不太正常，建议先检查截图是否包含清晰的表头；如果继续导入，后面可能需要手动修改。',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColorTokens.textSecondary,
                            height: 1.45,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 18),
              const Text(
                '识别结果',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              ..._courses.take(10).map(
                    (c) => GlassCard(
                      margin: const EdgeInsets.only(bottom: 8),
                      borderRadius: 16,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  c.name,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                if (c.location.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    c.location,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColorTokens.textSecondary,
                                    ),
                                  ),
                                ],
                                if (c.teacher.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    c.teacher,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColorTokens.textTertiary,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            '周${c.dayOfWeek}\n第${c.startPeriod}-${c.endPeriod}节',
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColorTokens.textTertiary,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              const SizedBox(height: 14),
              SizedBox(
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _importing ? null : _importToSchedule,
                  icon: _importing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save_alt_rounded, size: 18),
                  label: Text(_importing ? '导入中...' : '确认并导入课表'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColorTokens.success,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TimeConfigResult {
  final int periodMinutes;
  final String morningStart;
  final String afternoonStart;
  final String eveningStart;
  final int morningCount;
  final int afternoonCount;
  final int eveningCount;

  const _TimeConfigResult({
    required this.periodMinutes,
    required this.morningStart,
    required this.afternoonStart,
    required this.eveningStart,
    required this.morningCount,
    required this.afternoonCount,
    required this.eveningCount,
  });
}

class _TimeConfigDialog extends StatefulWidget {
  final int periodMinutes;
  final String morningStart;
  final String afternoonStart;
  final String eveningStart;
  final int morningCount;
  final int afternoonCount;
  final int eveningCount;

  const _TimeConfigDialog({
    required this.periodMinutes,
    required this.morningStart,
    required this.afternoonStart,
    required this.eveningStart,
    required this.morningCount,
    required this.afternoonCount,
    required this.eveningCount,
  });

  @override
  State<_TimeConfigDialog> createState() => _TimeConfigDialogState();
}

class _TimeConfigDialogState extends State<_TimeConfigDialog> {
  late int _periodMinutes;
  late String _morningStart;
  late String _afternoonStart;
  late String _eveningStart;
  late int _morningCount;
  late int _afternoonCount;
  late int _eveningCount;

  @override
  void initState() {
    super.initState();
    _periodMinutes = widget.periodMinutes;
    _morningStart = widget.morningStart;
    _afternoonStart = widget.afternoonStart;
    _eveningStart = widget.eveningStart;
    _morningCount = widget.morningCount;
    _afternoonCount = widget.afternoonCount;
    _eveningCount = widget.eveningCount;
  }

  Future<void> _pickTime(String current, ValueChanged<String> onSet) async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.tryParse(current.split(':')[0]) ?? 8,
        minute: int.tryParse(current.split(':')[1]) ?? 0,
      ),
    );
    if (time != null) {
      setState(() {
        onSet(
          '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('设置作息时间'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '请确认课程时间信息，这会直接影响 AI 识别节次的准确率。',
              style: TextStyle(
                fontSize: 13,
                color: AppColorTokens.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            _buildIntField(
              '每节课时长（分钟）',
              _periodMinutes,
              (v) => _periodMinutes = v,
            ),
            const SizedBox(height: 12),
            _buildTimeField('上午第一节课开始', _morningStart, (v) => _morningStart = v),
            _buildIntField('上午节课数', _morningCount, (v) => _morningCount = v),
            const SizedBox(height: 12),
            _buildTimeField('下午第一节课开始', _afternoonStart, (v) => _afternoonStart = v),
            _buildIntField('下午节课数', _afternoonCount, (v) => _afternoonCount = v),
            const SizedBox(height: 12),
            _buildTimeField('晚上第一节课开始', _eveningStart, (v) => _eveningStart = v),
            _buildIntField('晚上节课数', _eveningCount, (v) => _eveningCount = v),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(
            context,
            _TimeConfigResult(
              periodMinutes: _periodMinutes,
              morningStart: _morningStart,
              afternoonStart: _afternoonStart,
              eveningStart: _eveningStart,
              morningCount: _morningCount,
              afternoonCount: _afternoonCount,
              eveningCount: _eveningCount,
            ),
          ),
          child: const Text('开始识别'),
        ),
      ],
    );
  }

  Widget _buildTimeField(String label, String value, ValueChanged<String> onSet) {
    return Row(
      children: [
        Text(label, style: const TextStyle(fontSize: 14)),
        const Spacer(),
        TextButton(
          onPressed: () => _pickTime(value, onSet),
          child: Text(
            value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  Widget _buildIntField(String label, int value, ValueChanged<int> onSet) {
    return Row(
      children: [
        Text(label, style: const TextStyle(fontSize: 14)),
        const Spacer(),
        IconButton(
          icon: const Icon(Icons.remove_circle_outline),
          onPressed: () => setState(() {
            if (value > 1) onSet(value - 1);
          }),
        ),
        Text(
          '$value',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        IconButton(
          icon: const Icon(Icons.add_circle_outline),
          onPressed: () => setState(() {
            onSet(value + 1);
          }),
        ),
      ],
    );
  }
}
