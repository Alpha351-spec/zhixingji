import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/services/settings_service.dart';
import '../data/database/database_helper.dart';
import 'supabase_service.dart';
import 'user_service.dart';

/// 数据同步服务 —— 协调本地 SQLite 和云端 Supabase 数据
///
/// 同步策略：本地为主，云端为备份。
/// - 写入时先写本地，再静默上传云端
/// - 读取时直接读本地
/// - 网络异常时不同步，不提示用户，只打印日志
class SyncService {
  SyncService._();

  /// SharedPreferences key：云端计划 ID
  static const String _cloudPlanIdKey = 'cloud_plan_id';

  /// 是否正在同步（防止重复触发）
  static bool _isSyncing = false;

  /// 自动同步防抖定时器（5 秒内多次触发只执行一次）
  static Timer? _debounceTimer;

  // ============ 同步方法 ============

  /// 将本地所有数据批量上传到云端
  ///
  /// 读取本地 SQLite 中的计划、任务、验证记录、设置，
  /// 逐一调用 SupabaseService 上传。静默执行，失败只打印日志。
  static Future<void> syncAll(String userId) async {
    if (!SupabaseService.isAvailable) return;
    if (_isSyncing) return;
    _isSyncing = true;

    try {
      // 1. 同步计划
      await _syncPlan(userId);

      // 2. 同步任务（任务嵌入在 plan 的 tasks_json 中，需拆分上传）
      await _syncTasks(userId);

      // 3. 同步验证记录
      await _syncVerificationRecords(userId);

      // 4. 同步用户设置
      await _syncSettings(userId);

      // 5. 同步用户资料
      await _syncUserProfile(userId);
    } catch (e) {
      print('[SyncService] syncAll 失败: $e');
    } finally {
      _isSyncing = false;
    }
  }

