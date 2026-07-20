import 'package:flutter/material.dart';

/// 东方禅意极简 · 配色系统
///
/// 宣纸底色、墨色文字、松烟墨绿强调、朱砂红打卡完成
class AppColors {
  AppColors._();

  /// 页面底色（宣纸色）
  static const Color background = Color(0xFFF9F7F4);

  /// 卡片背景（纯白）
  static const Color card = Color(0xFFFFFFFF);

  /// 主文本（墨色）
  static const Color textPrimary = Color(0xFF2C2416);

  /// 次要文字
  static const Color textSecondary = Color(0xFF8C8070);

  /// 弱化文本
  static const Color textTertiary = Color(0xFFBFB8AE);

  /// 强调色（松烟墨绿）— 静态用，进度、按钮、选中态
  static const Color accent = Color(0xFF5B7B6A);

  /// 强调色浅色变体
  static const Color accentLight = Color(0xFF8FA89B);

  /// 打卡完成色（朱砂红）— 仅打卡完成瞬间使用
  static const Color accentComplete = Color(0xFFC8553D);

  /// 分割线 / 卡片边框
  static const Color borderCard = Color(0xFFE8E3DA);

  /// 切换器/按钮边框
  static const Color borderButton = Color(0xFFE8E3DA);

  /// 复选框未选边框
  static const Color checkboxBorder = Color(0xFFE8E3DA);

  /// 进度条底色
  static const Color progressTrack = Color(0xFFE8E3DA);

  /// AI消息气泡背景
  static const Color bubbleAI = Color(0xFFF3F0EA);

  /// 用户消息气泡背景
  static const Color bubbleUser = Color(0xFFE8EDE8);

  /// 计划卡片边框
  static const Color borderPlanCard = Color(0xFFE8E3DA);

  /// 退出登录软红
  static const Color logoutRed = Color(0xFFC8553D);

  /// 白色
  static const Color white = Color(0xFFFFFFFF);

  /// 透明
  static const Color transparent = Color(0x00000000);

  /// 底部导航未激活色
  static const Color navInactive = Color(0xFFBFB8AE);
}
