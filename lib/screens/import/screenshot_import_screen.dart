import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/theme.dart';
import '../../models/course.dart';
import '../../providers/schedule_provider.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/import_target_sheet.dart';
import '../../widgets/liquid_scaffold.dart';
import 'import_start_date_helper.dart';

class ScreenshotImportScreen extends ConsumerStatefulWidget {
  const ScreenshotImportScreen({super.key});

  @override
  ConsumerState<ScreenshotImportScreen> createState() =>
      _ScreenshotImportScreenState();
}

class _ScreenshotImportScreenState extends ConsumerState<ScreenshotImportScreen> {
  final _jsonCtrl = TextEditingController();
  bool _importing = false;

  @override
  void dispose() {
    _jsonCtrl.dispose();
    super.dispose();
  }

  String get _promptText =>
      '请帮我把这张课表截图解析成 JSON 格式，每个课程包含以下字段：\n'
      'name（课程名称）、teacher（教师）、position（上课地点）、'
      'day（星期几，1=周一 7=周日）、startSection（开始节次）、'
      'endSection（结束节次）、weeks（上课周次列表，如 [1,2,3,4,5]）。\n'
      '输出格式：{"courses": [{...}, {...}]}';

  Future<void> _importPastedJson() async {
    final text = _jsonCtrl.text.trim();
    if (text.isEmpty) {
      _showError('请先粘贴 AI 返回的 JSON 内容');
      return;
    }
    await _importJson(text);
  }

  Future<void> _importJsonFile() async {
    try {
      final pickerResult = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (pickerResult == null || pickerResult.files.isEmpty) return;
      final bytes = pickerResult.files.single.bytes;
      if (bytes == null) return;
      await _importJson(utf8.decode(bytes));
    } catch (e) {
      _showError('文件读取失败: $e');
    }
  }

  Future<void> _importJson(String content) async {
    if (content.isEmpty) {
      _showError('JSON 内容为空');
      return;
    }

    setState(() => _importing = true);

    try {
      final decoded = jsonDecode(content);
      List<dynamic> courseList;
      if (decoded is Map && decoded.containsKey('courses')) {
        courseList = decoded['courses'] as List<dynamic>;
      } else if (decoded is List) {
        courseList = decoded;
      } else {
        _showError('JSON 格式不正确，需要包含 courses 数组或直接是课程数组');
        setState(() => _importing = false);
        return;
      }

      final courses = courseList
          .map((item) => Course.fromJson(item as Map<String, dynamic>))
          .toList();
      if (courses.isEmpty) {
        _showError('未解析到课程，请检查 JSON 格式');
        setState(() => _importing = false);
        return;
      }

      if (!mounted) return;
      final choice = await showImportTargetSheet(
        context,
        currentTable: ref.read(scheduleProvider).currentTable,
        courseCount: courses.length,
      );
      if (choice == null) {
        setState(() => _importing = false);
        return;
      }
      if (!mounted) return;

      final result = await ref.read(scheduleProvider.notifier).importCourses(
            courses,
            mode: choice.mode,
            newTableName: choice.newTableName,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: result.message.contains('失败')
                ? AppColorTokens.warning
                : AppColorTokens.success,
          ),
        );
        if (result.isSuccess) {
          await promptForMissingStartDateIfNeeded(context, ref, result);
          if (context.mounted) context.go('/schedule');
        }
      }
    } catch (e) {
      _showError('导入失败: $e');
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColorTokens.error),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LiquidScaffold(
      appBar: AppBar(title: const Text('AI 辅助导入')),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GlassCard(
                borderRadius: 24,
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.lightbulb_outline, color: AppColorTokens.warning),
                        SizedBox(width: 10),
                        Text('使用说明', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '1. 将你的课表截图发送给豆包 / 千问等 AI 助手\n'
                      '2. 把下面的提示词一起发给 AI\n'
                      '3. AI 会返回一段 JSON 文本\n'
                      '4. 将 JSON 粘贴到下方输入框，或导出为 .json 文件后导入',
                      style: TextStyle(fontSize: 14, height: 1.7, color: AppColorTokens.textSecondary),
                    ),
                    const SizedBox(height: 16),
                    GlassCard(
                      borderRadius: 18,
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text('提示词模板', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                              const Spacer(),
                              TextButton.icon(
                                onPressed: () {
                                  Clipboard.setData(ClipboardData(text: _promptText));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('提示词已复制到剪贴板'), backgroundColor: AppColorTokens.success),
                                  );
                                },
                                icon: const Icon(Icons.copy, size: 16),
                                label: const Text('复制', style: TextStyle(fontSize: 13)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(_promptText, style: const TextStyle(fontSize: 12, height: 1.6, color: AppColorTokens.textTertiary, fontFamily: 'monospace')),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _jsonCtrl,
                maxLines: 10,
                enabled: !_importing,
                decoration: InputDecoration(
                  labelText: '粘贴 AI 返回的 JSON',
                  hintText: '将 AI 返回的 JSON 文本粘贴到这里...',
                  border: const OutlineInputBorder(),
                  alignLabelWithHint: true,
                  suffixIcon: _jsonCtrl.text.isNotEmpty
                      ? IconButton(icon: const Icon(Icons.clear), onPressed: () => _jsonCtrl.clear())
                      : null,
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _importing ? null : _importPastedJson,
                      icon: _importing ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.paste_rounded),
                      label: const Text('从粘贴导入'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _importing ? null : _importJsonFile,
                      icon: const Icon(Icons.file_open_rounded),
                      label: const Text('从文件导入'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
