import 'package:flutter/material.dart';

class AppColorTokens {
  AppColorTokens._();

  static const Color background = Color(0xFFFFF1F2);
  static const Color backgroundGradientStart = Color(0xFFFFF7F8);
  static const Color backgroundGradientEnd = Color(0xFFF8FBFF);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceGlass = Color(0xB8FFFFFF);
  static const Color surfaceGlassStrong = Color(0xE6FFFFFF);
  static const Color primary = Color(0xFFE11D48);
  static const Color primaryGradientEnd = Color(0xFFFB7185);
  static const Color accent = Color(0xFF2563EB);
  static const Color textPrimary = Color(0xFF3B0712);
  static const Color textSecondary = Color(0xFF7F1D2D);
  static const Color textTertiary = Color(0xFF9F6470);
  static const Color divider = Color(0xFFFECDD3);
  static const Color glassBorder = Color(0x99FFFFFF);
  static const Color muted = Color(0xFFF0ECF2);
  static const Color success = Color(0xFF10B981);
  static const Color error = Color(0xFFDC2626);
  static const Color warning = Color(0xFFF59E0B);

  static const Color darkBackground = Color(0xFF12080D);
  static const Color darkBackgroundGradientStart = Color(0xFF1B0B12);
  static const Color darkBackgroundGradientEnd = Color(0xFF081226);
  static const Color darkSurface = Color(0xFF211018);
  static const Color darkSurfaceGlass = Color(0xB01F1118);
  static const Color darkSurfaceGlassStrong = Color(0xE626151D);
  static const Color darkTextPrimary = Color(0xFFFFF1F4);
  static const Color darkTextSecondary = Color(0xFFFFB6C3);
  static const Color darkTextTertiary = Color(0xFFC98A98);
  static const Color darkDivider = Color(0xFF4B2530);
  static const Color darkGlassBorder = Color(0x26FFFFFF);
}

class AppBackgroundTheme {
  final String id;
  final String label;
  final Color start;
  final Color end;
  final Color orbPrimary;
  final Color orbSecondary;
  final Color orbAccent;

  const AppBackgroundTheme({
    required this.id,
    required this.label,
    required this.start,
    required this.end,
    required this.orbPrimary,
    required this.orbSecondary,
    required this.orbAccent,
  });
}

class AppBackgroundThemes {
  AppBackgroundThemes._();

  static const defaultId = 'pink_sky';

  static const themes = [
    AppBackgroundTheme(
      id: 'pink_sky',
      label: '粉雾青空',
      start: Color.fromRGBO(248, 233, 240, 1),
      end: Color.fromRGBO(224, 247, 250, 1),
      orbPrimary: Color.fromRGBO(251, 113, 133, 0.26),
      orbSecondary: Color.fromRGBO(37, 99, 235, 0.18),
      orbAccent: Color.fromRGBO(255, 255, 255, 0.18),
    ),
    AppBackgroundTheme(
      id: 'mint_lemon',
      label: '奶绿柠黄',
      start: Color.fromRGBO(232, 245, 233, 1),
      end: Color.fromRGBO(255, 249, 196, 1),
      orbPrimary: Color.fromRGBO(129, 199, 132, 0.24),
      orbSecondary: Color.fromRGBO(255, 235, 59, 0.18),
      orbAccent: Color.fromRGBO(255, 255, 255, 0.16),
    ),
    AppBackgroundTheme(
      id: 'lavender_peach',
      label: '紫芋蜜桃',
      start: Color.fromRGBO(243, 229, 245, 1),
      end: Color.fromRGBO(252, 228, 236, 1),
      orbPrimary: Color.fromRGBO(171, 71, 188, 0.22),
      orbSecondary: Color.fromRGBO(244, 143, 177, 0.18),
      orbAccent: Color.fromRGBO(255, 255, 255, 0.18),
    ),
    AppBackgroundTheme(
      id: 'sea_mint',
      label: '浅海薄荷',
      start: Color.fromRGBO(227, 242, 253, 1),
      end: Color.fromRGBO(224, 242, 241, 1),
      orbPrimary: Color.fromRGBO(100, 181, 246, 0.22),
      orbSecondary: Color.fromRGBO(77, 208, 225, 0.18),
      orbAccent: Color.fromRGBO(255, 255, 255, 0.16),
    ),
  ];

