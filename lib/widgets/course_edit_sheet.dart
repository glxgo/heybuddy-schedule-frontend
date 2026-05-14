import 'package:flutter/material.dart';
import '../config/constants.dart';
import '../config/theme.dart';
import '../models/course.dart';
import 'bottom_sheet_helper.dart';
import 'glass_card.dart';
import 'spring_button.dart';

enum CourseEditMode { add, edit }

class CourseEditData {
  final String name;
  final String position;
  final String teacher;
  final int day;
  final int startSection;
  final int endSection;
  final String weeks;
  final String color;

  const CourseEditData({
    required this.name,
    this.position = '',
    this.teacher = '',
    this.day = 1,
    this.startSection = 1,
    this.endSection = 2,
    this.weeks = '1-20',
    this.color = '#5B6AF0',
  });

  factory CourseEditData.fromCourse(Course c) => CourseEditData(
    name: c.name,
    position: c.position,
    teacher: c.teacher,
    day: c.day,
    startSection: c.startSection,
    endSection: c.endSection,
    weeks: c.weeks,
    color: c.color,
  );
}

class CourseEditSheet extends StatefulWidget {
  final Course? course;
  final int prefillDay;
  final int prefillStartSection;
  final int prefillEndSection;

  const CourseEditSheet({
    super.key,
    this.course,
    this.prefillDay = 1,
    this.prefillStartSection = 1,
    this.prefillEndSection = 1,
  });

  bool get isEdit => course != null;
  CourseEditMode get mode => isEdit ? CourseEditMode.edit : CourseEditMode.add;

  @override
  State<CourseEditSheet> createState() => _CourseEditSheetState();
}

class _CourseEditSheetState extends State<CourseEditSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _positionCtrl;
  late final TextEditingController _teacherCtrl;
  late final TextEditingController _weeksCtrl;
  late int _day;
  late int _startSection;
  late int _endSection;
  late String _selectedColor;

  @override
  void initState() {
    super.initState();
    final c = widget.course;
    _nameCtrl = TextEditingController(text: c?.name ?? '');
    _positionCtrl = TextEditingController(text: c?.position ?? '');
    _teacherCtrl = TextEditingController(text: c?.teacher ?? '');
    _weeksCtrl = TextEditingController(text: c?.weeks ?? '1-20');
    _day = c?.day ?? widget.prefillDay;
    _startSection = c?.startSection ?? widget.prefillStartSection;
    _endSection = c?.endSection ?? widget.prefillEndSection;
    _selectedColor = c?.color ?? _stableColor(c?.name ?? '');
  }

  String _stableColor(String name) {
    if (name.isEmpty) return AppConstants.courseColors[0];
    return AppConstants.stableCourseColor(name);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _positionCtrl.dispose();
    _teacherCtrl.dispose();
    _weeksCtrl.dispose();
    super.dispose();
  }

  CourseEditData _buildData() => CourseEditData(
    name: _nameCtrl.text.trim(),
    position: _positionCtrl.text.trim(),
    teacher: _teacherCtrl.text.trim(),
    day: _day,
    startSection: _startSection,
    endSection: _endSection,
    weeks: _weeksCtrl.text.trim(),
    color: _selectedColor,
  );

  bool get _canSave => _nameCtrl.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final dayLabels = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    return buildAppBottomSheetFrame(
      context,
      left: 14,
      right: 14,
      top: 16,
      maxHeightFactor: 0.92,
      child: GlassCard(
        borderRadius: 28,
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
        elevation: 1.5,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 38,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: AppColorTokens.primary.withAlpha(90),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Text(
                      widget.isEdit ? '编辑课程' : '新增课程',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _nameCtrl,
                      autofocus: !widget.isEdit,
                      decoration: const InputDecoration(
                        labelText: '课程名称 *',
                        hintText: '例如：高等数学',
                        prefixIcon: Icon(Icons.book_rounded, size: 20),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _positionCtrl,
                            decoration: const InputDecoration(
                              labelText: '教室',
                              hintText: '例如：教一101',
                              prefixIcon: Icon(Icons.location_on_outlined, size: 20),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _teacherCtrl,
                            decoration: const InputDecoration(
                              labelText: '教师',
                              hintText: '例如：张三',
                              prefixIcon: Icon(Icons.person_outline, size: 20),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Text('星期：', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: SegmentedButton<int>(
                            segments: List.generate(7, (i) => ButtonSegment<int>(
                              value: i + 1,
                              label: Text(dayLabels[i], style: const TextStyle(fontSize: 11)),
                            )),
                            selected: {_day},
                            onSelectionChanged: (v) => setState(() => _day = v.single),
                            style: ButtonStyle(
                              visualDensity: VisualDensity.compact,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Text('节次：', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            initialValue: _startSection,
                            decoration: const InputDecoration(labelText: '开始节', contentPadding: EdgeInsets.symmetric(horizontal: 10)),
                            items: List.generate(12, (i) => DropdownMenuItem(value: i + 1, child: Text('${i + 1}', style: const TextStyle(fontSize: 13)))),
                            onChanged: (v) => setState(() { _startSection = v ?? 1; if (_endSection < _startSection) _endSection = _startSection; }),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 6),
                          child: Text('—', style: TextStyle(fontSize: 16, color: AppColorTokens.textTertiary)),
                        ),
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            initialValue: _endSection,
                            decoration: const InputDecoration(labelText: '结束节', contentPadding: EdgeInsets.symmetric(horizontal: 10)),
                            items: List.generate(12, (i) => DropdownMenuItem(value: i + 1, child: Text('${i + 1}', style: const TextStyle(fontSize: 13)))),
                            onChanged: (v) => setState(() => _endSection = v ?? 2),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _weeksCtrl,
                      decoration: const InputDecoration(
                        labelText: '周次',
                        hintText: '例如：1-16 或 1,3,5,7-12',
                        helperText: '支持范围和逗号分隔，如 1-16 或 1,3,5-12',
                        prefixIcon: Icon(Icons.date_range, size: 20),
                      ),
                      keyboardType: TextInputType.text,
                    ),
                    const SizedBox(height: 14),
                    const Text('课程颜色', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: AppConstants.courseColors.map((colorHex) {
                        final color = Color(int.parse('0xFF${colorHex.substring(1)}'));
                        final selected = _selectedColor == colorHex;
                        return GestureDetector(
                          onTap: () => setState(() => _selectedColor = colorHex),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: selected ? Colors.white : Colors.transparent,
                                width: 3,
                              ),
                              boxShadow: selected
                                  ? [BoxShadow(color: color.withAlpha(140), blurRadius: 12, offset: const Offset(0, 4))]
                                  : [BoxShadow(color: color.withAlpha(60), blurRadius: 4, offset: const Offset(0, 2))],
                            ),
                            child: selected
                                ? const Icon(Icons.check, color: Colors.white, size: 18)
                                : null,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (widget.isEdit)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, CourseEditAction.delete),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColorTokens.error,
                        side: const BorderSide(color: AppColorTokens.error),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('删除课程'),
                    ),
                  ),
                if (widget.isEdit) const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: SpringButton(
                    onTap: _canSave
                        ? () {
                            Navigator.pop(context, _buildData());
                          }
                        : null,
                    child: Text(widget.isEdit ? '保存修改' : '添加课程'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

enum CourseEditAction { save, delete }
