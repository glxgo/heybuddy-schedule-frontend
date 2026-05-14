import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/theme.dart';
import '../providers/settings_provider.dart';

class LiquidBackground extends ConsumerWidget {
  final Widget child;
  final bool includeSafeArea;
  final EdgeInsetsGeometry padding;

  const LiquidBackground({
    super.key,
    required this.child,
    this.includeSafeArea = false,
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final bg = AppBackgroundThemes.byId(settings.backgroundThemeId);
    final content = Padding(
      padding: padding,
      child: includeSafeArea ? SafeArea(child: child) : child,
    );

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [bg.start, bg.end],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -90,
            right: -70,
            child: _LiquidOrb(color: bg.orbPrimary, size: 220),
          ),
          Positioned(
            top: 170,
            left: -95,
            child: _LiquidOrb(color: bg.orbSecondary, size: 190),
          ),
          Positioned(
            bottom: -100,
            right: 20,
            child: _LiquidOrb(color: bg.orbAccent, size: 240),
          ),
          content,
        ],
      ),
    );
  }
}

class _LiquidOrb extends StatelessWidget {
  final Color color;
  final double size;

  const _LiquidOrb({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 42, sigmaY: 42),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
      ),
    );
  }
}
