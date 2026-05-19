import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import '../screens/splash_screen.dart';
import '../screens/login_screen.dart';
import '../screens/register_screen.dart';
import '../screens/school_select_screen.dart';
import '../screens/import/import_method_screen.dart';
import '../screens/import/webview_import_screen.dart';
import '../screens/import/screenshot_import_screen.dart';
import '../screens/main_shell.dart';
import '../screens/schedule/schedule_screen.dart';
import '../screens/daily/daily_screen.dart';
import '../screens/friends/friends_screen.dart';
import '../screens/chat/chat_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/schedule/table_manage_screen.dart';
import '../screens/profile/about_screen.dart';
import '../screens/profile/announcements_screen.dart';
import '../screens/forgot_password_screen.dart';
import '../screens/friends/friend_home_screen.dart';
import '../screens/friends/friend_schedule_screen.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();
final shellNavigatorKey = GlobalKey<NavigatorState>();

class _RouteArgErrorScreen extends StatelessWidget {
  final String title;
  final String message;

  const _RouteArgErrorScreen({required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14),
          ),
        ),
      ),
    );
  }
}

final GoRouter appRouter = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: '/splash',
  routes: [
    GoRoute(path: '/splash', builder: (context, state) => const SplashScreen()),
    GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
    GoRoute(
      path: '/register',
      builder: (context, state) => const RegisterScreen(),
    ),
    GoRoute(
      path: '/select-school',
      builder: (context, state) => const SchoolSelectScreen(),
    ),
    GoRoute(
      path: '/import',
      builder: (context, state) => const ImportMethodScreen(),
    ),
    GoRoute(
      path: '/import/webview',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>? ?? {};
        return WebViewImportScreen(
          schoolName: extra['schoolName'] as String? ?? '',
          systemUrl: extra['systemUrl'] as String? ?? '',
          systemType: extra['systemType'] as String? ?? 'generic',
          schoolId: extra['schoolId'] as String? ?? '',
        );
      },
    ),
    GoRoute(
      path: '/import/screenshot',
      builder: (context, state) => const ScreenshotImportScreen(),
    ),
    GoRoute(
      path: '/table-manage',
      builder: (context, state) => const TableManageScreen(),
    ),
    GoRoute(
      path: '/announcements',
      builder: (context, state) => const AnnouncementsScreen(),
    ),
    GoRoute(path: '/about', builder: (context, state) => const AboutScreen()),
    GoRoute(
      path: '/friend-home',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>? ?? {};
        final friendshipId = extra['friendshipId'] as String?;
        final friendId = extra['friendId'] as String?;
        final friendName = extra['friendName'] as String?;
        if (friendshipId == null || friendshipId.isEmpty ||
            friendId == null || friendId.isEmpty ||
            friendName == null || friendName.isEmpty) {
          return const _RouteArgErrorScreen(
            title: '好友主页',
            message: '好友信息缺失，请返回好友列表后重新进入。',
          );
        }
        return FriendHomeScreen(
          friendshipId: friendshipId,
          friendId: friendId,
          friendName: friendName,
          originalNickname: extra['originalNickname'] as String?,
          avatarUrl: extra['avatarUrl'] as String?,
          schoolName: extra['schoolName'] as String?,
        );
      },
    ),
    GoRoute(
      path: '/friend-schedule',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>? ?? {};
        final friendId = extra['friendId'] as String?;
        final friendName = extra['friendName'] as String?;
        if (friendId == null || friendId.isEmpty ||
            friendName == null || friendName.isEmpty) {
          return const _RouteArgErrorScreen(
            title: '好友课表',
            message: '好友课表参数缺失，请返回好友列表后重试。',
          );
        }
        return FriendScheduleScreen(
          friendId: friendId,
          friendName: friendName,
        );
      },
    ),
    GoRoute(
      path: '/forgot-password',
      builder: (context, state) => const ForgotPasswordScreen(),
    ),
    GoRoute(
      path: '/chat',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>? ?? {};
        final friendId = extra['friendId'] as String?;
        final friendName = extra['friendName'] as String?;
        if (friendId == null || friendId.isEmpty ||
            friendName == null || friendName.isEmpty) {
          return const _RouteArgErrorScreen(
            title: '聊天',
            message: '聊天参数缺失，请返回好友列表后重新进入。',
          );
        }
        return ChatScreen(
          friendId: friendId,
          friendName: friendName,
        );
      },
    ),
    ShellRoute(
      navigatorKey: shellNavigatorKey,
      builder: (context, state, child) => MainShell(child: child),
      routes: [
        GoRoute(
          path: '/daily',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: DailyScreen()),
        ),
        GoRoute(
          path: '/schedule',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: ScheduleScreen()),
        ),
        GoRoute(
          path: '/friends',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: FriendsScreen()),
        ),
        GoRoute(
          path: '/profile',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: ProfileScreen()),
        ),
      ],
    ),
  ],
);
