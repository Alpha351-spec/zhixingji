import 'package:flutter/foundation.dart';

/// API Key 管理服务（当前已写死，保留接口供后续云函数迁移使用）
class ApiKeyService {
  ApiKeyService._();

  /// 加载 API Key（当前无需操作，已写死在 AppConstants 中）
  static Future<void> load() async {
    debugPrint('[ApiKeyService] API Key 已内置');
  }
}
