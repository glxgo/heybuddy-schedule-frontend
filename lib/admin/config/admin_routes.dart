import 'package:go_router/go_router.dart';

import '../screens/admin_dashboard_screen.dart';
import '../screens/admin_gate_screen.dart';
import '../screens/admin_login_screen.dart';
import '../screens/admin_users_screen.dart';
import '../screens/admin_announcements_screen.dart';

final GoRouter adminRouter = GoRouter(
  routes: [
    GoRoute(path: '/', builder: (c, s) => const AdminGateScreen()),
    GoRoute(path: '/gate', builder: (c, s) => const AdminGateScreen()),
    GoRoute(path: '/login', builder: (c, s) => const AdminLoginScreen()),
    GoRoute(path: '/dashboard', builder: (c, s) => const AdminDashboardScreen()),
    GoRoute(path: '/users', builder: (c, s) => const AdminUsersScreen()),
    GoRoute(path: '/announcements', builder: (c, s) => const AdminAnnouncementsScreen()),
  ],
);
