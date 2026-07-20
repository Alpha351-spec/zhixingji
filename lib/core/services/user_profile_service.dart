import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/user_profile.dart';
import '../../services/user_service.dart';

/// 用户个人信息持久化服务
///
/// 使用 shared_preferences 以 JSON 字符串形式存储用户资料。
/// 应用启动时由 main.dart 调用 load()，运行中通过 save() 更新。
///
/// 注意：用户码由 [UserService] 统一管理，
/// 本服务在 load() 时从 UserService 同步，确保全局一致。
class UserProfileService {
  UserProfileService._();

  static const String _storageKey = 'user_profile';

  /// 当前缓存的用户资料（内存中）
  static UserProfile _current = const UserProfile();

  /// 获取当前用户资料
  static UserProfile get current => _current;

  /// 启动时加载已保存的用户资料
  ///
  /// 用户码从 UserService 同步（UserService 必须先于本服务初始化）。
  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_storageKey);
      if (json != null && json.isNotEmpty) {
        _current = UserProfile.fromJson(
          jsonDecode(json) as Map<String, dynamic>,
        );
      }
      // 统一使用 UserService 的用户码（以 UserService 为唯一来源）
      final unifiedUserId = UserService.userId;
      if (unifiedUserId.isNotEmpty && _current.userId != unifiedUserId) {
        _current = _current.copyWith(userId: unifiedUserId);
        await prefs.setString(_storageKey, jsonEncode(_current.toJson()));
      }
    } catch (e) {
      // ignore: avoid_print
      print('[UserProfileService] 加载失败: $e');
      // 出错时也要保证 userId 与 UserService 一致
      _current = UserProfile(userId: UserService.userId);
    }
  }

  /// 保存用户资料
  static Future<bool> save(UserProfile profile) async {
    try {
      // 保存时强制使用 UserService 的用户码，防止不一致
      if (profile.userId != UserService.userId && UserService.userId.isNotEmpty) {
        profile = profile.copyWith(userId: UserService.userId);
      }
      _current = profile;
      final prefs = await SharedPreferences.getInstance();
      return await prefs.setString(_storageKey, jsonEncode(profile.toJson()));
    } catch (e) {
      // ignore: avoid_print
      print('[UserProfileService] 保存失败: $e');
      return false;
    }
  }
}
