import 'package:flutter/material.dart';

class AppSpacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;

  static const EdgeInsets paddingXs = EdgeInsets.all(xs);
  static const EdgeInsets paddingSm = EdgeInsets.all(sm);
  static const EdgeInsets paddingMd = EdgeInsets.all(md);
  static const EdgeInsets paddingLg = EdgeInsets.all(lg);
  static const EdgeInsets paddingXl = EdgeInsets.all(xl);

  static const EdgeInsets horizontalXs = EdgeInsets.symmetric(horizontal: xs);
  static const EdgeInsets horizontalSm = EdgeInsets.symmetric(horizontal: sm);
  static const EdgeInsets horizontalMd = EdgeInsets.symmetric(horizontal: md);
  static const EdgeInsets horizontalLg = EdgeInsets.symmetric(horizontal: lg);
  static const EdgeInsets horizontalXl = EdgeInsets.symmetric(horizontal: xl);

  static const EdgeInsets verticalXs = EdgeInsets.symmetric(vertical: xs);
  static const EdgeInsets verticalSm = EdgeInsets.symmetric(vertical: sm);
  static const EdgeInsets verticalMd = EdgeInsets.symmetric(vertical: md);
  static const EdgeInsets verticalLg = EdgeInsets.symmetric(vertical: lg);
  static const EdgeInsets verticalXl = EdgeInsets.symmetric(vertical: xl);
}

class AppRadius {
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 24.0;
}

extension TextStyleContext on BuildContext {
  TextTheme get textStyles => Theme.of(this).textTheme;
}

extension TextStyleExtensions on TextStyle {
  TextStyle get bold => copyWith(fontWeight: FontWeight.bold);
  TextStyle get semiBold => copyWith(fontWeight: FontWeight.w600);
  TextStyle get medium => copyWith(fontWeight: FontWeight.w500);
  TextStyle get normal => copyWith(fontWeight: FontWeight.w400);
  TextStyle get light => copyWith(fontWeight: FontWeight.w300);
  TextStyle withColor(Color color) => copyWith(color: color);
  TextStyle withSize(double size) => copyWith(fontSize: size);
}

// =============================================================================
// TASKASSASSIN COLOR PALETTE - Based on Logo
// =============================================================================

class AppColors {
  // Background colors - Steel Blue inspired by logo background
  static const Color background = Color(0xFF1E3A5F); // Deep steel blue
  static const Color surface = Color(0xFF254A73); // Lighter steel blue
  static const Color surfaceVariant = Color(0xFF2C5580); // Surface variant
  static const Color cardBg = Color(0xFF1A3250); // Card background

  // Primary - Steel Blue from logo
  static const Color steelBlue = Color(0xFF4A7BAD);
  static const Color steelBlueBright = Color(0xFF5B8FC4);
  static const Color steelBlueDark = Color(0xFF3A6490);

  // Secondary - Dark Navy/Charcoal (assassin cloak)
  static const Color darkNavy = Color(0xFF1A2332);
  static const Color charcoal = Color(0xFF2D3748);
  static const Color slate = Color(0xFF3D4F5F);

  // Accent - Green (checkmarks from logo)
  static const Color checkGreen = Color(0xFF22C55E);
  static const Color checkGreenBright = Color(0xFF4ADE80);
  static const Color checkGreenDark = Color(0xFF16A34A);

  // Cream/White (hood and clipboard)
  static const Color cream = Color(0xFFF5F5F0);
  static const Color offWhite = Color(0xFFE8E8E3);

  // Orange accent for streaks/fire
  static const Color accentOrange = Color(0xFFF97316);
  static const Color accentOrangeBright = Color(0xFFFB923C);

  // Purple accent for levels
  static const Color accentPurple = Color(0xFF8B5CF6);
  static const Color accentPurpleBright = Color(0xFFA78BFA);

  // Text colors
  static const Color textPrimary = Color(0xFFFFFFFF); // Pure white
  static const Color textSecondary = Color(0xFFE0E9F2); // Very light steel
  static const Color textMuted = Color(0xFFB0C4D9); // Brighter blue-gray

  // Border colors
  static const Color border = Color(0xFF3A5170);
  static const Color borderBright = Color(0xFF4A6A8A);

  // Error
  static const Color error = Color(0xFFF87171);
  static const Color errorDark = Color(0xFFEF4444);

