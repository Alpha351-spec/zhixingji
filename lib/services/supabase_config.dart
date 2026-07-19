/// Supabase 云端数据库配置
///
/// 使用前需替换为真实的 Supabase 项目 URL 和 anon key。
/// 获取方式：Supabase Dashboard → Project Settings → API
class SupabaseConfig {
  SupabaseConfig._();

  /// Supabase 项目 URL（占位符，替换为真实值）
  ///
  /// 格式：https://xxxxx.supabase.co
  static const String url = 'https://YOUR_PROJECT.supabase.co';

  /// Supabase anon/publishable key（占位符，替换为真实值）
  ///
  /// 在 Supabase Dashboard → Settings → API → Project API keys 中获取
  static const String anonKey = 'YOUR_ANON_KEY';

  /// Supabase 是否已配置真实凭证（URL 和 key 都不是占位符时为 true）
  static bool get isConfigured =>
      !url.contains('YOUR_PROJECT') && !anonKey.contains('YOUR_ANON_KEY');
}