  static AppBackgroundTheme byId(String id) {
    return themes.where((theme) => theme.id == id).firstOrNull ?? themes.first;
  }
}

class AppTheme {
  AppTheme._();

  static ThemeData get light => _buildTheme(Brightness.light);
  static ThemeData get dark => _buildTheme(Brightness.dark);

  static ThemeData _buildTheme(Brightness brightness) {
    final isLight = brightness == Brightness.light;
    final textPrimary = isLight
        ? AppColorTokens.textPrimary
        : AppColorTokens.darkTextPrimary;
    final textSecondary = isLight
        ? AppColorTokens.textSecondary
        : AppColorTokens.darkTextSecondary;
    final textTertiary = isLight
        ? AppColorTokens.textTertiary
        : AppColorTokens.darkTextTertiary;
    final surface = isLight
        ? AppColorTokens.surfaceGlassStrong
        : AppColorTokens.darkSurfaceGlassStrong;
    final divider = isLight
        ? AppColorTokens.divider
        : AppColorTokens.darkDivider;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColorTokens.primary,
        brightness: brightness,
        primary: AppColorTokens.primary,
        secondary: AppColorTokens.primaryGradientEnd,
        tertiary: AppColorTokens.accent,
        surface: isLight ? AppColorTokens.surface : AppColorTokens.darkSurface,
        error: AppColorTokens.error,
      ),
      scaffoldBackgroundColor: isLight
          ? AppColorTokens.background
          : AppColorTokens.darkBackground,
      fontFamilyFallback: const [
        'PingFang SC',
        'Microsoft YaHei',
        'Noto Sans CJK SC',
      ],
      textTheme: TextTheme(
        titleLarge: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: textPrimary,
          height: 1.25,
        ),
        titleMedium: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: textPrimary,
          height: 1.3,
        ),
        titleSmall: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: textPrimary,
          height: 1.35,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: textPrimary,
          height: 1.5,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: textSecondary,
          height: 1.45,
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: textTertiary,
          height: 1.35,
        ),
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: textPrimary,
        ),
        labelMedium: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: textSecondary,
        ),
        labelSmall: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: textTertiary,
        ),
      ),
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: textPrimary,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        iconTheme: IconThemeData(color: textPrimary),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shadowColor: Colors.black.withAlpha(isLight ? 14 : 45),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        color: surface,
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColorTokens.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColorTokens.primary.withAlpha(90),
          disabledForegroundColor: Colors.white.withAlpha(170),
          elevation: 0,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColorTokens.primary,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
          side: BorderSide(color: divider.withAlpha(isLight ? 190 : 150)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColorTokens.primary,
          minimumSize: const Size(44, 44),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: textSecondary,
          minimumSize: const Size(44, 44),
          tapTargetSize: MaterialTapTargetSize.padded,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        labelStyle: TextStyle(
          color: textSecondary,
          fontWeight: FontWeight.w600,
        ),
        hintStyle: TextStyle(color: textTertiary),
        prefixIconColor: textTertiary,
        suffixIconColor: textTertiary,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: divider.withAlpha(isLight ? 190 : 130)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(
            color: AppColorTokens.primary,
            width: 1.4,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColorTokens.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColorTokens.error, width: 1.4),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: divider.withAlpha(isLight ? 160 : 120),
        thickness: 0.5,
        space: 0,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isLight
            ? AppColorTokens.darkSurfaceGlassStrong
            : AppColorTokens.surfaceGlassStrong,
        contentTextStyle: TextStyle(
          color: isLight ? Colors.white : AppColorTokens.textPrimary,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 0,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        contentTextStyle: TextStyle(
          color: textSecondary,
          fontSize: 14,
          height: 1.5,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: isLight
            ? AppColorTokens.surfaceGlassStrong
            : AppColorTokens.darkSurfaceGlassStrong,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: isLight
            ? AppColorTokens.surfaceGlassStrong
            : AppColorTokens.darkSurfaceGlassStrong,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        showDragHandle: true,
        dragHandleColor: textTertiary.withAlpha(120),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColorTokens.primary
              : null,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColorTokens.primary.withAlpha(90)
              : null,
        ),
      ),
    );
  }
}
