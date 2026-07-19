import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'supabase_config.dart';
import 'supabase_service.dart';

/// 用户身份管理服务
///
/// 负责：
/// - 生成唯一用户码（格式 ZXX# + 8位随机数字，如 ZXX#38474568）
/// - 持久化存储到 shared_preferences（key: `user_id`）
/// - 在 Supabase users 表中创建对应记录（静默执行，失败不提示）
class UserService {
  UserService._();

  static const String _userIdKey = 'user_id';

  /// 当前缓存的用户码
  static String _userId = '';

  /// 获取当前用户码
  static String get userId => _userId;

  /// 启动时初始化：读取或生成用户码
  ///
  /// 流程：
  /// 1. 从 shared_preferences 读取 user_id
  /// 2. 若不存在，生成新的用户码并持久化
  /// 3. 静默在 Supabase 创建用户记录（失败不阻断）
  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_userIdKey);

      if (saved != null && saved.isNotEmpty) {
        _userId = saved;
      } else {
        // 首次启动，生成新用户码
        _userId = _generateUserId();
        await prefs.setString(_userIdKey, _userId);
      }
    } catch (e) {
      // ignore: avoid_print
      print('[UserService] 初始化失败: $e');
      // 出错时也要保证有用户码
      if (_userId.isEmpty) {
        _userId = _generateUserId();
      }
    }

    // 静默在云端创建用户记录（失败不影响本地）
    _registerToCloud();
  }

  /// 生成唯一用户码（ZXX# + 8位随机数字）
  static String _generateUserId() {
    final random = Random();
    final num = 10000000 + random.nextInt(90000000); // 8位随机数
    return 'ZXX#$num';
  }

  /// 静默在 Supabase 创建用户记录
  ///
  /// 失败时只打印日志，不抛出异常，不阻断用户操作。
  static Future<void> _registerToCloud() async {
    if (!SupabaseConfig.isConfigured) return;
    try {
      await SupabaseService.createUser(_userId);
    } catch (e) {
      // ignore: avoid_print
      print('[UserService] 云端注册失败: $e');
    }
  }

  /// 更新用户资料到云端（静默执行）
  static Future<void> updateProfile({
    String? nickname,
    String? phone,
    String? email,
  }) async {
    if (!SupabaseConfig.isConfigured) return;
    try {
      await SupabaseService.updateUser(
        _userId,
        nickname: nickname,
        phone: phone,
        email: email,
      );
    } catch (e) {
      // ignore: avoid_print
      print('[UserService] 云端更新资料失败: $e');
    }
  }
}
