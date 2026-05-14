import 'dart:ui';
import 'package:flutter/material.dart';
import '../config/theme.dart';

class GlassCard extends StatefulWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final VoidCallback? onTap;
  final double elevation;
  final Color? tint;
  final Gradient? gradient;
  final double blur;
  final double borderOpacity;
  final bool enablePressEffect;

  const GlassCard({
    super.key,
    required this.child,
    this.borderRadius = 20,
    this.padding = const EdgeInsets.all(16),
    this.margin = EdgeInsets.zero,
    this.onTap,
    this.elevation = 1,
    this.tint,
    this.gradient,
    this.blur = 20,
    this.borderOpacity = 0.55,
    this.enablePressEffect = true,
  });

  @override
  State<GlassCard> createState() => _GlassCardState();
}

class _GlassCardState extends State<GlassCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final disableAnimations = MediaQuery.of(context).disableAnimations;
    final baseTint =
        widget.tint ??
        (isDark
            ? AppColorTokens.darkSurfaceGlassStrong
            : AppColorTokens.surfaceGlassStrong);
    final borderColor =
        (isDark ? AppColorTokens.darkGlassBorder : AppColorTokens.glassBorder)
            .withValues(alpha: widget.borderOpacity.clamp(0.0, 1.0));

    final card = Container(
      margin: widget.margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 70 : 18),
            blurRadius: 18 * widget.elevation,
            offset: Offset(0, 8 * widget.elevation),
          ),
          if (!isDark)
            BoxShadow(
              color: AppColorTokens.primary.withAlpha(10),
              blurRadius: 28 * widget.elevation,
              offset: Offset(0, 10 * widget.elevation),
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: widget.blur, sigmaY: widget.blur),
          child: AnimatedContainer(
            duration: disableAnimations
                ? Duration.zero
                : const Duration(milliseconds: 180),
            padding: widget.padding,
            decoration: BoxDecoration(
              color: widget.gradient == null ? baseTint : null,
              gradient: widget.gradient,
              borderRadius: BorderRadius.circular(widget.borderRadius),
              border: Border.all(color: borderColor, width: 0.8),
            ),
            child: widget.child,
          ),
        ),
      ),
    );

    if (widget.onTap == null) return card;

    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: widget.enablePressEffect
            ? (_) => setState(() => _isPressed = true)
            : null,
        onTapUp: (_) {
          if (widget.enablePressEffect) setState(() => _isPressed = false);
          widget.onTap?.call();
        },
        onTapCancel: widget.enablePressEffect
            ? () => setState(() => _isPressed = false)
            : null,
        child: AnimatedScale(
          scale: widget.enablePressEffect && _isPressed ? 0.985 : 1,
          duration: disableAnimations
              ? Duration.zero
              : const Duration(milliseconds: 150),
          curve: Curves.easeOutCubic,
          child: card,
        ),
      ),
    );
  }
}
