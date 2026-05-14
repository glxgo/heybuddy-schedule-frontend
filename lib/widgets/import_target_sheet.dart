import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../models/course.dart';
import '../providers/schedule_provider.dart';
import 'glass_card.dart';
import 'spring_button.dart';

class ImportTargetChoice {
  final CourseImportMode mode;
  final String? newTableName;

  const ImportTargetChoice({
    required this.mode,
    this.newTableName,
  });
}

Future<ImportTargetChoice?> showImportTargetSheet(
  BuildContext context, {
  required CourseTable? currentTable,
  required int courseCount,
}) {
  return showModalBottomSheet<ImportTargetChoice>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => _ImportTargetSheet(
      currentTable: currentTable,
      courseCount: courseCount,
    ),
  );
}

class _ImportTargetSheet extends StatefulWidget {
  final CourseTable? currentTable;
  final int courseCount;

  const _ImportTargetSheet({
    required this.currentTable,
    required this.courseCount,
  });

  @override
  State<_ImportTargetSheet> createState() => _ImportTargetSheetState();
}

class _ImportTargetSheetState extends State<_ImportTargetSheet> {
  CourseImportMode _mode = CourseImportMode.overwriteCurrent;
  final TextEditingController _nameCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final bottomSafe = MediaQuery.of(context).padding.bottom;
    final currentTableName = widget.currentTable?.name ?? '当前课表';

    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        bottomInset > 0 ? bottomInset + 14 : bottomSafe + 96,
      ),
      child: GlassCard(
        borderRadius: 28,
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
        elevation: 1.5,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColorTokens.primary.withAlpha(90),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '导入到哪里？',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              Text(
                '本次将导入 ${widget.courseCount} 门课程。',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColorTokens.textSecondary,
                ),
              ),
              const SizedBox(height: 18),
              _ChoiceCard(
                selected: _mode == CourseImportMode.overwriteCurrent,
                title: '覆盖当前课表',
                subtitle: '覆盖“$currentTableName”里现有的课程',
                onTap: () => setState(
                  () => _mode = CourseImportMode.overwriteCurrent,
                ),
              ),
              const SizedBox(height: 10),
              _ChoiceCard(
                selected: _mode == CourseImportMode.createNewTable,
                title: '新建课表',
                subtitle: '保留当前课表，导入到一张新课表中',
                onTap: () => setState(
                  () => _mode = CourseImportMode.createNewTable,
                ),
              ),
              if (_mode == CourseImportMode.createNewTable) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _nameCtrl,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: '新课表名称',
                    hintText: '例如：2025春季导入课表',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
              const SizedBox(height: 18),
              SpringButton(
                onTap: () {
                  if (_mode == CourseImportMode.createNewTable &&
                      _nameCtrl.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('请输入新课表名称')),
                    );
                    return;
                  }
                  Navigator.pop(
                    context,
                    ImportTargetChoice(
                      mode: _mode,
                      newTableName: _mode == CourseImportMode.createNewTable
                          ? _nameCtrl.text.trim()
                          : null,
                    ),
                  );
                },
                child: const Text('开始导入'),
              ),
              const SizedBox(height: 8),
              const Text(
                '提示：云端当前仍按“当前学期一份课表”保存，不区分本地多个课表。',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  color: AppColorTokens.textTertiary,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  final bool selected;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ChoiceCard({
    required this.selected,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: onTap,
      borderRadius: 20,
      padding: const EdgeInsets.all(14),
      borderOpacity: selected ? 0.9 : 0.55,
      gradient: selected
          ? LinearGradient(
              colors: [
                AppColorTokens.primary.withAlpha(18),
                AppColorTokens.primaryGradientEnd.withAlpha(14),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            )
          : null,
      child: Row(
        children: [
          Icon(
            selected
                ? Icons.radio_button_checked_rounded
                : Icons.radio_button_off_rounded,
            color: selected
                ? AppColorTokens.primary
                : AppColorTokens.textTertiary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColorTokens.textSecondary,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
