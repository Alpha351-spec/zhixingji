import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 番茄钟软锁屏服务（Flutter 端）
///
/// 封装与 Android 原生 LockScreenService 的 MethodChannel 通信。
/// 仅在 Android 平台生效，其他平台为空操作。
///
/// 原生端通过 MethodChannel 回调：
/// - `on_abandon_focus`：用户点击"放弃专注"按钮
class LockScreenService {
  LockScreenService._();

  static const _channel = MethodChannel('com.zhixingji.zhixingji/lock_screen');

  /// 放弃专注回调
  static void Function()? onAbandonFocus;

  /// 初始化 MethodChannel 回调监听
  static void init() {
    if (!Platform.isAndroid) return;

    _channel.setMethodCallHandler((call) async {
      debugPrint('[LockScreenService] 收到原生回调: ${call.method}');
      switch (call.method) {
        case 'on_abandon_focus':
          debugPrint('[LockScreenService] 用户放弃专注');
          onAbandonFocus?.call();
          break;
        default:
          debugPrint('[LockScreenService] 未知方法: ${call.method}');
      }
    });

    debugPrint('[LockScreenService] MethodChannel 已初始化');
  }

  /// 检查是否有悬浮窗权限（仅 Android）
  static Future<bool> canDrawOverlays() async {
    if (!Platform.isAndroid) return true;
    try {
      final result = await _channel.invokeMethod<bool>('canDrawOverlays');
      return result ?? false;
    } catch (e) {
      debugPrint('[LockScreenService] canDrawOverlays 失败: $e');
      return false;
    }
  }

  /// 请求悬浮窗权限（引导用户跳转系统设置）
  static Future<void> requestOverlayPermission() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<bool>('requestOverlayPermission');
    } catch (e) {
      debugPrint('[LockScreenService] requestOverlayPermission 失败: $e');
    }
  }

  /// 显示锁屏覆盖层
  ///
  /// [timeRemaining] 剩余秒数
  static Future<void> showLockScreen(int timeRemaining) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<bool>('showLockScreen', {
        'timeRemaining': timeRemaining,
      });
      debugPrint('[LockScreenService] showLockScreen: $timeRemaining 秒');
    } catch (e) {
      debugPrint('[LockScreenService] showLockScreen 失败: $e');
    }
  }

  /// 隐藏锁屏覆盖层
  static Future<void> hideLockScreen() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<bool>('hideLockScreen');
      debugPrint('[LockScreenService] hideLockScreen');
    } catch (e) {
      debugPrint('[LockScreenService] hideLockScreen 失败: $e');
    }
  }

  /// 更新锁屏上的倒计时显示
  ///
  /// [secondsRemaining] 剩余秒数
  static Future<void> updateCountdown(int secondsRemaining) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<bool>('updateCountdown', {
        'secondsRemaining': secondsRemaining,
      });
    } catch (e) {
      debugPrint('[LockScreenService] updateCountdown 失败: $e');
    }
  }
}
