/// Supabase 云端数据库配置
///
/// 使用前需替换为真实的 Supabase 项目 URL 和 anon key。
/// 获取方式：Supabase Dashboard → Project Settings → API
class SupabaseConfig {
  SupabaseConfig._();

  /// Supabase 项目 URL（占位符，替换为真实值）
  ///
  /// 格式：https://xxxxx.supabase.co
  static const String url = 'https://rqsigxohqvhrlxdqtkdt.supabase.co';

  /// Supabase anon/publishable key（占位符，替换为真实值）
  ///
  /// 在 Supabase Dashboard → Settings → API → Project API keys 中获取
  static const String anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJxc2lneG9ocXZocmx4ZHF0a2R0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODQ0NDc4MzYsImV4cCI6MjEwMDAyMzgzNn0.VYWR4-RuNP8uoGyZHHmc1hozQ2nU1_e5leqAMJFsdt0';

  /// Supabase 是否已配置真实凭证（URL 和 key 都不是占位符时为 true）
  static bool get isConfigured =>
      !url.contains('YOUR_PROJECT') && !anonKey.contains('YOUR_ANON_KEY');
}
