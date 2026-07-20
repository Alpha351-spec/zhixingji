import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

/// 快捷选项胶囊组件
///
/// 用于 AI 问完每天可用时间后，展示截止日期和周期选择的快捷选项。
/// 两种模式：
/// - [QuickChoiceMode.deadline]：显示"有，我填个日期"和"没有，长期学习"
/// - [QuickChoiceMode.duration]：显示 14/30/60/90/120 天选项
class QuickChoices extends StatelessWidget {
  final QuickChoiceMode mode;
  final ValueChanged<String> onSelect;

  const QuickChoices({
    super.key,
    required this.mode,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    if (mode == QuickChoiceMode.deadline) {
      return _buildDeadlineChoices();
    } else {
      return _buildDurationChoices();
    }
  }

  /// 截止日期选择：两个胶囊
  Widget _buildDeadlineChoices() {
    return Align(
      alignment: Alignment.centerRight,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _pill('有，我填个日期', () => onSelect('有截止日期')),
          _pill('没有，长期学习', () => onSelect('没有，长期学习')),
        ],
      ),
    );
  }

  /// 周期选择：14/30/60/90/120 天
  ///
  /// 短期(14/30天)按天生成任务，长期(60/90/120天)按周生成任务
  Widget _buildDurationChoices() {
    final durations = [14, 30, 60, 90, 120];
    return Align(
      alignment: Alignment.centerRight,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: durations.map((d) {
          final label = d >= 60
              ? '$d 天（约${(d / 7).round()}周）'
              : '$d 天';
          return _pill(label, () => onSelect('$d 天'));
        }).toList(),
      ),
    );
  }

  Widget _pill(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.bubbleUser,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

/// 快捷选项模式
enum QuickChoiceMode {
  /// 截止日期选择（有/没有）
  deadline,

  /// 周期选择（14/30/60/90/120天）
  duration,
}
