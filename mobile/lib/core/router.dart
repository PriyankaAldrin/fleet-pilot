import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../core/models.dart';
import '../features/admin/admin_shell.dart';
import '../features/admin/dashboard_screen.dart';
import '../features/admin/people_screens.dart';
import '../features/admin/reports_screen.dart';
import '../features/admin/shift_detail_screen.dart';
import '../features/admin/shifts_screen.dart';
import '../features/admin/vehicles_screen.dart';
import '../features/auth/auth_controller.dart';
import '../features/auth/login_screen.dart';
import '../features/common/settings_screen.dart';
import '../features/driver/driver_home_screen.dart';
import '../features/driver/select_vehicle_screen.dart';
import '../features/driver/shift_history_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.read(authControllerProvider.notifier);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: auth.changes,
    redirect: (context, state) {
      final s = ref.read(authControllerProvider);
      final path = state.matchedLocation;
      if (s is AuthUnknown) return path == '/' ? null : '/';
      if (s is SignedOut) return path == '/login' ? null : '/login';
      final user = (s as SignedIn).user;
      final home = user.isAdmin ? '/admin' : '/driver';
      if (path == '/' || path == '/login') return home;
      // Keep each role inside its own area.
      if (path.startsWith('/admin') && !user.isAdmin) return home;
      if (path.startsWith('/driver') && user.isAdmin) return home;
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (_, _) => const Scaffold(body: Center(child: CircularProgressIndicator()))),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
      GoRoute(
        path: '/driver',
        builder: (_, _) => const DriverHomeScreen(),
        routes: [
          GoRoute(path: 'vehicles', builder: (_, _) => const SelectVehicleScreen()),
          GoRoute(path: 'history', builder: (_, _) => const ShiftHistoryScreen()),
        ],
      ),
      ShellRoute(
        builder: (context, state, child) => AdminShell(location: state.matchedLocation, child: child),
        routes: [
          GoRoute(path: '/admin', builder: (_, _) => const DashboardScreen()),
          GoRoute(
            path: '/admin/shifts',
            builder: (_, state) => ShiftsScreen(
              key: ValueKey(state.uri.query),
              reviewOnly: state.uri.queryParameters['review'] == '1',
            ),
          ),
          GoRoute(path: '/admin/drivers', builder: (_, _) => const DriversScreen()),
          GoRoute(path: '/admin/vehicles', builder: (_, _) => const VehiclesScreen()),
          GoRoute(path: '/admin/admins', builder: (_, _) => const AdminsScreen()),
          GoRoute(path: '/admin/reports', builder: (_, _) => const ReportsScreen()),
        ],
      ),
      // Detail and form screens open full screen above the shell.
      GoRoute(
        path: '/admin/shifts/:id',
        builder: (_, state) => ShiftDetailScreen(id: int.parse(state.pathParameters['id']!)),
      ),
      GoRoute(path: '/admin/drivers/edit', builder: (_, state) => DriverFormScreen(driver: state.extra as Driver?)),
      GoRoute(path: '/admin/vehicles/edit', builder: (_, state) => VehicleFormScreen(vehicle: state.extra as Vehicle?)),
      GoRoute(path: '/admin/admins/edit', builder: (_, state) => AdminFormScreen(admin: state.extra as Admin?)),
    ],
  );
});
