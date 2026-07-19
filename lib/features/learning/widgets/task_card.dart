import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/settings_service.dart';
import '../../../data/models/task.dart';
import 'stamp_checkbox.dart';

/// 任务卡片（东方禅意极简风格）
///
/// 卡片圆角8px，0.5px边框，无阴影
/// 勾选后标题变灰+删除线
class TaskCard extends StatefulWidget {
  final Task task;
  final VoidCallback onToggle;

  /// 是否显示天数标签（本周任务视图时显示 Day N）
  final bool showDayLabel;

  const TaskCard({
    super.key,
    required this.task,
    required this.onToggle,
    this.showDayLabel = false,
  });

  @override
  State<TaskCard> createState() => _TaskCardState();
}

class _TaskCardState extends State<TaskCard> {
  bool _expanded = false;

  void _toggleExpand() {
    setState(() => _expanded = !_expanded);
  }

  String _cleanMarkdown(String text) {
    return text
        .replaceAll('**', '')
        .replaceAll('*', '')
        .replaceAll('##', '')
        .replaceAll('#', '')
        .replaceAll('`', '')
        .trim();
  }

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    final cleanedDescription = _cleanMarkdown(task.description);
    final cleanedKeywords = _cleanMarkdown(task.resourceKeywords);
    final cleanedEncouragement = _cleanMarkdown(task.encouragement);

    // 根据资源显示模式决定是否显示资源关键词和鼓励语
    final resourceMode = SettingsService.current.resourceMode;
    final showKeywords = resourceMode == '资源模式';
    final showEncouragement =
        resourceMode == '引导模式' || resourceMode == '资源模式';

    return Container(
      padding: const EdgeInsets.all(AppConstants.taskCardPadding),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppConstants.cardRadius),
        border: Border.all(color: AppColors.borderCard, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 上排：复选框 + 标题 + 展开箭头
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _checkbox(),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.showDayLabel)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          'Day ${task.day}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: AppColors.accent,
                          ),
                        ),
                      ),
                    Text(
                      _cleanMarkdown(task.title),
                      style: AppTextStyles.taskTitle.copyWith(
                        color: task.completed
                            ? AppColors.textTertiary
                            : AppColors.textPrimary,
                        decoration: task.completed
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _toggleExpand,
                child: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      size: 20,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 下排：描述
          GestureDetector(
            onTap: _toggleExpand,
            child: Padding(
              padding: const EdgeInsets.only(left: 36),
              child: AnimatedCrossFade(
                duration: const Duration(milliseconds: 200),
                crossFadeState: _expanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                firstChild: Text(
                  cleanedDescription,
                  style: AppTextStyles.taskDescription.copyWith(
                    color: AppColors.textSecondary
                        .withOpacity(task.completed ? 0.6 : 1),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                secondChild: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cleanedDescription,
                      style: AppTextStyles.taskDescription.copyWith(
                        color: AppColors.textSecondary
                            .withOpacity(task.completed ? 0.6 : 1),
                      ),
                    ),
                    if (showKeywords && cleanedKeywords.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.search,
                              size: 14,
                              color: AppColors.textTertiary,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                '资源：$cleanedKeywords',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textTertiary,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (showEncouragement && cleanedEncouragement.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Icon(
                            Icons.favorite_border,
                            size: 14,
                            color: AppColors.accent,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              cleanedEncouragement,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.accent,
                                fontWeight: FontWeight.w400,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 复选框（带印章动画）
  ///
  /// 打卡完成时播放朱砂红印章盖章动画，动画结束后印章定格替换复选框
  Widget _checkbox() {
    return StampCheckbox(
      completed: widget.task.completed,
      onTap: widget.onToggle,
    );
  }
}
