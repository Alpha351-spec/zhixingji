import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_text_styles.dart';

/// 东方禅意极简 · 全局主题
///
/// 无阴影，靠0.5px边框和留白区分层次
class AppTheme {
  AppTheme._();

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.background,
      fontFamily: AppTextStyles.fontFamily,

      colorScheme: const ColorScheme.light(
        primary: AppColors.accent,
        onPrimary: AppColors.white,
        surface: AppColors.card,
        onSurface: AppColors.textPrimary,
        error: AppColors.logoutRed,
      ),

      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
      ),

      cardTheme: const CardThemeData(
        color: AppColors.card,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
          side: BorderSide(color: AppColors.borderCard, width: 0.5),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: AppColors.white,
          elevation: 0,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(6)),
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.accent,
        ),
      ),

      checkboxTheme: CheckboxThemeData(
        fillColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return AppColors.accent;
          }
          return AppColors.transparent;
        }),
        side: const BorderSide(color: AppColors.checkboxBorder, width: 1.5),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(4)),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF3F0EA),
        border: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(6)),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(6)),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(6)),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      ),

      dividerTheme: const DividerThemeData(
        color: AppColors.borderCard,
        thickness: 0.5,
        space: 1,
      ),

      switchTheme: SwitchThemeData(
        thumbColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return AppColors.white;
          }
          return AppColors.white;
        }),
        trackColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return AppColors.accent;
          }
          return const Color(0xFFE8E3DA);
        }),
        trackOutlineColor: MaterialStateProperty.all(AppColors.transparent),
      ),

      sliderTheme: const SliderThemeData(
        activeTrackColor: AppColors.accent,
        inactiveTrackColor: AppColors.borderCard,
        thumbColor: AppColors.accent,
        trackHeight: 2,
      ),
    );
  }
}
