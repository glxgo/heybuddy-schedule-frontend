import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/theme.dart';
import '../../models/course.dart';
import '../../providers/schedule_provider.dart';
import '../../widgets/glass_card.dart';
import 'import_start_date_helper.dart';
import '../../widgets/import_target_sheet.dart';
import '../../widgets/liquid_scaffold.dart';

class ImportMethodScreen extends ConsumerWidget {
  const ImportMethodScreen({super.key});

  static const _applyUrl = 'https://v.wjx.cn/vm/e9L3RYG.aspx';

  Future<void> _importJsonFile(BuildContext context, WidgetRef ref) async {
    try {
      final pickerResult = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (pickerResult == null || pickerResult.files.isEmpty) return;
      final bytes = pickerResult.files.single.bytes;
      if (bytes == null && pickerResult.files.single.path == null) return;
      final content = bytes != null ? utf8.decode(bytes) : '';
      if (content.isEmpty) return;

      final decoded = jsonDecode(content);
      List<dynamic> courseList;
      if (decoded is Map && decoded.containsKey('courses')) {
        courseList = decoded['courses'] as List<dynamic>;
      } else if (decoded is List) {
        courseList = decoded;
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('JSON 格式不正确'),
              backgroundColor: AppColorTokens.error,
            ),
          );
        }
        return;
      }

      final courses = courseList
          .map((item) => Course.fromJson(item as Map<String, dynamic>))
          .toList();
      if (courses.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('未解析到课程'),
              backgroundColor: AppColorTokens.warning,
            ),
          );
        }
        return;
      }

      if (!context.mounted) return;
      final choice = await showImportTargetSheet(
        context,
        currentTable: ref.read(scheduleProvider).currentTable,
        courseCount: courses.length,
      );
      if (choice == null) return;
      if (!context.mounted) return;

      final importResult = await ref.read(scheduleProvider.notifier).importCourses(
            courses,
            mode: choice.mode,
            newTableName: choice.newTableName,
          );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(importResult.message),
            backgroundColor: importResult.message.contains('失败')
                ? AppColorTokens.warning
                : AppColorTokens.success,
          ),
        );
        if (importResult.isSuccess) {
          await promptForMissingStartDateIfNeeded(context, ref, importResult);
          if (context.mounted) context.go('/schedule');
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('导入失败: $e'),
            backgroundColor: AppColorTokens.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LiquidScaffold(
      appBar: AppBar(title: const Text('导入课表')),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '选择导入方式',
                style: TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w900,
                  color: AppColorTokens.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '支持教务系统一键导入、AI 辅助导入或 JSON 文件导入',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColorTokens.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.only(bottom: 32),
                  children: [
                    _ImportCard(
                      icon: Icons.school_outlined,
                      title: '教务系统导入',
                      subtitle: '选择你的学校，一键导入课表',
                      color: AppColorTokens.primary,
                      badge: '推荐',
                      badgeColor: AppColorTokens.success,
                      onTap: () => context.push('/select-school'),
                    ),
                    const SizedBox(height: 14),
                    _ImportCard(
                      icon: Icons.auto_awesome_outlined,
                      title: 'AI 辅助导入',
                      subtitle: '将课表截图发给 AI，粘贴返回的 JSON 即可导入',
                      color: AppColorTokens.primaryGradientEnd,
                      onTap: () => context.push('/import/screenshot'),
                    ),
                    const SizedBox(height: 14),
                    _ImportCard(
                      icon: Icons.code_outlined,
                      title: 'JSON 文件导入',
                      subtitle: '选择 .json 格式的拾光课表数据',
                      color: AppColorTokens.accent,
                      onTap: () => _importJsonFile(context, ref),
                    ),
                    const SizedBox(height: 22),
                    GlassCard(
                      borderRadius: 22,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      onTap: () => launchUrl(Uri.parse(_applyUrl)),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.edit_note_rounded,
                            size: 22,
                            color: AppColorTokens.textSecondary,
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              '申请适配 — 提交学校信息，帮助我们支持更多学校',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColorTokens.textSecondary,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.open_in_new_rounded,
                            size: 18,
                            color: AppColorTokens.textTertiary,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ImportCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  final String? badge;
  final Color? badgeColor;

  const _ImportCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
    this.badge,
    this.badgeColor,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: onTap,
      borderRadius: 26,
      padding: const EdgeInsets.all(18),
      elevation: 1.2,
      gradient: LinearGradient(
        colors: [AppColorTokens.surfaceGlassStrong, color.withAlpha(18)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color.withAlpha(38), color.withAlpha(18)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: color.withAlpha(70)),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: AppColorTokens.textPrimary,
                        ),
                      ),
                    ),
                    if (badge != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: (badgeColor ?? AppColorTokens.success)
                              .withAlpha(28),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: (badgeColor ?? AppColorTokens.success)
                                .withAlpha(75),
                          ),
                        ),
                        child: Text(
                          badge!,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: badgeColor ?? AppColorTokens.success,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColorTokens.textSecondary,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          const Icon(
            Icons.chevron_right_rounded,
            color: AppColorTokens.textTertiary,
          ),
        ],
      ),
    );
  }
}
