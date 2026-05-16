import 'package:flutter/material.dart';

// ============================================================================
// COLOR PALETTE
// ============================================================================

class AppColors {
  // Primary Colors
  static const Color primaryCyan = Color(0xFF4D7CFF);
  static const Color primaryBlue = Color(0xFF3B5BFF);
  static const Color primaryTeal = Color(0xFF00C7B8);
  static const Color accentOrange = Color(0xFFFFA726);
  static const Color surfaceCard = Color(0xFFF7F9FF);
  static const Color background = Color(0xFFF4F7FF);

  // Secondary Colors
  static const Color successEmerald = Color(0xFF22C55E);
  static const Color alertRose = Color(0xFFFB7185);
  static const Color warningAmber = Color(0xFFF59E0B);
  static const Color infoSky = Color(0xFF3B82F6);

  // Neutrals
  static const Color gray900 = Color(0xFF0F172A);
  static const Color gray800 = Color(0xFF1E293B);
  static const Color gray700 = Color(0xFF334155);
  static const Color gray600 = Color(0xFF475569);
  static const Color gray500 = Color(0xFF64748B);
  static const Color gray400 = Color(0xFF94A3B8);
  static const Color gray300 = Color(0xFFCBD5E1);
  static const Color gray200 = Color(0xFFE2E8F0);
  static const Color gray100 = Color(0xFFF1F5F9);
  static const Color gray50 = Color(0xFFF8FAFC);

  // Functional Colors
  static const Color errorRed = Color(0xFFEF4444);
  static const Color successGreen = Color(0xFF16A34A);
  static const Color warningOrangeAlt = Color(0xFFF97316);
  static const Color infoBlueAlt = Color(0xFF2563EB);
}

// ============================================================================
// TYPOGRAPHY
// ============================================================================

class AppTypography {

  // Display
  static const TextStyle displayLarge = TextStyle(
    fontSize: 48,
    fontWeight: FontWeight.bold,
    letterSpacing: -1.5,
  );

  static const TextStyle displayMedium = TextStyle(
    fontSize: 36,
    fontWeight: FontWeight.bold,
    letterSpacing: -0.5,
  );

  // Heading
  static const TextStyle headingLarge = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle headingMedium = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle headingSmall = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
  );

  // Body
  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.normal,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.normal,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.normal,
  );

  // Label
  static const TextStyle labelLarge = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
  );

  static const TextStyle labelMedium = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.4,
  );

  static const TextStyle labelSmall = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.3,
  );
}

// ============================================================================
// SPACING SYSTEM
// ============================================================================

class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;
  static const double huge = 64;
}

// ============================================================================
// BORDER RADIUS
// ============================================================================

class AppBorderRadius {
  static const double sm = 4;
  static const double md = 8;
  static const double lg = 12;
  static const double xl = 16;
  static const double full = 9999;
}

// ============================================================================
// SHADOWS
// ============================================================================

class AppShadows {
  static const BoxShadow none = BoxShadow(color: Colors.transparent);

  static const BoxShadow sm = BoxShadow(
    color: Color.fromRGBO(0, 0, 0, 0.05),
    blurRadius: 2,
    offset: Offset(0, 1),
  );

  static const BoxShadow md = BoxShadow(
    color: Color.fromRGBO(0, 0, 0, 0.1),
    blurRadius: 4,
    offset: Offset(0, 2),
  );

  static const BoxShadow lg = BoxShadow(
    color: Color.fromRGBO(0, 0, 0, 0.15),
    blurRadius: 12,
    offset: Offset(0, 4),
  );

  static const BoxShadow xl = BoxShadow(
    color: Color.fromRGBO(0, 0, 0, 0.2),
    blurRadius: 20,
    offset: Offset(0, 8),
  );

  static const List<BoxShadow> glowCyan = [
    BoxShadow(
      color: Color.fromRGBO(0, 217, 255, 0.3),
      blurRadius: 20,
      spreadRadius: 0,
    ),
  ];
}

// ============================================================================
// THEME DATA
// ============================================================================

