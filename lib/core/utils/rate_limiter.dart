/// 频率限制器
///
/// 用于限制同一操作的请求频率，防止短时间内重复请求。
/// 每个实例独立计时，记录上次请求时间，在冷却时间内拒绝请求。
class RateLimiter {
  RateLimiter(this.cooldown);

  /// 冷却时长
  final Duration cooldown;

  /// 上次请求时间
  DateTime? _lastRequest;

  /// 是否可以请求（冷却已过）
  bool get canRequest {
    if (_lastRequest == null) return true;
    return DateTime.now().difference(_lastRequest!) >= cooldown;
  }

  /// 剩余冷却时间（秒）
  int get remainingSeconds {
    if (_lastRequest == null) return 0;
    final elapsed = DateTime.now().difference(_lastRequest!);
    if (elapsed >= cooldown) return 0;
    return cooldown.inSeconds - elapsed.inSeconds;
  }

  /// 记录一次请求（重置冷却计时）
  void record() {
    _lastRequest = DateTime.now();
  }

  /// 重置（清除记录，立即允许下次请求）
  void reset() {
    _lastRequest = null;
  }
}