  // Legacy aliases for backward compatibility with existing code
  static const Color neonTeal = steelBlue;
  static const Color neonTealBright = steelBlueBright;
  static const Color neonTealDark = steelBlueDark;
  static const Color neonGreen = checkGreen;
  static const Color neonGreenBright = checkGreenBright;
  static const Color neonOrange = accentOrange;
  static const Color neonOrangeBright = accentOrangeBright;
  static const Color neonPurple = accentPurple;
  static const Color neonPurpleBright = accentPurpleBright;
  static const Color neonMagenta = accentPurple;
  static const Color neonPink = accentPurpleBright;
  static const Color neonPinkDark = accentPurple;
}

// Keep CyberpunkColors as alias for backward compatibility
typedef CyberpunkColors = AppColors;

class FontSizes {
  static const double displayLarge = 57.0;
  static const double displayMedium = 45.0;
  static const double displaySmall = 36.0;
  static const double headlineLarge = 32.0;
  static const double headlineMedium = 28.0;
  static const double headlineSmall = 24.0;
  static const double titleLarge = 22.0;
  static const double titleMedium = 16.0;
  static const double titleSmall = 14.0;
  static const double labelLarge = 14.0;
  static const double labelMedium = 12.0;
  static const double labelSmall = 11.0;
  static const double bodyLarge = 16.0;
  static const double bodyMedium = 14.0;
  static const double bodySmall = 12.0;
}

// =============================================================================
// THEMES
// =============================================================================

ThemeData get lightTheme => ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(0xFFF7FAF9),
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF0B8F87),
        brightness: Brightness.light,
        primary: const Color(0xFF0B8F87),
        secondary: const Color(0xFFFF7A66),
        surface: Colors.white,
        onSurface: const Color(0xFF17324D),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFF7FAF9),
        foregroundColor: Color(0xFF17324D),
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF0B8F87),
          foregroundColor: Colors.white,
          minimumSize: const Size(48, 52),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF17324D),
          minimumSize: const Size(48, 52),
          side: const BorderSide(color: Color(0xFFB9C9C8)),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFC9D7D6)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF0B8F87), width: 2),
        ),
      ),
      navigationBarTheme: const NavigationBarThemeData(
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(
              color: Color(0xFF17324D),
              fontSize: 12,
              fontWeight: FontWeight.w700),
        ),
      ),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: Color(0xFF17324D)),
        titleLarge: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: Color(0xFF17324D)),
        titleMedium: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Color(0xFF17324D)),
        bodyLarge: TextStyle(fontSize: 16, color: Color(0xFF17324D)),
        bodyMedium: TextStyle(fontSize: 14, color: Color(0xFF526879)),
        bodySmall: TextStyle(fontSize: 12, color: Color(0xFF667684)),
        labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
      ),
    );

ThemeData get darkTheme => ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: CyberpunkColors.background,
      colorScheme: ColorScheme.dark(
        primary: CyberpunkColors.neonTeal,
        onPrimary: CyberpunkColors.background,
        primaryContainer: CyberpunkColors.neonTealDark,
        onPrimaryContainer: CyberpunkColors.neonTealBright,
        secondary: CyberpunkColors.neonPurple,
        onSecondary: Colors.white,
        secondaryContainer: CyberpunkColors.neonPurple.withValues(alpha: 0.2),
        onSecondaryContainer: CyberpunkColors.neonPurpleBright,
        tertiary: CyberpunkColors.neonGreen,
        onTertiary: CyberpunkColors.background,
        error: CyberpunkColors.error,
        onError: CyberpunkColors.background,
        errorContainer: CyberpunkColors.errorDark.withValues(alpha: 0.2),
        onErrorContainer: CyberpunkColors.error,
        surface: CyberpunkColors.surface,
        onSurface: CyberpunkColors.textPrimary,
        surfaceContainerHighest: CyberpunkColors.surfaceVariant,
        onSurfaceVariant: CyberpunkColors.textSecondary,
        outline: CyberpunkColors.border,
        shadow: Colors.black,
        inversePrimary: CyberpunkColors.neonTealBright,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: CyberpunkColors.background,
        foregroundColor: CyberpunkColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: CyberpunkColors.textPrimary,
          letterSpacing: 1.5,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: CyberpunkColors.cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: CyberpunkColors.border,
            width: 1,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: CyberpunkColors.neonTeal,
          foregroundColor: CyberpunkColors.background,
          textStyle: TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: CyberpunkColors.neonTeal,
          side: BorderSide(color: CyberpunkColors.neonTeal),
          textStyle: TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: CyberpunkColors.neonTeal,
          textStyle: TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: CyberpunkColors.surfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: CyberpunkColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: CyberpunkColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: CyberpunkColors.neonTeal, width: 2),
        ),
        hintStyle: TextStyle(color: CyberpunkColors.textMuted),
        labelStyle: TextStyle(color: CyberpunkColors.textSecondary),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: CyberpunkColors.surfaceVariant,
        selectedColor: CyberpunkColors.neonTeal.withValues(alpha: 0.2),
        labelStyle: TextStyle(
          color: CyberpunkColors.textSecondary,
          letterSpacing: 1.0,
        ),
        side: BorderSide(color: CyberpunkColors.border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: CyberpunkColors.border,
        thickness: 1,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: CyberpunkColors.neonTeal,
        linearTrackColor: CyberpunkColors.border,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: CyberpunkColors.cardBg,
        contentTextStyle: TextStyle(
          color: CyberpunkColors.textPrimary,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: CyberpunkColors.neonTeal),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: CyberpunkColors.surface,
        selectedItemColor: CyberpunkColors.neonGreen,
        unselectedItemColor: CyberpunkColors.textMuted,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.0,
        ),
        unselectedLabelStyle: TextStyle(
          fontSize: 10,
          letterSpacing: 1.0,
        ),
      ),
      textTheme: _buildTextTheme(),
    );

