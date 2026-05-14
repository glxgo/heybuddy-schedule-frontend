import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../widgets/liquid_background.dart';
import '../widgets/liquid_bottom_nav.dart';

class MainShell extends StatefulWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateIndex());
  }

  void _updateIndex() {
    final location = GoRouterState.of(context).uri.toString();
    final idx = location == '/daily'
        ? 0
        : location == '/schedule'
        ? 1
        : location == '/friends'
        ? 2
        : location == '/profile'
        ? 3
        : 0;
    if (idx != _currentIndex) setState(() => _currentIndex = idx);
  }

  void _onTap(int index) {
    switch (index) {
      case 0:
        context.go('/daily');
      case 1:
        context.go('/schedule');
      case 2:
        context.go('/friends');
      case 3:
        context.go('/profile');
    }
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    _updateIndex();
    return LiquidBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBody: true,
        body: widget.child,
        bottomNavigationBar: LiquidBottomNav(
          currentIndex: _currentIndex,
          onTap: _onTap,
        ),
      ),
    );
  }
}
