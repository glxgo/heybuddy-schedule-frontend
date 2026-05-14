import 'dart:ui';
import 'package:flutter/material.dart';
import '../config/theme.dart';

class LiquidBottomNav extends StatelessWidget {
  static const _navCyan = Color(0xFF7BA5B8);
  static const _navCyanLight = Color(0xFF9EC5D4);

  final int currentIndex;
  final ValueChanged<int> onTap;

  const LiquidBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  static const _items = [
    _LiquidNavItem(
      Icons.calendar_today_outlined,
      Icons.calendar_today_rounded,
      '每日',
    ),
    _LiquidNavItem(Icons.grid_view_outlined, Icons.grid_view_rounded, '课表'),
    _LiquidNavItem(Icons.people_outline, Icons.people_rounded, '好友'),
    _LiquidNavItem(Icons.person_outline_rounded, Icons.person_rounded, '我的'),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
            child: Container(
              height: 66,
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColorTokens.darkSurfaceGlassStrong
                    : AppColorTokens.surfaceGlass,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: isDark
                      ? AppColorTokens.darkGlassBorder
                      : AppColorTokens.glassBorder,
                  width: 0.8,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(isDark ? 80 : 18),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                children: List.generate(_items.length, (index) {
                  final item = _items[index];
                  final selected = currentIndex == index;
                  return Expanded(
                    child: _LiquidNavButton(
                      item: item,
                      selected: selected,
                      onTap: () => onTap(index),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LiquidNavButton extends StatelessWidget {
  final _LiquidNavItem item;
  final bool selected;
  final VoidCallback onTap;

  const _LiquidNavButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final disableAnimations = MediaQuery.of(context).disableAnimations;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final unselectedColor = isDark
        ? AppColorTokens.darkTextTertiary
        : AppColorTokens.textTertiary;

    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: disableAnimations
              ? Duration.zero
              : const Duration(milliseconds: 140),
          curve: Curves.easeOutCubic,
          height: 54,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: selected
                ? const LinearGradient(
                    colors: [
                      LiquidBottomNav._navCyan,
                      LiquidBottomNav._navCyanLight,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: LiquidBottomNav._navCyan.withAlpha(45),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                selected ? item.activeIcon : item.icon,
                size: 21,
                color: selected ? Colors.white : unselectedColor,
              ),
              const SizedBox(height: 2),
              Text(
                item.label,
                style: TextStyle(
                  fontSize: 10.5,
                  height: 1,
                  color: selected ? Colors.white : unselectedColor,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LiquidNavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const _LiquidNavItem(this.icon, this.activeIcon, this.label);
}
