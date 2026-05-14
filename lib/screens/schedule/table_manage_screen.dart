import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../models/course.dart';
import '../../providers/schedule_provider.dart';
import '../../widgets/bottom_sheet_helper.dart';
import '../../widgets/glass_card.dart';

class TableManageScreen extends ConsumerStatefulWidget {
  const TableManageScreen({super.key});

  @override
  ConsumerState<TableManageScreen> createState() => _TableManageScreenState();
}

class _TableManageScreenState extends ConsumerState<TableManageScreen> {
  Future<void> _createTable() async {
    final nameCtrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('新建课表'),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '输入课表名称',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, nameCtrl.text.trim()),
            child: const Text('创建'),
          ),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      await ref.read(scheduleProvider.notifier).createTable(name);
    }
  }

  Future<void> _renameTable(String id, String currentName) async {
    final nameCtrl = TextEditingController(text: currentName);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('重命名'),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '输入新名称',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, nameCtrl.text.trim()),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      await ref.read(scheduleProvider.notifier).renameTable(id, name);
    }
  }

  Future<void> _deleteTable(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除课表'),
        content: const Text('删除后该课表下的所有课程将被清除，确定删除吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColorTokens.error,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(scheduleProvider.notifier).deleteTable(id);
    }
  }

  Future<void> _showTableSettings(CourseTable table) async {
    DateTime? selectedDate = table.startDateTime;
    final weeksCtrl = TextEditingController(
      text: table.totalWeeks.toString(),
    );
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return buildAppBottomSheetFrame(
          ctx,
          alignment: Alignment.center,
          left: 16,
          right: 16,
          top: 56,
          maxWidth: 480,
          maxHeightFactor: 0.74,
          bottomNavClearance: 72,
          child: GlassCard(
            borderRadius: 28,
            padding: const EdgeInsets.all(22),
            elevation: 1.5,
            child: StatefulBuilder(
              builder: (ctx, setSheetState) {
                return SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        width: 38,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColorTokens.primary.withAlpha(90),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 22),
                      Text(
                        '课表设置 — ${table.name}',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        '开学日期',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColorTokens.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: ctx,
                            initialDate: selectedDate ?? DateTime(DateTime.now().year, 2, 17),
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2030),
                            helpText: '选择开学日期',
                          );
                          if (picked != null) {
                            setSheetState(() => selectedDate = picked);
                            final fmt = DateFormat('yyyy-MM-dd').format(picked);
                            await ref
                                .read(scheduleProvider.notifier)
                                .updateTable(table.id, startDate: fmt);
                            if (ctx.mounted) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                const SnackBar(content: Text('开学日期已更新')),
                              );
                            }
                          }
                        },
                        child: GlassCard(
                          borderRadius: 16,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.calendar_today,
                                size: 18,
                                color: AppColorTokens.primary,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                selectedDate != null
                                    ? DateFormat('yyyy年MM月dd日').format(selectedDate!)
                                    : '未设置',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: selectedDate != null
                                      ? AppColorTokens.textPrimary
                                      : AppColorTokens.textTertiary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (selectedDate != null) ...[
                        const SizedBox(height: 6),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () async {
                              setSheetState(() => selectedDate = null);
                              await ref
                                  .read(scheduleProvider.notifier)
                                  .updateTable(table.id, clearStartDate: true);
                            },
                            child: const Text(
                              '清除',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      const Text(
                        '总周数',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColorTokens.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: weeksCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          hintText: '输入学期总周数',
                          suffixText: '周',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (val) async {
                          final weeks = int.tryParse(val.trim());
                          if (weeks != null && weeks > 0 && weeks <= 30) {
                            await ref
                                .read(scheduleProvider.notifier)
                                .updateTable(table.id, totalWeeks: weeks);
                          }
                        },
                      ),
                      const SizedBox(height: 18),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(scheduleProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('管理课表')),
      body: ListView(
        children: [
          ...state.tables.map((table) {
            final isActive = table.id == state.currentTableId;
            return ListTile(
              leading: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isActive
                      ? AppColorTokens.primary.withAlpha(25)
                      : AppColorTokens.background,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isActive ? Icons.check_circle : Icons.table_chart_outlined,
                  color: isActive
                      ? AppColorTokens.primary
                      : AppColorTokens.textTertiary,
                  size: 20,
                ),
              ),
              title: Text(
                table.name,
                style: TextStyle(
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
              subtitle: Text(
                table.semester,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColorTokens.textTertiary,
                ),
              ),
              trailing: PopupMenuButton<String>(
                onSelected: (action) {
                  if (action == 'settings') _showTableSettings(table);
                  if (action == 'rename') _renameTable(table.id, table.name);
                  if (action == 'delete') _deleteTable(table.id);
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(value: 'settings', child: Text('设置')),
                  const PopupMenuItem(value: 'rename', child: Text('重命名')),
                  if (table.id != 'default')
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text(
                        '删除',
                        style: TextStyle(color: AppColorTokens.error),
                      ),
                    ),
                ],
              ),
              onTap: () {
                if (!isActive) {
                  ref.read(scheduleProvider.notifier).switchTable(table.id);
                  context.pop();
                }
              },
            );
          }),
          const Divider(),
          ListTile(
            leading: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColorTokens.primary.withAlpha(15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.add,
                color: AppColorTokens.primary,
                size: 20,
              ),
            ),
            title: const Text(
              '新建课表',
              style: TextStyle(color: AppColorTokens.primary),
            ),
            onTap: _createTable,
          ),
        ],
      ),
    );
  }
}
