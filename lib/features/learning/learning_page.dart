import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/task.dart';
import 'widgets/view_switcher.dart';
import 'views/task_view.dart';
import 'views/focus_view.dart';

/// 学习页（Tab 1，开发文档第4.1节）
class LearningPage extends StatefulWidget {
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

  /// 当前周内第几天（1-7）
  final int dayInWeek;

  /// 是否有截止日期
  final bool hasDeadline;

  /// 距离截止日期剩余天数
  final int daysUntilDeadline;

  /// 截止日期描述
  final String deadlineLabel;

  /// 是否还有下一周可以续订
  final bool canRenew;

  /// 是否正在续订中
  final bool isRenewing;

  final ValueChanged<Task> onToggleTask;
  final VoidCallback onGoToPlan;

  /// 续订回调，参数为用户反馈
  final void Function(String feedback) onRenew;

  /// 调整本周计划回调，参数为用户反馈
  final void Function(String feedback) onAdjustWeek;

  /// 是否正在调整本周计划中
  final bool isAdjustingWeek;

  const LearningPage({
    super.key,
    required this.tasks,
    required this.allWeekTasks,
    required this.currentWeek,
    required this.remainingDays,
    required this.completedCount,
    required this.totalCount,
    this.dayInWeek = 1,
    this.hasDeadline = false,
    this.daysUntilDeadline = 0,
    this.deadlineLabel = '考试',
    this.canRenew = true,
    this.isRenewing = false,
    this.isAdjustingWeek = false,
    required this.onToggleTask,
    required this.onGoToPlan,
    required this.onRenew,
    required this.onAdjustWeek,
  });

  @override
  State<LearningPage> createState() => _LearningPageState();
}

class _LearningPageState extends State<LearningPage> {
  LearningView _activeView = LearningView.tasks;
  String _focusTaskTitle = '';

  /// 番茄钟锁屏状态（true 时禁用视图切换）
  bool _isFocusLocked = false;

  void _switchView(LearningView view) {
    // 锁屏时拦截视图切换
    if (_isFocusLocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('专注锁定中，无法切换视图'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    setState(() => _activeView = view);
  }

  void _startFocus() {
    if (_isFocusLocked) return;
    final unfinished = widget.tasks.where((t) => !t.completed);
    if (unfinished.isNotEmpty) {
      _focusTaskTitle = unfinished.first.title;
    }
    _switchView(LearningView.focus);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            ViewSwitcher(
              activeView: _activeView,
              onSwitch: _switchView,
              locked: _isFocusLocked,
            ),
            const SizedBox(height: 20),
            if (_activeView == LearningView.tasks)
              TaskView(
                tasks: widget.tasks,
                allWeekTasks: widget.allWeekTasks,
                currentWeek: widget.currentWeek,
                remainingDays: widget.remainingDays,
                completedCount: widget.completedCount,
                totalCount: widget.totalCount,
                hasDeadline: widget.hasDeadline,
                daysUntilDeadline: widget.daysUntilDeadline,
                deadlineLabel: widget.deadlineLabel,
                dayInWeek: widget.dayInWeek,
                canRenew: widget.canRenew,
                isRenewing: widget.isRenewing,
                onToggleTask: widget.onToggleTask,
                onStartFocus: _startFocus,
                onGoToPlan: widget.onGoToPlan,
                onRenew: widget.onRenew,
                onAdjustWeek: widget.onAdjustWeek,
                isAdjustingWeek: widget.isAdjustingWeek,
              )
            else
              FocusView(
                tasks: widget.tasks,
                currentTaskTitle: _focusTaskTitle.isNotEmpty
                    ? _focusTaskTitle
                    : (widget.tasks.isNotEmpty
                        ? widget.tasks.first.title
                        : ''),
                onReturnToTasks: () => _switchView(LearningView.tasks),
                onLockChanged: (locked) {
                  setState(() => _isFocusLocked = locked);
                },
              ),
          ],
        ),
      ),
    );
  }
}
