import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/constants/app_constants.dart';

/// 横幅卡片（开发文档第4.1.2节）
///
/// 适配滚动7天计划：
/// - 有截止日期：显示"距离XX还有 X 天" + "第N周"
/// - 无截止日期：显示"第N周 · 剩余X天" + 进度条
class ProgressBanner extends StatelessWidget {
  final String greeting;

  /// 当前周数
  final int currentWeek;

  /// 剩余总天数（整个计划）
  final int remainingDays;

  /// 当前周已完成任务数
  final int completedCount;

  /// 当前周总任务数
  final int totalCount;

  /// 是否有截止日期
  final bool hasDeadline;

  /// 距离截止日期剩余天数
  final int daysUntilDeadline;

  /// 截止日期描述
  final String deadlineLabel;

  const ProgressBanner({
    super.key,
    required this.greeting,
    required this.currentWeek,
    required this.remainingDays,
    required this.completedCount,
    required this.totalCount,
    this.hasDeadline = false,
    this.daysUntilDeadline = 0,
    this.deadlineLabel = '考试',
  });

  @override
  Widget build(BuildContext context) {
    final progress = totalCount > 0 ? completedCount / totalCount : 0.0;

    // 副标题：始终优先用截止日期倒计时
    final String subtitle;
    final String progressText;

    if (hasDeadline) {
      if (daysUntilDeadline > 0) {
        subtitle = '距离$deadlineLabel还有 $daysUntilDeadline 天';
      } else {
        subtitle = '$deadlineLabel已到期';
      }
      progressText = '$completedCount/$totalCount';
    } else if (remainingDays > 0) {
      subtitle = '第$currentWeek周 · 剩余 $remainingDays 天';
      progressText = '$completedCount/$totalCount';
    } else {
      subtitle = '第$currentWeek周';
      progressText = '$completedCount/$totalCount';
    }

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppConstants.pageMargin,
      ),
      constraints: BoxConstraints(
        minHeight: AppConstants.bannerHeight,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppConstants.cardRadius),
        border: Border.all(color: AppColors.borderButton, width: 0.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(greeting, style: AppTextStyles.greeting),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: hasDeadline && daysUntilDeadline > 0
                        ? AppColors.accent
                        : AppColors.textSecondary,
                    fontWeight: hasDeadline && daysUntilDeadline <= 7
                        ? FontWeight.w500
                        : FontWeight.w400,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: SizedBox(
                  width: AppConstants.progressWidth,
                  height: AppConstants.progressHeight,
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: AppColors.progressTrack,
                    valueColor:
                        const AlwaysStoppedAnimation(AppColors.accent),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                progressText,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: hasDeadline && daysUntilDeadline <= 7
                      ? AppColors.accent
                      : AppColors.accent,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
