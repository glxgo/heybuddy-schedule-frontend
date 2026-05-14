import 'package:flutter/material.dart';
import '../models/course.dart';
import '../config/theme.dart';

class CourseTile extends StatefulWidget {
  final Course course;
  final double height;
  final VoidCallback? onTap;

  const CourseTile({
    super.key,
    required this.course,
    this.height = 52,
    this.onTap,
  });

  @override
  State<CourseTile> createState() => _CourseTileState();
}

class _CourseTileState extends State<CourseTile> {
  bool _pressed = false;

  Color get _baseColor {
    try {
      if (widget.course.color.isEmpty || !widget.course.color.startsWith('#')) {
        return AppColorTokens.primary;
      }
      return Color(int.parse('0xFF${widget.course.color.substring(1)}'));
    } catch (_) {
      return AppColorTokens.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final base = _baseColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final disableAnimations = MediaQuery.of(context).disableAnimations;
    final showMeta = widget.height >= 62;
    final showTeacher = showMeta && widget.course.teacher.isNotEmpty;
    final showPosition = widget.course.position.isNotEmpty;

    return Semantics(
      button: widget.onTap != null,
      label:
          '${widget.course.name}${widget.course.position.isNotEmpty ? '，${widget.course.position}' : ''}，第${widget.course.startSection}到${widget.course.endSection}节',
      child: GestureDetector(
        onTapDown: widget.onTap != null
            ? (_) => setState(() => _pressed = true)
            : null,
        onTapUp: widget.onTap != null
            ? (_) {
                setState(() => _pressed = false);
                widget.onTap?.call();
              }
            : null,
        onTapCancel: widget.onTap != null
            ? () => setState(() => _pressed = false)
            : null,
        child: AnimatedScale(
          scale: _pressed && !disableAnimations ? 0.97 : 1,
          duration: disableAnimations
              ? Duration.zero
              : const Duration(milliseconds: 140),
          curve: Curves.easeOutCubic,
          child: Container(
            height: widget.height,
            margin: const EdgeInsets.all(1.5),
            padding: const EdgeInsets.fromLTRB(3, 4.5, 3, 4.5),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  base.withAlpha(isDark ? 88 : 52),
                  (isDark
                          ? AppColorTokens.darkSurfaceGlassStrong
                          : AppColorTokens.surfaceGlassStrong)
                      .withAlpha(isDark ? 190 : 210),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(11),
              border: Border.all(
                color: base.withAlpha(isDark ? 100 : 92),
                width: 0.9,
              ),
              boxShadow: [
                BoxShadow(
                  color: base.withAlpha(isDark ? 42 : 28),
                  blurRadius: 12,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 2,
                  decoration: BoxDecoration(
                    color: base,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        widget.course.name,
                        style: TextStyle(
                          fontSize: showMeta ? 11.5 : 10.5,
                          fontWeight: FontWeight.w900,
                          color: isDark
                              ? AppColorTokens.darkTextPrimary
                              : AppColorTokens.textPrimary,
                          height: 1.08,
                        ),
                        maxLines: showMeta ? 3 : 2,
                        softWrap: true,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (showPosition) ...[
                        SizedBox(height: showMeta ? 2.5 : 1.5),
                        Text(
                          widget.course.position,
                          style: TextStyle(
                            fontSize: showMeta ? 9.8 : 8.8,
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? AppColorTokens.darkTextSecondary
                                : AppColorTokens.textSecondary,
                            height: 1.05,
                          ),
                          maxLines: showMeta ? 2 : 1,
                          softWrap: true,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      if (showTeacher) ...[
                        const SizedBox(height: 2),
                        Text(
                          widget.course.teacher,
                          style: TextStyle(
                            fontSize: 8.8,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? AppColorTokens.darkTextTertiary
                                : AppColorTokens.textTertiary,
                            height: 1.05,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
