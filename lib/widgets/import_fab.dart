import 'package:flutter/material.dart';
import '../config/theme.dart';

class ImportFab extends StatefulWidget {
  final VoidCallback onPressed;
  const ImportFab({super.key, required this.onPressed});

  @override
  State<ImportFab> createState() => _ImportFabState();
}

class _ImportFabState extends State<ImportFab> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final disableAnimations = MediaQuery.of(context).disableAnimations;

    return Semantics(
      button: true,
      label: '导入课表',
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) {
          setState(() => _pressed = false);
          widget.onPressed();
        },
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed && !disableAnimations ? 0.94 : 1,
          duration: disableAnimations
              ? Duration.zero
              : const Duration(milliseconds: 150),
          curve: Curves.easeOutCubic,
          child: Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [
                  AppColorTokens.primary,
                  AppColorTokens.primaryGradientEnd,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(color: Colors.white.withAlpha(150), width: 1),
              boxShadow: [
                BoxShadow(
                  color: AppColorTokens.primary.withAlpha(85),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
                BoxShadow(
                  color: AppColorTokens.primaryGradientEnd.withAlpha(55),
                  blurRadius: 36,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: const Icon(Icons.add_rounded, color: Colors.white, size: 30),
          ),
        ),
      ),
    );
  }
}