TextTheme _buildTextTheme() => TextTheme(
      displayLarge: TextStyle(
        fontSize: FontSizes.displayLarge,
        fontWeight: FontWeight.w400,
        letterSpacing: 2.0,
        color: CyberpunkColors.textPrimary,
      ),
      displayMedium: TextStyle(
        fontSize: FontSizes.displayMedium,
        fontWeight: FontWeight.w400,
        letterSpacing: 1.5,
        color: CyberpunkColors.textPrimary,
      ),
      displaySmall: TextStyle(
        fontSize: FontSizes.displaySmall,
        fontWeight: FontWeight.w400,
        letterSpacing: 1.5,
        color: CyberpunkColors.textPrimary,
      ),
      headlineLarge: TextStyle(
        fontSize: FontSizes.headlineLarge,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.5,
        color: CyberpunkColors.textPrimary,
      ),
      headlineMedium: TextStyle(
        fontSize: FontSizes.headlineMedium,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.2,
        color: CyberpunkColors.textPrimary,
      ),
      headlineSmall: TextStyle(
        fontSize: FontSizes.headlineSmall,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.2,
        color: CyberpunkColors.textPrimary,
      ),
      titleLarge: TextStyle(
        fontSize: FontSizes.titleLarge,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.2,
        color: CyberpunkColors.textPrimary,
      ),
      titleMedium: TextStyle(
        fontSize: FontSizes.titleMedium,
        fontWeight: FontWeight.w500,
        letterSpacing: 1.0,
        color: CyberpunkColors.textPrimary,
      ),
      titleSmall: TextStyle(
        fontSize: FontSizes.titleSmall,
        fontWeight: FontWeight.w500,
        letterSpacing: 1.0,
        color: CyberpunkColors.textPrimary,
      ),
      labelLarge: TextStyle(
        fontSize: FontSizes.labelLarge,
        fontWeight: FontWeight.w500,
        letterSpacing: 1.5,
        color: CyberpunkColors.textPrimary,
      ),
      labelMedium: TextStyle(
        fontSize: FontSizes.labelMedium,
        fontWeight: FontWeight.w500,
        letterSpacing: 1.5,
        color: CyberpunkColors.textSecondary,
      ),
      labelSmall: TextStyle(
        fontSize: FontSizes.labelSmall,
        fontWeight: FontWeight.w500,
        letterSpacing: 1.5,
        color: CyberpunkColors.textSecondary,
      ),
      bodyLarge: TextStyle(
        fontSize: FontSizes.bodyLarge,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.15,
        color: CyberpunkColors.textPrimary,
      ),
      bodyMedium: TextStyle(
        fontSize: FontSizes.bodyMedium,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.25,
        color: CyberpunkColors.textPrimary,
      ),
      bodySmall: TextStyle(
        fontSize: FontSizes.bodySmall,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.4,
        color: CyberpunkColors.textSecondary,
      ),
    );