class AppTheme {
  // Light Theme
  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    fontFamily: 'Inter',
    colorScheme: const ColorScheme.light(
      primary: AppColors.primaryBlue,
      secondary: AppColors.primaryTeal,
      tertiary: AppColors.accentOrange,
      surface: AppColors.surfaceCard,
      background: AppColors.background,
      error: AppColors.errorRed,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: AppColors.gray900,
      onBackground: AppColors.gray900,
      onError: Colors.white,
    ),
    scaffoldBackgroundColor: AppColors.background,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: AppColors.gray900,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: AppTypography.headingMedium.copyWith(
        color: AppColors.gray900,
      ),
      iconTheme: const IconThemeData(color: AppColors.gray900),
    ),
    cardTheme: const CardThemeData(
      color: AppColors.surfaceCard,
      elevation: 8,
      shadowColor: Color.fromRGBO(19, 37, 92, 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(AppBorderRadius.xl)),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primaryBlue,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: AppSpacing.lg,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppBorderRadius.xl),
        ),
        elevation: 0,
        shadowColor: AppColors.primaryBlue.withOpacity(0.2),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primaryBlue,
        side: BorderSide(color: AppColors.primaryBlue.withOpacity(0.18), width: 1.75),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: AppSpacing.lg,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppBorderRadius.xl),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primaryBlue,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppBorderRadius.xl),
        borderSide: BorderSide(color: AppColors.gray300.withOpacity(0.9)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppBorderRadius.xl),
        borderSide: BorderSide(color: AppColors.gray300.withOpacity(0.9)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppBorderRadius.xl),
        borderSide: BorderSide(color: AppColors.primaryBlue, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppBorderRadius.xl),
        borderSide: const BorderSide(color: AppColors.errorRed),
      ),
      hintStyle: AppTypography.bodyMedium.copyWith(
        color: AppColors.gray500,
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Colors.white,
      elevation: 12,
      selectedItemColor: AppColors.primaryBlue,
      unselectedItemColor: AppColors.gray500,
      showSelectedLabels: true,
      showUnselectedLabels: true,
    ),
    navigationBarTheme: NavigationBarThemeData(
      elevation: 8,
      backgroundColor: Colors.white,
      indicatorColor: AppColors.primaryBlue.withOpacity(0.14),
      iconTheme: MaterialStateProperty.resolveWith((states) {
        final isSelected = states.contains(MaterialState.selected);
        return IconThemeData(
          color: isSelected ? AppColors.primaryBlue : AppColors.gray500,
        );
      }),
      labelTextStyle: MaterialStateProperty.all(
        AppTypography.labelLarge.copyWith(color: AppColors.gray900),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.primaryBlue,
      contentTextStyle: const TextStyle(color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppBorderRadius.xl)),
    ),
    dividerTheme: const DividerThemeData(color: AppColors.gray200, thickness: 1),
    textTheme: TextTheme(
      displayLarge: AppTypography.displayLarge.copyWith(color: AppColors.gray900),
      displayMedium: AppTypography.displayMedium.copyWith(color: AppColors.gray900),
      headlineLarge: AppTypography.headingLarge.copyWith(color: AppColors.gray900),
      headlineMedium: AppTypography.headingMedium.copyWith(color: AppColors.gray900),
      headlineSmall: AppTypography.headingSmall.copyWith(color: AppColors.gray900),
      bodyLarge: AppTypography.bodyLarge.copyWith(color: AppColors.gray900),
      bodyMedium: AppTypography.bodyMedium.copyWith(color: AppColors.gray700),
      bodySmall: AppTypography.bodySmall.copyWith(color: AppColors.gray600),
      labelLarge: AppTypography.labelLarge.copyWith(color: AppColors.gray900),
    ),
  );

  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    fontFamily: 'Inter',
    colorScheme: const ColorScheme.dark(
      primary: AppColors.primaryBlue,
      secondary: AppColors.primaryTeal,
      tertiary: AppColors.accentOrange,
      surface: AppColors.gray800,
      background: AppColors.gray900,
      error: AppColors.errorRed,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: AppColors.gray50,
      onBackground: AppColors.gray50,
      onError: Colors.white,
    ),
    scaffoldBackgroundColor: AppColors.gray900,
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.gray900,
      foregroundColor: AppColors.gray50,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: AppTypography.headingMedium.copyWith(color: AppColors.gray50),
      iconTheme: const IconThemeData(color: AppColors.gray50),
    ),
    cardTheme: const CardThemeData(
      color: Color(0xFF111827),
      elevation: 6,
      shadowColor: Color.fromRGBO(0, 0, 0, 0.28),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(AppBorderRadius.xl)),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primaryBlue,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.lg),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppBorderRadius.xl)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF15212C),
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppBorderRadius.xl),
        borderSide: BorderSide(color: AppColors.gray700.withOpacity(0.9)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppBorderRadius.xl),
        borderSide: BorderSide(color: AppColors.gray700.withOpacity(0.9)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppBorderRadius.xl),
        borderSide: BorderSide(color: AppColors.primaryBlue.withOpacity(0.9), width: 2),
      ),
      hintStyle: AppTypography.bodyMedium.copyWith(color: AppColors.gray400),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.gray800,
      selectedItemColor: AppColors.primaryBlue,
      unselectedItemColor: AppColors.gray400,
      elevation: 12,
      showSelectedLabels: true,
      showUnselectedLabels: true,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.primaryBlue,
      contentTextStyle: const TextStyle(color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppBorderRadius.xl)),
    ),
    textTheme: TextTheme(
      displayLarge: AppTypography.displayLarge.copyWith(color: AppColors.gray50),
      displayMedium: AppTypography.displayMedium.copyWith(color: AppColors.gray50),
      headlineLarge: AppTypography.headingLarge.copyWith(color: AppColors.gray50),
      headlineMedium: AppTypography.headingMedium.copyWith(color: AppColors.gray50),
      headlineSmall: AppTypography.headingSmall.copyWith(color: AppColors.gray50),
      bodyLarge: AppTypography.bodyLarge.copyWith(color: AppColors.gray100),
      bodyMedium: AppTypography.bodyMedium.copyWith(color: AppColors.gray200),
      bodySmall: AppTypography.bodySmall.copyWith(color: AppColors.gray300),
      labelLarge: AppTypography.labelLarge.copyWith(color: AppColors.gray100),
    ),
  );
}

// ============================================================================
// ANIMATION DURATIONS
// ============================================================================

class AppAnimationDurations {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 500);
  static const Duration verySlow = Duration(milliseconds: 1000);
}

// ============================================================================
// ANIMATION CURVES
// ============================================================================

class AppCurves {
  static const Curve easeIn = Curves.easeIn;
  static const Curve easeOut = Curves.easeOut;
  static const Curve easeInOut = Curves.easeInOut;
  static const Curve bounce = Curves.bounceOut;
  static const Curve elastic = Curves.elasticOut;
}
