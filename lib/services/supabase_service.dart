import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_config.dart';

/// Supabase 云端数据库服务
///
/// 封装所有云端数据库操作。每个方法都采用静默执行模式——
/// 成功不提示，失败只打印日志，不抛出异常，不阻断用户操作。
///
/// 云端表结构（需在 Supabase Dashboard 中创建）：
/// - users: user_id(PK), nickname, phone, email, created_at
/// - plans: plan_id(PK/auto), user_id, goal, diagnosis_json, tasks_json,
///           created_at, deadline, total_days, current_week
/// - tasks: task_id(PK/auto), plan_id, day, title, description,
///          resource_keywords, encouragement, completed, focus_minutes,
///          verification_type
/// - checkins: id(PK/auto), user_id, plan_id, task_id, created_at
/// - verification_records: id(PK/auto), user_id, task_id, verification_type,
///          questions_json, user_answer, ai_evaluation, passed, created_at
/// - user_settings: user_id(PK), settings_json, updated_at
class SupabaseService {
  SupabaseService._();

  /// 获取 Supabase 客户端单例
  static SupabaseClient get _client => Supabase.instance.client;

  /// Supabase 是否可用（已初始化且配置了真实凭证）
  static bool get isAvailable => SupabaseConfig.isConfigured;

  // ============ 用户相关 ============

