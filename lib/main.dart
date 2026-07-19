import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/platform/database_init.dart';
import 'core/services/api_key_service.dart';
import 'core/services/lock_screen_service.dart';
import 'core/services/settings_service.dart';
import 'core/services/user_profile_service.dart';
import 'services/supabase_config.dart';
import 'services/user_service.dart';
import 'services/sync_service.dart';
import 'app.dart';

/// 知行计 - 应用入口
///
/// 用AI对话诊断你的情况，生成个性化任务清单，结合番茄钟专注执行，完成每日打卡。
void main() async {
  // 1. Flutter 绑定初始化
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Supabase 初始化（使用占位符，配置真实凭证后生效）
  if (SupabaseConfig.isConfigured) {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      publishableKey: SupabaseConfig.anonKey,
    );
  }

  // 3. 本地 SQLite 数据库初始化（桌面端用 sqflite_common_ffi，移动端用原生 sqflite）
  initPlatformDatabase();

  // 4. 加载已保存的 API Key
  await ApiKeyService.load();

  // 5. 加载已保存的用户资料
  await UserProfileService.load();

  // 6. 加载已保存的应用设置
  await SettingsService.load();

  // 7. 用户身份初始化（生成/读取用户码，静默注册到云端）
  await UserService.init();

  // 8. 初始化番茄钟软锁屏服务
  LockScreenService.init();

  // 9. 首次启动且本地无数据时，从云端恢复（换机场景）
  if (SupabaseConfig.isConfigured) {
    final hasLocalData = await SyncService.hasLocalData();
    if (!hasLocalData) {
      await SyncService.restoreFromCloud(UserService.userId);
    }
  }

  // 10. 后台静默自动同步（不等待完成）
  if (SupabaseConfig.isConfigured) {
    SyncService.autoSync(UserService.userId);
  }

  runApp(const App());
}
