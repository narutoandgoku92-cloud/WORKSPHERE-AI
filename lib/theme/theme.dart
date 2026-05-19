import 'package:flutter/material.dart';

// ============================================================================
// COLOR PALETTE
// ============================================================================

class AppColors {
  // Primary Colors
  static const Color primaryCyan = Color(0xFF00D9FF);
  static const Color primaryDeepNavy = Color(0xFF0F1419);
  static const Color primaryOffWhite = Color(0xFFF5F5F7);

  // Secondary Colors
  static const Color successEmerald = Color(0xFF10B981);
  static const Color alertRose = Color(0xFFF472B6);
  static const Color warningAmber = Color(0xFFF59E0B);
  static const Color infoSky = Color(0xFF0EA5E9);

  // Neutrals
  static const Color gray900 = Color(0xFF111827);
  static const Color gray800 = Color(0xFF1F2937);
  static const Color gray700 = Color(0xFF374151);
  static const Color gray600 = Color(0xFF4B5563);
  static const Color gray500 = Color(0xFF6B7280);
  static const Color gray400 = Color(0xFF9CA3AF);
  static const Color gray300 = Color(0xFFD1D5DB);
  static const Color gray200 = Color(0xFFE5E7EB);
  static const Color gray100 = Color(0xFFF3F4F6);
  static const Color gray50 = Color(0xFFFAFAFA);

  // Functional Colors
  static const Color errorRed = Color(0xFFEF4444);
  static const Color successGreen = Color(0xFF22C55E);
  static const Color warningOrange = Color(0xFFFB923C);
  static const Color infoBlue = Color(0xFF3B82F6);
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
    colorScheme: const ColorScheme.light(
      primary: AppColors.primaryCyan,
      secondary: AppColors.infoSky,
      tertiary: AppColors.successEmerald,
      surface: AppColors.primaryOffWhite,
      error: AppColors.errorRed,
      onPrimary: AppColors.primaryDeepNavy,
      onSecondary: Colors.white,
      onSurface: AppColors.gray900,
      onError: Colors.white,
    ),
    scaffoldBackgroundColor: AppColors.gray50,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: AppColors.gray900,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: AppTypography.headingMedium.copyWith(
        color: AppColors.gray900,
      ),
      iconTheme: const IconThemeData(color: AppColors.gray900),
    ),
    cardTheme: const CardThemeData(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(AppBorderRadius.lg)),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primaryCyan,
        foregroundColor: AppColors.primaryDeepNavy,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: AppSpacing.lg,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppBorderRadius.md),
        ),
        elevation: 0,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primaryCyan,
        side: const BorderSide(color: AppColors.primaryCyan, width: 2),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: AppSpacing.lg,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppBorderRadius.md),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primaryCyan,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.gray100,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppBorderRadius.md),
        borderSide: const BorderSide(color: AppColors.gray300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppBorderRadius.md),
        borderSide: const BorderSide(color: AppColors.gray300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppBorderRadius.md),
        borderSide: const BorderSide(color: AppColors.primaryCyan, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppBorderRadius.md),
        borderSide: const BorderSide(color: AppColors.errorRed),
      ),
      hintStyle: AppTypography.bodyMedium.copyWith(
        color: AppColors.gray500,
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Colors.white,
      selectedItemColor: AppColors.primaryCyan,
      unselectedItemColor: AppColors.gray500,
      elevation: 0,
      type: BottomNavigationBarType.fixed,
    ),
    textTheme: TextTheme(
      displayLarge: AppTypography.displayLarge.copyWith(
        color: AppColors.gray900,
      ),
      displayMedium: AppTypography.displayMedium.copyWith(
        color: AppColors.gray900,
      ),
      headlineLarge: AppTypography.headingLarge.copyWith(
        color: AppColors.gray900,
      ),
      headlineMedium: AppTypography.headingMedium.copyWith(
        color: AppColors.gray900,
      ),
      headlineSmall: AppTypography.headingSmall.copyWith(
        color: AppColors.gray900,
      ),
      bodyLarge: AppTypography.bodyLarge.copyWith(
        color: AppColors.gray900,
      ),
      bodyMedium: AppTypography.bodyMedium.copyWith(
        color: AppColors.gray600,
      ),
      bodySmall: AppTypography.bodySmall.copyWith(
        color: AppColors.gray500,
      ),
      labelLarge: AppTypography.labelLarge.copyWith(
        color: AppColors.gray900,
      ),
    ),
  );

  // Dark Theme (similar structure)
  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.primaryCyan,
      secondary: AppColors.infoSky,
      tertiary: AppColors.successEmerald,
      surface: AppColors.gray800,
      error: AppColors.errorRed,
      onPrimary: AppColors.gray900,
      onSecondary: AppColors.gray900,
      onSurface: AppColors.primaryOffWhite,
      onError: Colors.white,
    ),
    scaffoldBackgroundColor: AppColors.gray900,
    // ... Additional dark theme configuration
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