  /// 创建用户记录
  ///
  /// 在 users 表中插入新用户。若已存在则忽略（onConflict: user_id）。
  static Future<void> createUser(
    String userId, {
    String? nickname,
    String? phone,
    String? email,
  }) async {
    if (!isAvailable) return;
    try {
      await _client.from('users').upsert({
        'user_id': userId,
        'nickname': nickname,
        'phone': phone,
        'email': email,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'user_id');
    } catch (e) {
      print('[SupabaseService] createUser 失败: $e');
    }
  }

  /// 更新用户资料
  static Future<void> updateUser(
    String userId, {
    String? nickname,
    String? phone,
    String? email,
  }) async {
    if (!isAvailable) return;
    try {
      final data = <String, dynamic>{};
      if (nickname != null) data['nickname'] = nickname;
      if (phone != null) data['phone'] = phone;
      if (email != null) data['email'] = email;
      if (data.isEmpty) return;

      await _client.from('users').update(data).eq('user_id', userId);
    } catch (e) {
      print('[SupabaseService] updateUser 失败: $e');
    }
  }

  // ============ 计划相关 ============

  /// 上传计划数据，返回云端生成的 plan_id
  ///
  /// 若上传失败返回 null。
  static Future<int?> uploadPlan(String userId, Map<String, dynamic> planData) async {
    if (!isAvailable) return null;
    try {
      final response = await _client.from('plans').insert({
        'user_id': userId,
        'goal': planData['goal'],
        'diagnosis_json': planData['diagnosis_json'],
        'tasks_json': planData['tasks_json'],
        'created_at': planData['created_at'],
        'deadline': planData['deadline'] ?? '',
        'total_days': planData['total_days'] ?? 0,
        'current_week': planData['current_week'] ?? 1,
      }).select('plan_id').single();
      return response['plan_id'] as int?;
    } catch (e) {
      print('[SupabaseService] uploadPlan 失败: $e');
      return null;
    }
  }

  /// 更新计划数据
  static Future<void> updatePlan(int planId, Map<String, dynamic> planData) async {
    if (!isAvailable) return;
    try {
      final data = <String, dynamic>{};
      // 只更新非空字段
      for (final key in [
        'goal', 'diagnosis_json', 'tasks_json', 'created_at',
        'deadline', 'total_days', 'current_week',
      ]) {
        if (planData.containsKey(key)) {
          data[key] = planData[key];
        }
      }
      if (data.isEmpty) return;

      await _client.from('plans').update(data).eq('plan_id', planId);
    } catch (e) {
      print('[SupabaseService] updatePlan 失败: $e');
    }
  }

  /// 下载用户最新的计划数据
  ///
  /// 返回最新的计划 Map（含 plan_id），失败返回 null。
  static Future<Map<String, dynamic>?> downloadLatestPlan(String userId) async {
    if (!isAvailable) return null;
    try {
      final response = await _client
          .from('plans')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(1);
      if (response.isEmpty) return null;
      return response.first as Map<String, dynamic>?;
    } catch (e) {
      print('[SupabaseService] downloadLatestPlan 失败: $e');
      return null;
    }
  }

  // ============ 任务相关 ============

  /// 上传任务数据，返回云端生成的 task_id
  ///
  /// 若上传失败返回 null。
  static Future<int?> uploadTask(int planId, Map<String, dynamic> taskData) async {
    if (!isAvailable) return null;
    try {
      final response = await _client.from('tasks').insert({
        'plan_id': planId,
        'day': taskData['day'],
        'title': taskData['title'],
        'description': taskData['description'],
        'resource_keywords': taskData['resource_keywords'] ?? '',
        'encouragement': taskData['encouragement'] ?? '',
        'completed': taskData['completed'] ?? 0,
        'focus_minutes': taskData['focus_minutes'] ?? 0,
        'verification_type': taskData['verification_type'] ?? 'none',
      }).select('task_id').single();
      return response['task_id'] as int?;
    } catch (e) {
      print('[SupabaseService] uploadTask 失败: $e');
      return null;
    }
  }

  /// 更新任务数据
  static Future<void> updateTask(int taskId, Map<String, dynamic> taskData) async {
    if (!isAvailable) return;
    try {
      final data = <String, dynamic>{};
      for (final key in [
        'day', 'title', 'description', 'resource_keywords',
        'encouragement', 'completed', 'focus_minutes', 'verification_type',
      ]) {
        if (taskData.containsKey(key)) {
          data[key] = taskData[key];
        }
      }
      if (data.isEmpty) return;

      await _client.from('tasks').update(data).eq('task_id', taskId);
    } catch (e) {
      print('[SupabaseService] updateTask 失败: $e');
    }
  }

  /// 下载某个计划的所有任务
  ///
  /// 返回任务列表，失败返回空列表。
  static Future<List<Map<String, dynamic>>> downloadTasks(int planId) async {
    if (!isAvailable) return [];
    try {
      final response = await _client
          .from('tasks')
          .select()
          .eq('plan_id', planId)
          .order('day', ascending: true);
      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      print('[SupabaseService] downloadTasks 失败: $e');
      return [];
    }
  }

  // ============ 打卡记录相关 ============

  /// 上传打卡记录
  static Future<void> uploadCheckin(
    String userId,
    int planId,
    int taskId,
  ) async {
    if (!isAvailable) return;
    try {
      await _client.from('checkins').insert({
        'user_id': userId,
        'plan_id': planId,
        'task_id': taskId,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (e) {
      print('[SupabaseService] uploadCheckin 失败: $e');
    }
  }

  /// 下载某个计划的打卡记录列表
  ///
  /// 失败返回空列表。
  static Future<List<Map<String, dynamic>>> downloadCheckins(
    String userId,
    int planId,
  ) async {
    if (!isAvailable) return [];
    try {
      final response = await _client
          .from('checkins')
          .select()
          .eq('user_id', userId)
          .eq('plan_id', planId)
          .order('created_at', ascending: false);
      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      print('[SupabaseService] downloadCheckins 失败: $e');
      return [];
    }
  }

  // ============ 验证记录相关 ============

  /// 上传验证记录
  static Future<void> uploadVerificationRecord(
    String userId,
    int taskId,
    Map<String, dynamic> recordData,
  ) async {
    if (!isAvailable) return;
    try {
      await _client.from('verification_records').insert({
        'user_id': userId,
        'task_id': taskId,
        'task_day': recordData['task_day'],
        'plan_id': recordData['plan_id'],
        'verification_type': recordData['verification_type'],
        'questions_json': recordData['questions_json'],
        'user_answer': recordData['user_answer'],
        'ai_evaluation': recordData['ai_evaluation'],
        'passed': recordData['passed'],
        'created_at': recordData['created_at'],
      });
    } catch (e) {
      print('[SupabaseService] uploadVerificationRecord 失败: $e');
    }
  }

  /// 下载用户的所有验证记录
  ///
  /// 失败返回空列表。
  static Future<List<Map<String, dynamic>>> downloadVerificationRecords(
    String userId,
  ) async {
    if (!isAvailable) return [];
    try {
      final response = await _client
          .from('verification_records')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      print('[SupabaseService] downloadVerificationRecords 失败: $e');
      return [];
    }
  }

  // ============ 用户设置相关 ============

  /// 上传用户设置
  static Future<void> uploadSettings(
    String userId,
    Map<String, dynamic> settings,
  ) async {
    if (!isAvailable) return;
    try {
      await _client.from('user_settings').upsert({
        'user_id': userId,
        'settings_json': settings,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'user_id');
    } catch (e) {
      print('[SupabaseService] uploadSettings 失败: $e');
    }
  }

  /// 下载用户设置
  ///
  /// 失败返回 null。
  static Future<Map<String, dynamic>?> downloadSettings(String userId) async {
    if (!isAvailable) return null;
    try {
      final response = await _client
          .from('user_settings')
          .select('settings_json')
          .eq('user_id', userId)
          .limit(1);
      if (response.isEmpty) return null;
      return response.first['settings_json'] as Map<String, dynamic>?;
    } catch (e) {
      print('[SupabaseService] downloadSettings 失败: $e');
      return null;
    }
  }
}
