import 'dart:convert';
import '../models/current_plan.dart';
import '../models/task.dart';
import '../models/diagnosis.dart';
import '../database/database_helper.dart';
import 'ai_service.dart';
import '../../services/sync_service.dart';

/// 学习计划仓库（开发文档第5、6、7节）
///
/// 滚动7天计划模式：
/// - 初始生成7天任务
/// - 完成后通过 renewWeek() 续订下一周
class PlanRepository {
  PlanRepository._();

  /// 获取当前活跃计划
  static Future<CurrentPlan?> getCurrentPlan() async {
    try {
      final row = await DatabaseHelper.getPlan();
      if (row == null) return null;
      return CurrentPlan.fromDb(row);
    } catch (e) {
      debugLog('getCurrentPlan 失败: $e');
      return null;
    }
  }

  /// 是否已有活跃计划
  static Future<bool> hasActivePlan() async {
    return await getCurrentPlan() != null;
  }

  /// 从 AI 回复中解析并保存初始计划（第一周）
  static Future<CurrentPlan?> savePlanFromAI(String aiResponse) async {
    try {
      final json = AIService.extractJson(aiResponse);
      if (json == null) return null;

      final planJson = json['plan'] as Map<String, dynamic>?;
      if (planJson == null) return null;

      final diagnosisJson =
          json['diagnosis'] as Map<String, dynamic>? ?? {};
      final tasksJson = planJson['tasks'] as List? ?? [];

      final diagnosis = Diagnosis.fromJson(diagnosisJson);
      final tasks = tasksJson
          .map((e) => Task.fromJson(e as Map<String, dynamic>))
          .toList();

      final plan = CurrentPlan(
        id: 1,
        goal: planJson['goal'] as String? ?? '',
        diagnosis: diagnosis,
        tasks: tasks,
        createdAt: DateTime.now().toIso8601String(),
        deadline: diagnosis.deadline,
        totalDays: diagnosis.totalDays,
        currentWeek: 1,
      );

      await DatabaseHelper.upsertPlan(plan.toDb());
      SyncService.triggerAutoSync();
      return plan;
    } catch (e) {
      debugLog('savePlanFromAI 失败: $e');
      return null;
    }
  }

  /// 续订下一周计划
  ///
  /// [plan] 当前计划
  /// [feedback] 用户反馈
  /// 返回更新后的计划，失败返回 null。
  static Future<CurrentPlan?> renewWeek(
    CurrentPlan plan,
    String feedback,
  ) async {
    try {
      // 收集本周完成的任务标题
      final completedTasks = plan.tasks
          .where((t) => t.completed)
          .map((t) => t.title)
          .toList();

      // 调用续订 API
      final aiResponse = await AIService.renewPlan(
        diagnosis: jsonEncode(plan.diagnosis.toJson()),
        currentWeek: plan.currentWeek,
        completedTasks: completedTasks,
        feedback: feedback,
      );

      // 解析新任务
      final json = AIService.extractJson(aiResponse);
      if (json == null) return null;

      final planJson = json['plan'] as Map<String, dynamic>?;
      if (planJson == null) return null;

      final tasksJson = planJson['tasks'] as List? ?? [];
      final newTasks = tasksJson
          .map((e) => Task.fromJson(e as Map<String, dynamic>))
          .toList();

      if (newTasks.isEmpty) return null;

      // 更新计划：currentWeek+1，tasks 替换为新任务
      final renewedPlan = CurrentPlan(
        id: plan.id,
        goal: plan.goal,
        diagnosis: plan.diagnosis,
        tasks: newTasks,
        createdAt: plan.createdAt,
        deadline: plan.deadline,
        totalDays: plan.totalDays,
        currentWeek: plan.currentWeek + 1,
      );

      await DatabaseHelper.upsertPlan(renewedPlan.toDb());
      SyncService.triggerAutoSync();
      return renewedPlan;
    } catch (e) {
      debugLog('renewWeek 失败: $e');
      return null;
    }
  }

  /// 更新任务完成状态
  static Future<void> updateTaskCompleted(
    int taskDay,
    bool completed, {
    String? taskTitle,
  }) async {
    try {
      final plan = await getCurrentPlan();
      if (plan == null) return;

      final updatedTasks = plan.tasks.map((t) {
        // 用 day + title 精确定位单个任务，避免同一天所有任务被一起打卡
        if (t.day == taskDay && (taskTitle == null || t.title == taskTitle)) {
          return t.copyWith(completed: completed);
        }
        return t;
      }).toList();

      final updatedPlan = CurrentPlan(
        id: plan.id,
        goal: plan.goal,
        diagnosis: plan.diagnosis,
        tasks: updatedTasks,
        createdAt: plan.createdAt,
        deadline: plan.deadline,
        totalDays: plan.totalDays,
        currentWeek: plan.currentWeek,
      );

      await DatabaseHelper.upsertPlan(updatedPlan.toDb());
      SyncService.triggerAutoSync();
    } catch (e) {
      debugLog('updateTaskCompleted 失败: $e');
    }
  }

