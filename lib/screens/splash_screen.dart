import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../config/theme.dart';
import '../providers/auth_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: const Interval(0.1, 0.5));
    _scale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.1, 0.7, curve: Curves.elasticOut),
      ),
    );
    _ctrl.forward();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    // Wait for auth to initialize, max 900ms
    final start = DateTime.now();
    while (DateTime.now().difference(start).inMilliseconds < 900) {
      if (!mounted) return;
      final auth = ref.read(authProvider);
      if (auth.isInitialized) break;
      await Future.delayed(const Duration(milliseconds: 50));
    }
    // Minimum splash visibility 500ms
    final elapsed = DateTime.now().difference(start).inMilliseconds;
    if (elapsed < 500) await Future.delayed(Duration(milliseconds: 500 - elapsed));
    if (!mounted) return;
    final auth = ref.read(authProvider);
    context.go(auth.isLoggedIn ? '/daily' : '/login');
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: FadeTransition(
          opacity: _fade,
          child: ScaleTransition(
            scale: _scale,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: AppColorTokens.primary.withAlpha(40),
                        blurRadius: 24,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: Image.asset(
                      'assets/images/app_icon.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  '相伴课表',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  '和好朋友一起用的课表',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColorTokens.textSecondary,
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
