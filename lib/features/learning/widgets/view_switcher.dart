import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/constants/app_constants.dart';

/// 视图切换器（开发文档第4.1.1节）
///
/// 两个胶囊按钮："今日任务"和"专注"
/// 尺寸 90x34px，间距8px，圆角17px
/// [locked] 为 true 时禁用切换（番茄钟锁屏）
typedef ViewSwitchCallback = void Function(LearningView view);

enum LearningView { tasks, focus }

class ViewSwitcher extends StatelessWidget {
  final LearningView activeView;
  final ViewSwitchCallback onSwitch;

  /// 是否锁定（番茄钟运行时锁定）
  final bool locked;

  const ViewSwitcher({
    super.key,
    required this.activeView,
    required this.onSwitch,
    this.locked = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _pillButton('今日任务', LearningView.tasks),
          const SizedBox(width: AppConstants.switcherSpacing),
          _pillButton('专注', LearningView.focus),
        ],
      ),
    );
  }

  Widget _pillButton(String label, LearningView view) {
    final isActive = activeView == view;
    // 锁定时：非当前视图的按钮禁用
    final isDisabled = locked && !isActive;

    return GestureDetector(
      onTap: isDisabled ? null : () => onSwitch(view),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: AppConstants.switcherWidth,
        height: AppConstants.switcherHeight,
        decoration: BoxDecoration(
          color: isActive ? AppColors.accent : AppColors.white,
          border: isActive
              ? null
              : Border.all(
                  color: isDisabled
                      ? AppColors.borderCard
                      : AppColors.borderButton,
                  width: 0.5),
          borderRadius:
              BorderRadius.circular(AppConstants.switcherRadius),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: AppTextStyles.pillButton.copyWith(
            color: isActive
                ? AppColors.white
                : isDisabled
                    ? AppColors.textTertiary
                    : AppColors.textSecondary,
            fontWeight: isActive ? FontWeight.w500 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}
