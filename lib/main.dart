import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/check_in_screen.dart';
import 'screens/admin_dashboard_screen.dart';
import 'screens/employee_dashboard_screen.dart';
import 'screens/face_enrollment_screen.dart';
import 'screens/face_recognition_screen.dart';
import 'screens/gps_verification_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/payroll_dashboard_screen.dart';
import 'screens/payroll_employee_list_screen.dart';
import 'screens/payroll_bulk_payout_screen.dart';
import 'screens/payroll_transactions_screen.dart';
import 'providers/auth_provider.dart';
import 'providers/profile_provider.dart';
import 'providers/payroll_provider.dart';
import 'theme/theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    final router = GoRouter(
      initialLocation: '/',
      redirect: (context, state) {
        final isAuthenticated = authState.accessToken != null;
        final path = state.matchedLocation;

        if (!isAuthenticated && path != '/login' && path != '/register') {
          return '/login';
        }

        if (isAuthenticated && (path == '/login' || path == '/register' || path == '/')) {
          return '/dashboard';
        }

        return null;
      },
      routes: [
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: '/register',
          builder: (context, state) => const RegisterScreen(),
        ),
        GoRoute(
          path: '/gps-verification',
          builder: (context, state) => const GpsVerificationScreen(),
        ),
        GoRoute(
          path: '/face-recognition',
          builder: (context, state) => const FaceRecognitionScreen(),
        ),
        GoRoute(
          path: '/enroll-face',
          builder: (context, state) => const FaceEnrollmentScreen(),
        ),
        GoRoute(
          path: '/check-in',
          builder: (context, state) => const CheckInScreen(),
        ),
        GoRoute(
          path: '/dashboard',
          builder: (context, state) {
            final user = authState.user;
            if (user?.role == 'admin' || user?.role == 'manager') {
              return const AdminDashboardScreen();
            }
            return const EmployeeDashboardScreen();
          },
        ),
        GoRoute(
          path: '/payroll',
          builder: (context, state) => const PayrollDashboardScreen(),
        ),
        GoRoute(
          path: '/payroll/employees',
          builder: (context, state) => const PayrollEmployeeListScreen(),
        ),
        GoRoute(
          path: '/payroll/bulk',
          builder: (context, state) => const PayrollBulkPayoutScreen(),
        ),
        GoRoute(
          path: '/payroll/transactions',
          builder: (context, state) => const PayrollTransactionsScreen(),
        ),
        GoRoute(
          path: '/profile',
          builder: (context, state) => const ProfileScreen(),
        ),
        GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsScreen(),
        ),
      ],
    );

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      title: 'WorkSphere AI',
      themeMode: ThemeMode.system,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
    );
  }
}
