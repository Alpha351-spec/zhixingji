import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/constants/app_constants.dart';

/// 提前完成提示条
///
/// 当用户在周末之前就完成了本周所有任务时显示。
/// 点击后触发续订流程。
class EarlyCompletionBanner extends StatelessWidget {
  /// 当前是第几天（1-7）
  final int currentDayInWeek;

  /// 点击续订回调
  final VoidCallback onRenew;

  const EarlyCompletionBanner({
    super.key,
    required this.currentDayInWeek,
    required this.onRenew,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.bubbleUser,
        borderRadius: BorderRadius.circular(AppConstants.cardRadius),
        border: Border.all(color: AppColors.accent.withOpacity(0.3), width: 1),
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome, size: 20, color: AppColors.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '提前完成！',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.accent,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '第${currentDayInWeek}天就完成了本周任务，要提前生成下周计划吗？',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onRenew,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Text(
                '续订',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
