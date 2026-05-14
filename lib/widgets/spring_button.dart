import 'package:flutter/material.dart';
import '../config/theme.dart';

class SpringButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double height;
  final Color? color;
  final Gradient? gradient;
  final BoxBorder? border;
  final double borderRadius;
  final bool enabled;
  final EdgeInsetsGeometry padding;

  const SpringButton({
    super.key,
    required this.child,
    this.onTap,
    this.height = 52,
    this.color,
    this.gradient,
    this.border,
    this.borderRadius = 18,
    this.enabled = true,
    this.padding = const EdgeInsets.symmetric(horizontal: 20),
  });

  @override
  State<SpringButton> createState() => _SpringButtonState();
}

class _SpringButtonState extends State<SpringButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _springCtrl;
  late final Animation<double> _scaleAnim;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _springCtrl = AnimationController(
      duration: const Duration(milliseconds: 260),
      vsync: this,
    );
    _scaleAnim = Tween<double>(begin: 1, end: 0.965).animate(
      CurvedAnimation(
        parent: _springCtrl,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeOutBack,
      ),
    );
  }

  @override
  void dispose() {
    _springCtrl.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    if (!widget.enabled) return;
    setState(() => _pressed = true);
    _springCtrl.forward();
  }

  void _onTapUp(TapUpDetails _) {
    if (!widget.enabled) return;
    setState(() => _pressed = false);
    _springCtrl.reverse().then((_) => widget.onTap?.call());
  }

  void _onTapCancel() {
    if (!widget.enabled) return;
    setState(() => _pressed = false);
    _springCtrl.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final disableAnimations = MediaQuery.of(context).disableAnimations;
    final color = widget.color ?? AppColorTokens.primary;
    final enabledGradient =
        widget.gradient ??
        const LinearGradient(
          colors: [AppColorTokens.primary, AppColorTokens.primaryGradientEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );

    return Semantics(
      button: true,
      enabled: widget.enabled,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        child: AnimatedBuilder(
          animation: _scaleAnim,
          builder: (context, child) => Transform.scale(
            scale: disableAnimations ? 1 : _scaleAnim.value,
            child: AnimatedOpacity(
              opacity: widget.enabled ? 1 : 0.48,
              duration: disableAnimations
                  ? Duration.zero
                  : const Duration(milliseconds: 160),
              child: AnimatedContainer(
                duration: disableAnimations
                    ? Duration.zero
                    : const Duration(milliseconds: 180),
                height: widget.height,
                padding: widget.padding,
                decoration: BoxDecoration(
                  color: widget.gradient == null && widget.color != null
                      ? color
                      : null,
                  gradient: widget.enabled ? enabledGradient : null,
                  borderRadius: BorderRadius.circular(widget.borderRadius),
                  border: widget.border,
                  boxShadow: _pressed || !widget.enabled
                      ? []
                      : [
                          BoxShadow(
                            color: color.withAlpha(55),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ],
                ),
                alignment: Alignment.center,
                child: DefaultTextStyle.merge(
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                  child: child!,
                ),
              ),
            ),
          ),
          child: widget.child,
        ),
      ),
    );
  }
}
