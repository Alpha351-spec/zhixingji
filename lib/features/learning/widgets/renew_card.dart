import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

/// 续订卡片（滚动7天计划 - 本周完成后的续订入口）
///
/// 包含：
/// - 完成祝贺文本
/// - 三个反馈选项按钮（太难了/太简单/节奏合适）
/// - "生成下周计划"按钮
class RenewCard extends StatefulWidget {
  /// 当前周数
  final int currentWeek;

  /// 是否还有下一周可以续订
  final bool canRenew;

  /// 续订回调，参数为用户反馈
  final void Function(String feedback) onRenew;

  /// 是否正在续订中
  final bool isRenewing;

  const RenewCard({
    super.key,
    required this.currentWeek,
    required this.canRenew,
    required this.onRenew,
    this.isRenewing = false,
  });

  @override
  State<RenewCard> createState() => _RenewCardState();
}

class _RenewCardState extends State<RenewCard> {
  String? _selectedFeedback;

  static const _feedbackOptions = [
    ('太难了', '太难了'),
    ('太简单', '太简单'),
    ('节奏合适', '节奏合适'),
  ];

  void _handleRenew() {
    final feedback = _selectedFeedback ?? '节奏合适';
    widget.onRenew(feedback);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.canRenew) {
      // 全部计划已完成
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.white,
          border: Border.all(color: AppColors.borderPlanCard, width: 1),
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Column(
          children: [
            Icon(Icons.celebration, size: 40, color: AppColors.accent),
            SizedBox(height: 12),
            Text(
              '恭喜！你已完成全部计划',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              '你真棒！可以去计划页制定新的目标了',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border.all(color: AppColors.borderPlanCard, width: 1),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题
          Center(
            child: Column(
              children: [
                const Icon(Icons.check_circle_outline,
                    size: 40, color: AppColors.accent),
                const SizedBox(height: 8),
                Text(
                  '第${widget.currentWeek}周学习完成！',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  '本周任务已全部完成，续订下一周计划吧',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 反馈选项标题
          const Text(
            '本周学习感受如何？',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),

          // 三个反馈选项按钮
          Row(
            children: _feedbackOptions.map((option) {
              final isSelected = _selectedFeedback == option.$2;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: widget.isRenewing
                        ? null
                        : () {
                            setState(() {
                              _selectedFeedback = option.$2;
                            });
                          },
                    child: Container(
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.accent
                            : AppColors.background,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Text(
                        option.$1,
                        style: TextStyle(
                          fontSize: 13,
                          color: isSelected
                              ? AppColors.white
                              : AppColors.textSecondary,
                          fontWeight:
                              isSelected ? FontWeight.w500 : FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          // 生成下周计划按钮
          Center(
            child: SizedBox(
              height: 42,
              child: ElevatedButton(
                onPressed: widget.isRenewing ? null : _handleRenew,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: AppColors.white,
                  disabledBackgroundColor: AppColors.accentLight,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(21),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                ),
                child: widget.isRenewing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.white,
                        ),
                      )
                    : const Text('生成下周计划',
                        style: AppTextStyles.pillButton),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
