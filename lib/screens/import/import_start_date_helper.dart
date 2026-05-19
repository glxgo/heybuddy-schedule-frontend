import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../providers/schedule_provider.dart';

Future<void> promptForMissingStartDateIfNeeded(
  BuildContext context,
  WidgetRef ref,
  ImportCoursesResult result,
) async {
  if (!result.needsStartDatePrompt || !context.mounted) return;

  final shouldSetNow = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('设置开学日期'),
      content: const Text('当前导入的课表还没有开学日期，不设置的话当前周可能会算错哦。'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('稍后再说'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('现在设置'),
        ),
      ],
    ),
  );
  if (shouldSetNow != true || !context.mounted) return;

  final picked = await showDatePicker(
    context: context,
    initialDate: DateTime(DateTime.now().year, 2, 17),
    firstDate: DateTime(2020),
    lastDate: DateTime(2035),
    helpText: '选择开学日期',
  );
  if (picked == null) return;

  await ref.read(scheduleProvider.notifier).updateTable(
        result.targetTableId,
        startDate: DateFormat('yyyy-MM-dd').format(picked),
      );
  if (!context.mounted) return;

  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('开学日期已设置')),
  );
}
