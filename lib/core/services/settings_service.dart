import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/app_settings.dart';

/// 应用设置持久化服务
///
/// 使用 shared_preferences 以 JSON 存储。启动时由 main.dart 调用 load()。
class SettingsService {
  SettingsService._();

  static const String _storageKey = 'app_settings';

  static AppSettings _current = const AppSettings();

  /// 当前设置（内存缓存）
  static AppSettings get current => _current;

  /// 启动时加载
  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_storageKey);
      if (json != null && json.isNotEmpty) {
        _current =
            AppSettings.fromJson(jsonDecode(json) as Map<String, dynamic>);
      }
    } catch (e) {
      // ignore: avoid_print
      print('[SettingsService] 加载失败: $e');
    }
  }

  /// 保存设置
  static Future<bool> save(AppSettings settings) async {
    try {
      _current = settings;
      final prefs = await SharedPreferences.getInstance();
      return await prefs.setString(
          _storageKey, jsonEncode(settings.toJson()));
    } catch (e) {
      // ignore: avoid_print
      print('[SettingsService] 保存失败: $e');
      return false;
    }
  }
}
