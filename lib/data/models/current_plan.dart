import 'dart:convert';
import 'task.dart';
import 'diagnosis.dart';

/// 当前活跃学习计划（开发文档第5节 current_plan 表）
///
/// 滚动7天计划模式：
/// - AI 每次只生成7天任务
/// - 完成后通过续订API生成下一周7天任务
/// - current_week 记录当前是第几周
class CurrentPlan {
  final int id;
  final String goal;
  final Diagnosis diagnosis;
  final List<Task> tasks;
  final String createdAt;

  /// 截止日期（YYYY-MM-DD，空字符串表示无截止日期）
  final String deadline;

  /// 计划总天数（从诊断中获取，用于计算剩余天数）
  final int totalDays;

  /// 当前是第几周（滚动7天计划的周数）
  final int currentWeek;

  const CurrentPlan({
    this.id = 1,
    required this.goal,
    required this.diagnosis,
    required this.tasks,
    required this.createdAt,
    this.deadline = '',
    this.totalDays = 0,
    this.currentWeek = 1,
  });

  factory CurrentPlan.fromDb(Map<String, dynamic> row) {
    return CurrentPlan(
      id: row['id'] as int? ?? 1,
      goal: row['goal'] as String? ?? '',
      diagnosis: Diagnosis.fromJson(
        jsonDecode(row['diagnosis_json'] as String? ?? '{}')
            as Map<String, dynamic>,
      ),
      tasks: (jsonDecode(row['tasks_json'] as String? ?? '[]') as List)
          .map((e) => Task.fromJson(e as Map<String, dynamic>))
          .toList(),
      createdAt: row['created_at'] as String? ?? '',
      deadline: row['deadline'] as String? ?? '',
      totalDays: row['total_days'] as int? ?? 0,
      currentWeek: row['current_week'] as int? ?? 1,
    );
  }

  Map<String, dynamic> toDb() {
    return {
      'id': id,
      'goal': goal,
      'diagnosis_json': jsonEncode(diagnosis.toJson()),
      'tasks_json': jsonEncode(tasks.map((t) => t.toJson()).toList()),
      'created_at': createdAt,
      'deadline': deadline,
      'total_days': totalDays,
      'current_week': currentWeek,
    };
  }

  // ============ 基础属性 ============

  /// 计划创建时间
  DateTime? get createdAtDate => DateTime.tryParse(createdAt);

  /// 当前是计划的第几天（从创建日算起）
  int get currentDay {
    if (tasks.isEmpty || createdAtDate == null) return 1;

    final created = DateTime(
      createdAtDate!.year,
      createdAtDate!.month,
      createdAtDate!.day,
    );
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final diffDays = today.difference(created).inDays + 1;

    // 当前周的天数范围：第N周 = (N-1)*7+1 ~ N*7
    final weekStartDay = (currentWeek - 1) * 7 + 1;
    final weekEndDay = currentWeek * 7;

    // 限制在当前周范围内
    if (diffDays < weekStartDay) return weekStartDay;
    if (diffDays > weekEndDay) return weekEndDay;
    return diffDays;
  }

  /// 今日任务（当前周的对应天）
  List<Task> get todayTasks {
    if (tasks.isEmpty) return [];

    // 当前周内第几天（1-7）
    final dayInWeek = currentDay - (currentWeek - 1) * 7;

    // 精确匹配
    final exact = tasks.where((t) => t.day == dayInWeek).toList();
    if (exact.isNotEmpty) return exact;

    // 按周匹配（长期计划 fallback）
    final sorted = List<Task>.from(tasks)
      ..sort((a, b) => a.day.compareTo(b.day));
    Task? current;
    for (final t in sorted) {
      if (t.day <= dayInWeek) {
        current = t;
      } else {
        break;
      }
    }
    return current != null ? [current] : [];
  }

  /// 已完成任务数（当前周）
  int get completedCount {
    return tasks.where((t) => t.completed).length;
  }

  /// 本周是否全部完成
  bool get isWeekCompleted {
    return tasks.isNotEmpty && tasks.every((t) => t.completed);
  }

  /// 是否提前完成（当前天数还未到周末，但任务全完成了）
  bool get isEarlyCompleted {
    if (!isWeekCompleted) return false;
    final dayInWeek = currentDay - (currentWeek - 1) * 7;
    return dayInWeek < 7;
  }

  // ============ 截止日期相关 ============

  bool get hasDeadline => deadline.isNotEmpty;

  DateTime? get deadlineDate => DateTime.tryParse(deadline);

  /// 距离截止日期剩余天数
  int get daysUntilDeadline {
    final dl = deadlineDate;
    if (dl == null) return -1;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final deadlineDay = DateTime(dl.year, dl.month, dl.day);
    final diff = deadlineDay.difference(today).inDays;
    return diff >= 0 ? diff + 1 : -1;
  }

  /// 剩余总天数（totalDays - 已经过去的天数）
  int get remainingTotalDays {
    if (totalDays <= 0) return 0;
    final elapsed = (currentWeek - 1) * 7;
    return (totalDays - elapsed).clamp(0, totalDays);
  }

  /// 是否还有下一周可以续订
  bool get canRenew {
    if (totalDays <= 0) return true; // 无限期
    final totalWeeks = (totalDays / 7).ceil();
    return currentWeek < totalWeeks;
  }

  /// 计划是否全部完成（所有周都做完了）
  bool get isPlanFinished {
    if (totalDays <= 0) return false;
    final totalWeeks = (totalDays / 7).ceil();
    return currentWeek >= totalWeeks && isWeekCompleted;
  }
}
