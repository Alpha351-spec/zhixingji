import 'dart:convert';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/rate_limiter.dart';
import '../../data/models/task.dart';
import '../../data/models/current_plan.dart';
import '../../data/services/ai_service.dart';
import '../../data/services/plan_repository.dart';
import '../../features/learning/learning_page.dart';
import '../../features/plan/plan_page.dart';
import '../../features/profile/profile_page.dart';
import '../../features/verification/verification_dialog.dart';
import '../widgets/bottom_nav_bar.dart';

/// 主框架（开发文档第3节）
///
/// 滚动7天计划模式：
/// - 每周7天任务，完成后通过续订API生成下一周
/// - current_week 记录当前周数
class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _currentIndex = 0;

  /// 今日任务（显示在列表中）
  List<Task> _todayTasks = [];

  /// 本周全部任务（用于计算完成数和标记全部完成）
  List<Task> _allWeekTasks = [];
  int _currentWeek = 1;
  int _remainingDays = 0;
  int _completedCount = 0;
  int _totalCount = 0;
  int _dayInWeek = 1;
  bool _hasDeadline = false;
  String _deadline = '';
  String _deadlineLabel = '考试';
  bool _canRenew = true;

  /// 实时计算截止日期剩余天数（每次 build 时调用，确保跨天自动更新）
  /// 返回 -1 表示无截止日期，0 表示已到期，正数表示剩余天数
  int get _daysUntilDeadline {
    if (_deadline.isEmpty) return -1;
    final dl = DateTime.tryParse(_deadline);
    if (dl == null) return -1;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final deadlineDay = DateTime(dl.year, dl.month, dl.day);
    final diff = deadlineDay.difference(today).inDays;
    return diff >= 0 ? diff + 1 : 0;
  }
  bool _isRenewing = false;
  bool _isAdjustingWeek = false;

  /// 续订频率限制（60秒冷却，防止短时间内重复请求生成计划）
  final RateLimiter _renewLimiter = RateLimiter(Duration(seconds: 60));

  /// 调整本周计划频率限制（60秒冷却）
  final RateLimiter _adjustWeekLimiter = RateLimiter(Duration(seconds: 60));

  @override
  void initState() {
    super.initState();
    _loadPlanFromDb();
  }

  Future<void> _loadPlanFromDb() async {
    final plan = await PlanRepository.getCurrentPlan();
    if (mounted) {
      setState(() {
        if (plan != null) {
          _allWeekTasks = plan.tasks;
          _todayTasks = plan.todayTasks;
          _currentWeek = plan.currentWeek;
          _remainingDays = plan.remainingTotalDays;
          _completedCount = plan.completedCount;
          _totalCount = plan.tasks.length;
          _dayInWeek = plan.currentDay - (plan.currentWeek - 1) * 7;
          _hasDeadline = plan.hasDeadline;
          _deadline = plan.deadline;
          _deadlineLabel = _extractDeadlineLabel(plan.goal);
          _canRenew = plan.canRenew;
        } else {
          _allWeekTasks = [];
          _todayTasks = [];
          _currentWeek = 1;
          _remainingDays = 0;
          _completedCount = 0;
          _totalCount = 0;
          _dayInWeek = 1;
          _hasDeadline = false;
          _deadline = '';
          _canRenew = true;
        }
      });
    }
  }

  String _extractDeadlineLabel(String goal) {
    if (goal.contains('考试')) return '考试';
    if (goal.contains('面试')) return '面试';
    if (goal.contains('考证')) return '考证';
    if (goal.contains('比赛')) return '比赛';
    return '截止日';
  }

  void _toggleTask(Task task) {
    final newCompleted = !task.completed;

    // 取消完成：直接取消，无需验证
    if (!newCompleted) {
      _doToggleTask(task, false);
      return;
    }

    // 标记完成：根据验证类型决定流程
    if (task.verificationType == 'none') {
      // 无需验证，直接打卡
      _doToggleTask(task, true);
      return;
    }

    // 需要验证：打开验证页面
    _startVerification(task);
  }

  /// 执行实际的任务状态切换
  void _doToggleTask(Task task, bool completed) {
    setState(() {
      // 同时更新今日任务和全部任务
      _todayTasks = _todayTasks.map((t) {
        if (t.day == task.day) {
          return t.copyWith(completed: completed);
        }
        return t;
      }).toList();
      _allWeekTasks = _allWeekTasks.map((t) {
        if (t.day == task.day) {
          return t.copyWith(completed: completed);
        }
        return t;
      }).toList();
      _completedCount = _allWeekTasks.where((t) => t.completed).length;
    });
    PlanRepository.updateTaskCompleted(task.day, completed);
  }

  /// 启动打卡验证流程
  Future<void> _startVerification(Task task) async {
    final passed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => VerificationDialog(
          task: task,
          planId: 1,
        ),
      ),
    );

    // 验证通过（或网络失败跳过）→ 标记完成
    if (passed == true && mounted) {
      _doToggleTask(task, true);
    }
    // 验证未通过或用户关闭页面 → 不标记完成
  }

  void _switchTab(int index) {
    setState(() => _currentIndex = index);
  }

  void _onPlanGenerated() {
    _loadPlanFromDb();
    _switchTab(0);
  }

  /// 续订下一周计划
  Future<void> _handleRenew(String feedback) async {
    // 频率限制：60秒内不允许重复续订
    if (!_renewLimiter.canRequest) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '刚生成过计划，请等 ${_renewLimiter.remainingSeconds} 秒后再续订',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    setState(() => _isRenewing = true);

    final plan = await PlanRepository.getCurrentPlan();
    if (plan == null) {
      setState(() => _isRenewing = false);
      return;
    }

    final renewedPlan = await PlanRepository.renewWeek(plan, feedback);

    if (mounted) {
      if (renewedPlan != null) {
        // 成功生成 → 记录频率
        _renewLimiter.record();
        await _loadPlanFromDb();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('第${renewedPlan.currentWeek}周计划已生成！'),
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('续订失败，请稍后重试'),
            duration: Duration(seconds: 3),
          ),
        );
      }
      setState(() => _isRenewing = false);
    }
  }

  /// 调整本周计划（学习页：重新生成本周剩余天数任务）
  Future<void> _handleAdjustWeek(String feedback) async {
    // 频率限制
    if (!_adjustWeekLimiter.canRequest) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '刚调整过计划，请等 ${_adjustWeekLimiter.remainingSeconds} 秒后再试',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    setState(() => _isAdjustingWeek = true);

    final plan = await PlanRepository.getCurrentPlan();
    if (plan == null) {
      setState(() => _isAdjustingWeek = false);
      return;
    }

    try {
      // 获取已完成任务标题
      final completedTitles = plan.tasks
          .where((t) => t.completed)
          .map((t) => t.title)
          .toList();

      // 当前周内第几天
      final dayInWeek = plan.currentDay - (plan.currentWeek - 1) * 7;

      final aiResponse = await AIService.adjustWeekTasks(
        goal: plan.goal,
        diagnosisJson: jsonEncode(plan.diagnosis.toJson()),
        currentDayInWeek: dayInWeek,
        completedTaskTitles: completedTitles,
        feedback: feedback,
      );

      final adjustedPlan = await PlanRepository.adjustWeekTasksFromAI(
        aiResponse,
        plan,
      );

      if (mounted) {
        if (adjustedPlan != null) {
          _adjustWeekLimiter.record();
          await _loadPlanFromDb();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('本周计划已调整'),
              duration: Duration(seconds: 2),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('调整失败，请稍后重试'),
              duration: Duration(seconds: 3),
            ),
          );
        }
        setState(() => _isAdjustingWeek = false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('调整失败：$e'),
            duration: const Duration(seconds: 3),
          ),
        );
        setState(() => _isAdjustingWeek = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: IndexedStack(
        index: _currentIndex,
        children: [
          LearningPage(
            tasks: _todayTasks,
            allWeekTasks: _allWeekTasks,
            currentWeek: _currentWeek,
            remainingDays: _remainingDays,
            completedCount: _completedCount,
            totalCount: _totalCount,
            dayInWeek: _dayInWeek,
            hasDeadline: _hasDeadline,
            daysUntilDeadline: _daysUntilDeadline,
            deadlineLabel: _deadlineLabel,
            canRenew: _canRenew,
            isRenewing: _isRenewing,
            isAdjustingWeek: _isAdjustingWeek,
            onToggleTask: _toggleTask,
            onGoToPlan: () => _switchTab(1),
            onRenew: _handleRenew,
            onAdjustWeek: _handleAdjustWeek,
          ),
          PlanPage(
            onPlanGenerated: _onPlanGenerated,
          ),
          ProfilePage(
            todayRate: _todayTasks.isNotEmpty
                ? _todayTasks.where((t) => t.completed).length / _todayTasks.length
                : 0.0,
            weekRate: _totalCount > 0 ? _completedCount / _totalCount : 0.0,
            totalFocusMinutes: 0,
            deadlineLabel: _deadlineLabel,
            daysUntilDeadline: _daysUntilDeadline,
            onRegeneratePlan: () {
              PlanRepository.deletePlan();
              setState(() {
                _allWeekTasks = [];
                _todayTasks = [];
                _currentWeek = 1;
                _remainingDays = 0;
                _completedCount = 0;
                _totalCount = 0;
                _dayInWeek = 1;
                _hasDeadline = false;
                _deadline = '';
                _canRenew = true;
              });
              _switchTab(1);
            },
          ),
        ],
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: _currentIndex,
        onTap: _switchTab,
      ),
    );
  }
}