  /// 从云端恢复数据到本地（换机场景）
  ///
  /// 下载最新计划及关联数据，恢复到本地 SQLite。静默执行。
  static Future<void> restoreFromCloud(String userId) async {
    if (!SupabaseService.isAvailable) return;

    try {
      // 1. 下载最新计划
      final cloudPlan = await SupabaseService.downloadLatestPlan(userId);
      if (cloudPlan == null) {
        print('[SyncService] 云端无计划数据可恢复');
        return;
      }

      // 2. 下载关联任务
      final cloudPlanId = cloudPlan['plan_id'] as int;
      final cloudTasks = await SupabaseService.downloadTasks(cloudPlanId);

      // 3. 将任务列表转为 tasks_json
      final tasksJson = cloudTasks.map((t) {
        final task = Map<String, dynamic>.from(t);
        task.remove('task_id');
        task.remove('plan_id');
        return task;
      }).toList();

      // 4. 写入本地 SQLite
      final localPlan = Map<String, dynamic>.from(cloudPlan);
      localPlan.remove('plan_id');
      localPlan.remove('user_id');
      localPlan['id'] = 1; // 本地固定 id
      localPlan['tasks_json'] = jsonEncode(tasksJson);
      // 确保 created_at 格式正确
      if (!localPlan.containsKey('created_at') || localPlan['created_at'] == null) {
        localPlan['created_at'] = DateTime.now().toIso8601String();
      }

      await DatabaseHelper.upsertPlan(localPlan);

      // 5. 保存云端 plan_id 映射
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_cloudPlanIdKey, cloudPlanId);

      // 6. 下载并恢复验证记录
      final cloudRecords = await SupabaseService.downloadVerificationRecords(userId);
      for (final record in cloudRecords) {
        final localRecord = Map<String, dynamic>.from(record);
        localRecord.remove('id');
        localRecord.remove('user_id');
        localRecord.remove('task_id');
        await DatabaseHelper.insertVerificationRecord(localRecord);
      }

      // 7. 下载并恢复用户设置
      final cloudSettings = await SupabaseService.downloadSettings(userId);
      if (cloudSettings != null) {
        await SettingsService.save(
          SettingsService.current.copyWith(
            // 从云端 settings_json 恢复各字段
            resourceMode: cloudSettings['resourceMode'] as String? ??
                SettingsService.current.resourceMode,
            planDetailLevel: cloudSettings['planDetailLevel'] as String? ??
                SettingsService.current.planDetailLevel,
            defaultFocusDuration: cloudSettings['defaultFocusDuration'] as int? ??
                SettingsService.current.defaultFocusDuration,
            whiteNoise: cloudSettings['whiteNoise'] as bool? ??
                SettingsService.current.whiteNoise,
            whiteNoiseType: cloudSettings['whiteNoiseType'] as String? ??
                SettingsService.current.whiteNoiseType,
          ),
        );
      }

      print('[SyncService] 从云端恢复数据成功');
    } catch (e) {
      print('[SyncService] restoreFromCloud 失败: $e');
    }
  }

  /// 便捷触发自动同步（带 5 秒防抖）
  ///
  /// 适合在计划生成、打卡完成、设置修改后调用。
  /// 5 秒内多次触发只会执行一次真正的同步，避免频繁请求。
  static void triggerAutoSync() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(seconds: 5), () {
      autoSync(UserService.userId);
    });
  }

  /// 自动同步（在 Wi-Fi 环境下静默调用 syncAll）
  ///
  /// 触发时机：每次打卡完成、计划生成、设置修改后。
  static Future<void> autoSync(String userId) async {
    if (!SupabaseService.isAvailable) return;

    try {
      // 检查网络连接状态
      final connectivityResult = await Connectivity().checkConnectivity();

      // 在 Wi-Fi 或以太网环境下同步（移动网络不同步以节省流量）
      if (connectivityResult.contains(ConnectivityResult.wifi) ||
          connectivityResult.contains(ConnectivityResult.ethernet)) {
        await syncAll(userId);
      } else {
        print('[SyncService] 当前非 Wi-Fi 环境，跳过自动同步');
      }
    } catch (e) {
      print('[SyncService] autoSync 失败: $e');
    }
  }

  // ============ 内部同步实现 ============

  /// 同步当前计划到云端
  static Future<void> _syncPlan(String userId) async {
    final localPlan = await DatabaseHelper.getPlan();
    if (localPlan == null) return;

    final prefs = await SharedPreferences.getInstance();
    final cloudPlanId = prefs.getInt(_cloudPlanIdKey);

    if (cloudPlanId != null) {
      // 已有云端记录，更新
      await SupabaseService.updatePlan(cloudPlanId, localPlan);
    } else {
      // 首次上传，创建
      final newPlanId = await SupabaseService.uploadPlan(userId, localPlan);
      if (newPlanId != null) {
        await prefs.setInt(_cloudPlanIdKey, newPlanId);
      }
    }
  }

  /// 同步任务到云端
  ///
  /// 本地任务以 JSON 形式嵌入在 plan.tasks_json 中，
  /// 需要解析后逐一上传到云端 tasks 表。
  static Future<void> _syncTasks(String userId) async {
    final localPlan = await DatabaseHelper.getPlan();
    if (localPlan == null) return;

    final prefs = await SharedPreferences.getInstance();
    final cloudPlanId = prefs.getInt(_cloudPlanIdKey);
    if (cloudPlanId == null) return;

    try {
      final tasksJson = localPlan['tasks_json'] as String? ?? '[]';
      final tasks = (jsonDecode(tasksJson) as List).cast<Map<String, dynamic>>();

      for (final task in tasks) {
        await SupabaseService.uploadTask(cloudPlanId, task);
      }
    } catch (e) {
      print('[SyncService] _syncTasks 失败: $e');
    }
  }

  /// 同步验证记录到云端
  static Future<void> _syncVerificationRecords(String userId) async {
    final localPlan = await DatabaseHelper.getPlan();
    if (localPlan == null) return;

    try {
      // 查询所有验证记录（遍历所有 task_day）
      // 由于本地验证记录按 task_day 查询，这里遍历 1-7 天
      for (var day = 1; day <= 7; day++) {
        final records = await DatabaseHelper.getVerificationRecords(day);
        for (final record in records) {
          await SupabaseService.uploadVerificationRecord(
            userId,
            record['task_day'] as int? ?? day,
            record,
          );
        }
      }
    } catch (e) {
      print('[SyncService] _syncVerificationRecords 失败: $e');
    }
  }

  /// 同步用户设置到云端
  static Future<void> _syncSettings(String userId) async {
    try {
      final settings = SettingsService.current;
      await SupabaseService.uploadSettings(userId, settings.toJson());
    } catch (e) {
      print('[SyncService] _syncSettings 失败: $e');
    }
  }

  /// 同步用户资料到云端
  static Future<void> _syncUserProfile(String userId) async {
    try {
      // 从 UserProfileService 获取资料并同步
      // 使用延迟导入避免循环依赖
      final profile = await _getUserProfile();
      if (profile != null) {
        await SupabaseService.updateUser(
          userId,
          nickname: profile['nickname'] as String?,
          phone: profile['phone'] as String?,
          email: profile['email'] as String?,
        );
      }
    } catch (e) {
      print('[SyncService] _syncUserProfile 失败: $e');
    }
  }

  /// 从 shared_preferences 读取用户资料
  static Future<Map<String, dynamic>?> _getUserProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString('user_profile');
      if (json != null && json.isNotEmpty) {
        return jsonDecode(json) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  // ============ 辅助方法 ============

  /// 检查本地是否有数据
  ///
  /// 用于判断是否需要从云端恢复。
  static Future<bool> hasLocalData() async {
    final plan = await DatabaseHelper.getPlan();
    return plan != null;
  }

  /// 重置云端计划 ID（删除本地计划时调用）
  static Future<void> resetCloudPlanId() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cloudPlanIdKey);
  }
}