  /// 更新任务专注时长
  static Future<void> addFocusMinutes(int taskDay, int minutes, {String? taskTitle}) async {
    try {
      final plan = await getCurrentPlan();
      if (plan == null) return;

      final updatedTasks = plan.tasks.map((t) {
        // 用 day + title 精确定位单个任务
        if (t.day == taskDay && (taskTitle == null || t.title == taskTitle)) {
          return t.copyWith(focusMinutes: t.focusMinutes + minutes);
        }
        return t;
      }).toList();

      final updatedPlan = CurrentPlan(
        id: plan.id,
        goal: plan.goal,
        diagnosis: plan.diagnosis,
        tasks: updatedTasks,
        createdAt: plan.createdAt,
        deadline: plan.deadline,
        totalDays: plan.totalDays,
        currentWeek: plan.currentWeek,
      );

      await DatabaseHelper.upsertPlan(updatedPlan.toDb());
      SyncService.triggerAutoSync();
    } catch (e) {
      debugLog('addFocusMinutes 失败: $e');
    }
  }

  /// 删除当前计划
  static Future<void> deletePlan() async {
    try {
      await DatabaseHelper.deletePlan();
      SyncService.triggerAutoSync();
    } catch (e) {
      debugLog('deletePlan 失败: $e');
    }
  }

  /// 微调计划（计划页：保留诊断和计划元信息，只替换7天任务）
  ///
  /// 从 AI 微调回复中解析新任务，替换当前计划的任务列表。
  /// 诊断信息、deadline、totalDays、currentWeek 保持不变。
  ///
  /// [aiResponse] AI 的微调回复
  /// [existingPlan] 当前计划（用于保留诊断等元信息）
  static Future<CurrentPlan?> adjustPlanFromAI(
    String aiResponse,
    CurrentPlan existingPlan,
  ) async {
    try {
      final json = AIService.extractJson(aiResponse);
      if (json == null) return null;

      final planJson = json['plan'] as Map<String, dynamic>?;
      if (planJson == null) return null;

      final tasksJson = planJson['tasks'] as List? ?? [];
      final newTasks = tasksJson
          .map((e) => Task.fromJson(e as Map<String, dynamic>))
          .toList();

      if (newTasks.isEmpty) return null;

      final adjustedPlan = CurrentPlan(
        id: existingPlan.id,
        goal: existingPlan.goal,
        diagnosis: existingPlan.diagnosis,
        tasks: newTasks,
        createdAt: existingPlan.createdAt,
        deadline: existingPlan.deadline,
        totalDays: existingPlan.totalDays,
        currentWeek: existingPlan.currentWeek,
      );

      await DatabaseHelper.upsertPlan(adjustedPlan.toDb());
      SyncService.triggerAutoSync();
      return adjustedPlan;
    } catch (e) {
      debugLog('adjustPlanFromAI 失败: $e');
      return null;
    }
  }

  /// 微调本周剩余任务（学习页：保留已完成任务，替换未完成的剩余天数任务）
  ///
  /// 从 AI 微调回复中解析新任务，合并到当前计划中：
  /// - 已完成的任务保留不变
  /// - 从当前天数到第7天的任务用 AI 生成的新任务替换
  ///
  /// [aiResponse] AI 的微调回复
  /// [existingPlan] 当前计划
  static Future<CurrentPlan?> adjustWeekTasksFromAI(
    String aiResponse,
    CurrentPlan existingPlan,
  ) async {
    try {
      final json = AIService.extractJson(aiResponse);
      if (json == null) return null;

      final planJson = json['plan'] as Map<String, dynamic>?;
      if (planJson == null) return null;

      final tasksJson = planJson['tasks'] as List? ?? [];
      final newTasks = tasksJson
          .map((e) => Task.fromJson(e as Map<String, dynamic>))
          .toList();

      if (newTasks.isEmpty) return null;

      // 获取新任务覆盖的 day 范围
      final newDaySet = newTasks.map((t) => t.day).toSet();

      // 合并：保留已完成任务（不在新任务 day 范围内的），加上新任务
      final mergedTasks = <Task>[];

      // 保留已完成任务
      for (final task in existingPlan.tasks) {
        if (task.completed && !newDaySet.contains(task.day)) {
          mergedTasks.add(task);
        }
      }

      // 添加新任务
      mergedTasks.addAll(newTasks);

      // 按 day 排序
      mergedTasks.sort((a, b) => a.day.compareTo(b.day));

      final adjustedPlan = CurrentPlan(
        id: existingPlan.id,
        goal: existingPlan.goal,
        diagnosis: existingPlan.diagnosis,
        tasks: mergedTasks,
        createdAt: existingPlan.createdAt,
        deadline: existingPlan.deadline,
        totalDays: existingPlan.totalDays,
        currentWeek: existingPlan.currentWeek,
      );

      await DatabaseHelper.upsertPlan(adjustedPlan.toDb());
      SyncService.triggerAutoSync();
      return adjustedPlan;
    } catch (e) {
      debugLog('adjustWeekTasksFromAI 失败: $e');
      return null;
    }
  }

  static void debugLog(String message) {
    // ignore: avoid_print
    print('[PlanRepository] $message');
  }
}
