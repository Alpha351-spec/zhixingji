import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/models/task.dart';
import '../widgets/progress_banner.dart';
import '../widgets/task_card.dart';
import '../widgets/renew_card.dart';
import '../widgets/early_completion_banner.dart';

/// 今日任务视图（开发文档第4.1.2节）
///
/// 横幅卡片 → 任务列表标题 → 任务卡片 → 快捷入口
/// 集成滚动7天计划的续订功能：
/// - 本周全部完成 → 显示续订卡片
/// - 提前完成 → 显示提前完成提示条
/// 支持"今日任务"和"本周任务"两种视图切换
class TaskView extends StatelessWidget {
  /// 今日任务
  final List<Task> tasks;

  /// 本周全部任务（7个）
  final List<Task> allWeekTasks;

  /// 当前周数
  final int currentWeek;

  /// 剩余总天数
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

  /// 当前周内第几天（1-7）
  final int dayInWeek;

  /// 是否还有下一周可以续订
  final bool canRenew;

  /// 是否正在续订中
  final bool isRenewing;

  final ValueChanged<Task> onToggleTask;
  final VoidCallback onStartFocus;
  final VoidCallback onGoToPlan;

  /// 续订回调，参数为用户反馈
  final void Function(String feedback) onRenew;

  /// 调整本周计划回调，参数为用户反馈
  final void Function(String feedback) onAdjustWeek;

  /// 是否正在调整本周计划中
  final bool isAdjustingWeek;

  const TaskView({
    super.key,
    required this.tasks,
    required this.allWeekTasks,
    required this.currentWeek,
    required this.remainingDays,
    required this.completedCount,
    required this.totalCount,
    this.hasDeadline = false,
    this.daysUntilDeadline = 0,
    this.deadlineLabel = '考试',
    this.dayInWeek = 1,
    this.canRenew = true,
    this.isRenewing = false,
    this.isAdjustingWeek = false,
    required this.onToggleTask,
    required this.onStartFocus,
    required this.onGoToPlan,
    required this.onRenew,
    required this.onAdjustWeek,
  });

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return '早上好，同学';
    if (hour < 18) return '下午好，同学';
    return '晚上好，同学';
  }

  @override
  Widget build(BuildContext context) {
    // 空任务状态
    if (tasks.isEmpty && totalCount == 0) {
      return Expanded(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.assignment_outlined,
                size: 64,
                color: AppColors.textTertiary.withOpacity(0.5),
              ),
              const SizedBox(height: 16),
              const Text('还没有计划', style: AppTextStyles.subtitle),
              const SizedBox(height: 8),
              const Text('让 AI 帮你定制一个吧',
                  style: AppTextStyles.caption,
                  textAlign: TextAlign.center),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: onGoToPlan,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: AppColors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 32, vertical: 12),
                ),
                child: const Text('去定制计划', style: AppTextStyles.pillButton),
              ),
            ],
          ),
        ),
      );
    }

    final allCompleted = completedCount == totalCount && totalCount > 0;
    final isEarlyCompleted = allCompleted && dayInWeek < 7;

    return Expanded(
      child: _TaskListBody(
        tasks: tasks,
        allWeekTasks: allWeekTasks,
        currentWeek: currentWeek,
        remainingDays: remainingDays,
        completedCount: completedCount,
        totalCount: totalCount,
        hasDeadline: hasDeadline,
        daysUntilDeadline: daysUntilDeadline,
        deadlineLabel: deadlineLabel,
        dayInWeek: dayInWeek,
        canRenew: canRenew,
        isRenewing: isRenewing,
        allCompleted: allCompleted,
        isEarlyCompleted: isEarlyCompleted,
        greeting: _getGreeting(),
        onToggleTask: onToggleTask,
        onStartFocus: onStartFocus,
        onGoToPlan: onGoToPlan,
        onRenew: onRenew,
        onAdjustWeek: onAdjustWeek,
        isAdjustingWeek: isAdjustingWeek,
      ),
    );
  }
}

/// 带状态的任务列表体（管理今日/本周视图切换）
class _TaskListBody extends StatefulWidget {
  final List<Task> tasks;
  final List<Task> allWeekTasks;
  final int currentWeek;
  final int remainingDays;
  final int completedCount;
  final int totalCount;
  final bool hasDeadline;
  final int daysUntilDeadline;
  final String deadlineLabel;
  final int dayInWeek;
  final bool canRenew;
  final bool isRenewing;
  final bool allCompleted;
  final bool isEarlyCompleted;
  final String greeting;
  final ValueChanged<Task> onToggleTask;
  final VoidCallback onStartFocus;
  final VoidCallback onGoToPlan;
  final void Function(String feedback) onRenew;

  /// 调整本周计划回调
  final void Function(String feedback) onAdjustWeek;

  /// 是否正在调整本周计划中
  final bool isAdjustingWeek;

  const _TaskListBody({
    required this.tasks,
    required this.allWeekTasks,
    required this.currentWeek,
    required this.remainingDays,
    required this.completedCount,
    required this.totalCount,
    required this.hasDeadline,
    required this.daysUntilDeadline,
    required this.deadlineLabel,
    required this.dayInWeek,
    required this.canRenew,
    required this.isRenewing,
    required this.allCompleted,
    required this.isEarlyCompleted,
    required this.greeting,
    required this.onToggleTask,
    required this.onStartFocus,
    required this.onGoToPlan,
    required this.onRenew,
    required this.onAdjustWeek,
    this.isAdjustingWeek = false,
  });

  @override
  State<_TaskListBody> createState() => _TaskListBodyState();
}

