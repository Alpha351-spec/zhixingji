import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'package:flutter/material.dart';
import 'core/platform/database_init.dart';
import 'core/services/api_key_service.dart';
import 'core/services/lock_screen_service.dart';
import 'core/services/settings_service.dart';
import 'core/services/user_profile_service.dart';
import 'app.dart';

/// 知行计 - 应用入口
///
/// 用AI对话诊断你的情况，生成个性化任务清单，结合番茄钟专注执行，完成每日打卡。
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 平台特定的数据库初始化（桌面端用 sqflite_common_ffi，移动端用原生 sqflite）
  initPlatformDatabase();

  // 加载已保存的 API Key
  await ApiKeyService.load();

  // 加载已保存的用户资料
  await UserProfileService.load();

  // 加载已保存的应用设置
  await SettingsService.load();

  // 初始化番茄钟软锁屏服务
  LockScreenService.init();

  runApp(const App());
}
