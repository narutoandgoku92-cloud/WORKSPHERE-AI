import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:work_sphere_ai/screens/login_screen.dart';
import 'package:work_sphere_ai/screens/register_screen.dart';
import 'package:work_sphere_ai/screens/check_in_screen.dart';
import 'package:work_sphere_ai/screens/admin_dashboard_screen.dart';
import 'package:work_sphere_ai/screens/employee_dashboard_screen.dart';
import 'package:work_sphere_ai/screens/face_enrollment_screen.dart';
import 'package:work_sphere_ai/screens/face_recognition_screen.dart';
import 'package:work_sphere_ai/screens/gps_verification_screen.dart';
import 'package:work_sphere_ai/screens/profile_screen.dart';
import 'package:work_sphere_ai/screens/settings_screen.dart';
import 'package:work_sphere_ai/providers/auth_provider.dart';

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
    final themeSeed = const Color(0xFF5B37FF);
    final lightColorScheme = ColorScheme.fromSeed(seedColor: themeSeed, brightness: Brightness.light);
    final darkColorScheme = ColorScheme.fromSeed(seedColor: themeSeed, brightness: Brightness.dark);

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
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: lightColorScheme,
        scaffoldBackgroundColor: const Color(0xFFF5F6FF),
        appBarTheme: AppBarTheme(
          backgroundColor: lightColorScheme.primary,
          foregroundColor: lightColorScheme.onPrimary,
          elevation: 0,
          centerTitle: true,
          iconTheme: IconThemeData(color: lightColorScheme.onPrimary),
          titleTextStyle: TextStyle(
            color: lightColorScheme.onPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 4,
          margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: lightColorScheme.primary,
            foregroundColor: lightColorScheme.onPrimary,
            elevation: 3,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            minimumSize: const Size(double.infinity, 52),
            textStyle: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            side: BorderSide(color: lightColorScheme.primary.withOpacity(0.85)),
            foregroundColor: lightColorScheme.primary,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: lightColorScheme.primary, width: 2),
          ),
          hintStyle: TextStyle(color: Colors.grey.shade500),
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: lightColorScheme.primary,
          contentTextStyle: TextStyle(color: lightColorScheme.onPrimary),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        dividerTheme: DividerThemeData(color: Colors.grey.shade300, thickness: 1),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: darkColorScheme,
        scaffoldBackgroundColor: const Color(0xFF10101A),
        appBarTheme: AppBarTheme(
          backgroundColor: darkColorScheme.surfaceContainerHighest,
          foregroundColor: darkColorScheme.onSurface,
          elevation: 0,
          centerTitle: true,
          iconTheme: IconThemeData(color: darkColorScheme.onSurface),
          titleTextStyle: TextStyle(
            color: darkColorScheme.onSurface,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF151625),
          elevation: 4,
          margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: darkColorScheme.primary,
            foregroundColor: darkColorScheme.onPrimary,
            elevation: 3,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            minimumSize: const Size(double.infinity, 52),
            textStyle: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            side: BorderSide(color: darkColorScheme.primary.withOpacity(0.85)),
            foregroundColor: darkColorScheme.onPrimary,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF14141F),
          contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.grey.shade800),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: darkColorScheme.primary, width: 2),
          ),
          hintStyle: TextStyle(color: Colors.grey.shade500),
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: darkColorScheme.primary,
          contentTextStyle: TextStyle(color: darkColorScheme.onPrimary),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        dividerTheme: DividerThemeData(color: Colors.grey.shade800, thickness: 1),
      ),
    );
  }
}