class _TaskListBodyState extends State<_TaskListBody> {
  /// 0 = 今日任务，1 = 本周任务
  int _viewMode = 0;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        // 完成提示
        if (widget.allCompleted)
          const Padding(
            padding: EdgeInsets.only(bottom: 12, left: 16, right: 16),
            child: Center(
              child: Text(
                '✨ 本周目标已完成',
                style: TextStyle(fontSize: 14, color: AppColors.accent),
              ),
            ),
          ),

        // 横幅卡片
        ProgressBanner(
          greeting: widget.greeting,
          currentWeek: widget.currentWeek,
          remainingDays: widget.remainingDays,
          completedCount: widget.completedCount,
          totalCount: widget.totalCount,
          hasDeadline: widget.hasDeadline,
          daysUntilDeadline: widget.daysUntilDeadline,
          deadlineLabel: widget.deadlineLabel,
        ),

        // 任务列表标题 + 视图切换
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 视图切换胶囊
              _buildViewToggle(),
              // 周数信息
              Text(
                '第${widget.currentWeek}周 · Day ${widget.dayInWeek}',
                style: AppTextStyles.caption,
              ),
            ],
          ),
        ),

        // 任务列表
        if (_viewMode == 0)
          // 今日任务
          for (final task in widget.tasks)
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
              child: TaskCard(
                task: task,
                onToggle: () => widget.onToggleTask(task),
              ),
            )
        else
          // 本周全部任务
          for (final task in widget.allWeekTasks)
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
              child: TaskCard(
                task: task,
                onToggle: () => widget.onToggleTask(task),
                showDayLabel: true,
              ),
            ),

        // 调整本周计划按钮（未全部完成时显示）
        if (!widget.allCompleted)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Center(
              child: TextButton.icon(
                onPressed: widget.isAdjustingWeek ? null : _showAdjustWeekDialog,
                icon: widget.isAdjustingWeek
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.accent,
                        ),
                      )
                    : const Icon(Icons.tune, size: 16, color: AppColors.accent),
                label: Text(
                  widget.isAdjustingWeek ? '调整中...' : '调整本周计划',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.accent,
                  ),
                ),
              ),
            ),
          ),

        // 提前完成提示条（周末前就全部完成了）
        if (widget.isEarlyCompleted && widget.canRenew)
          EarlyCompletionBanner(
            currentDayInWeek: widget.dayInWeek,
            onRenew: () => widget.onRenew('节奏合适'),
          ),

        // 续订卡片（本周全部完成时显示）
        if (widget.allCompleted && widget.canRenew)
          RenewCard(
            currentWeek: widget.currentWeek,
            canRenew: widget.canRenew,
            onRenew: widget.onRenew,
            isRenewing: widget.isRenewing,
          ),

        // 全部计划完成提示
        if (widget.allCompleted && !widget.canRenew)
          RenewCard(
            currentWeek: widget.currentWeek,
            canRenew: false,
            onRenew: (_) {},
          ),

        const SizedBox(height: 20),
      ],
    );
  }

  /// 视图切换胶囊（今日任务 / 本周任务）
  Widget _buildViewToggle() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.progressTrack,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _toggleItem('今日任务', 0),
          _toggleItem('本周任务', 1),
        ],
      ),
    );
  }

  /// 显示调整本周计划对话框
  Future<void> _showAdjustWeekDialog() async {
    final textController = TextEditingController();
    var selectedOption = '';

    final feedback = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('调整本周计划'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'AI 将基于已完成进度，重新生成本周剩余天数的任务',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _adjustPill('节奏太紧', selectedOption, (v) {
                    setDialogState(() {
                      selectedOption = v;
                      textController.clear();
                    });
                  }),
                  _adjustPill('太简单', selectedOption, (v) {
                    setDialogState(() {
                      selectedOption = v;
                      textController.clear();
                    });
                  }),
                  _adjustPill('加练习', selectedOption, (v) {
                    setDialogState(() {
                      selectedOption = v;
                      textController.clear();
                    });
                  }),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: textController,
                decoration: const InputDecoration(
                  hintText: '或输入你的调整需求...',
                  hintStyle:
                      TextStyle(fontSize: 13, color: AppColors.textTertiary),
                  border: OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                maxLines: 2,
                onChanged: (text) {
                  setDialogState(() {
                    selectedOption = '';
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () {
                final text = textController.text.trim();
                if (text.isNotEmpty) {
                  Navigator.of(context).pop(text);
                } else if (selectedOption.isNotEmpty) {
                  Navigator.of(context).pop(selectedOption);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: AppColors.white,
              ),
              child: const Text('生成'),
            ),
          ],
        ),
      ),
    );

    if (feedback != null && feedback.isNotEmpty) {
      widget.onAdjustWeek(feedback);
    }
  }

  /// 调整选项胶囊
  Widget _adjustPill(
    String label,
    String selected,
    ValueChanged<String> onTap,
  ) {
    final isSelected = selected == label;
    return GestureDetector(
      onTap: () => onTap(label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accent : AppColors.background,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: isSelected ? AppColors.white : AppColors.textSecondary,
            fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
          ),
        ),
      ),
    );
  }

  Widget _toggleItem(String label, int index) {
    final isSelected = _viewMode == index;
    return GestureDetector(
      onTap: () => setState(() => _viewMode = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.white : AppColors.transparent,
          borderRadius: BorderRadius.circular(AppConstants.cardRadius),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
            color: isSelected ? AppColors.textPrimary : AppColors.textTertiary,
          ),
        ),
      ),
    );
  }
}
