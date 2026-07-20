import 'package:flutter/material.dart';
import 'app_colors.dart';

/// 东方禅意极简 · 文字样式
///
/// 大标题/页面标题：思源宋体（Noto Serif SC）
/// 卡片标题/正文/辅助文字：思源黑体（Noto Sans SC）
/// 番茄钟数字：系统等宽字体（Courier）
class AppTextStyles {
  AppTextStyles._();

  /// 正文字体族（思源黑体）
  static const String fontFamily = 'NotoSansSC';

  /// 标题字体族（思源宋体）
  static const String fontFamilySerif = 'NotoSerifSC';

  /// 等宽字体族（番茄钟数字）
  static const String fontFamilyMono = 'Courier';

  // ============ 标题类（宋体）============

  /// 标题 20-22px / 宋体
  static const TextStyle heading = TextStyle(
    fontFamily: fontFamilySerif,
    fontSize: 20,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
    height: 1.3,
  );

  /// 大标题 22px / 宋体
  static const TextStyle headingLarge = TextStyle(
    fontFamily: fontFamilySerif,
    fontSize: 22,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
    height: 1.3,
  );

  /// 问候语 18px / 宋体
  static const TextStyle greeting = TextStyle(
    fontFamily: fontFamilySerif,
    fontSize: 18,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
  );

  // ============ 正文类（无衬线）============

  /// 正文 15-16px
  static const TextStyle body = TextStyle(
    fontFamily: fontFamily,
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
    height: 1.5,
  );

  /// 任务标题 16px / 500
  static const TextStyle taskTitle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
  );

  /// 任务描述 14px
  static const TextStyle taskDescription = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
    height: 1.4,
  );

  /// 副标题 13px
  static const TextStyle subtitle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );

  /// 弱化文本 14px
  static const TextStyle caption = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textTertiary,
  );

  /// 胶囊按钮文字 14px / 500
  static const TextStyle pillButton = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w500,
  );

  // ============ 番茄钟（等宽衬线）============

  /// 数字计时器 56px / 等宽字体
  static const TextStyle timer = TextStyle(
    fontFamily: fontFamilyMono,
    fontSize: 56,
    fontWeight: FontWeight.w300,
    color: AppColors.textPrimary,
    height: 1,
    letterSpacing: 2,
  );

  /// 计时器副文本 14px
  static const TextStyle timerSubtitle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textTertiary,
  );

  // ============ 导航/按钮 ============

  /// 底部导航文字 12px
  static const TextStyle navLabel = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w400,
  );

  /// 快捷入口文字按钮 14px / 500
  static const TextStyle quickLink = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.accent,
  );
}
