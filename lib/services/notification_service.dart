import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

/// 本地通知服务
///
/// 管理所有本地通知的权限请求、调度与取消。
/// 使用 flutter_local_notifications 22.x 实现跨平台通知。
class NotificationService {
  NotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  /// 是否已初始化
  static bool _initialized = false;

  // ============ 通知 ID 常量 ============
  static const int _dailyReminderId = 1001;
  static const int _pomodoroCompleteId = 1002;
  static const int _planRenewalId = 1003;
  static const int _streakWarningId = 1004;

  /// 初始化通知插件并请求权限
  ///
  /// 首次启动时调用。请求系统通知权限。
  static Future<void> init() async {
    if (_initialized) return;

    // 初始化时区数据（用于定时通知）
    tz_data.initializeTimeZones();

    // 构建各平台初始化设置
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const linuxSettings = LinuxInitializationSettings(
      defaultActionName: '打开',
    );
    // Windows 需要 AppUserModelId 和 GUID，在桌面开发环境下
    // 使用简单的占位值（打包 MSIX 时需替换为真实值）
    final windowsSettings = WindowsInitializationSettings(
      appName: '知行计',
      appUserModelId: _getAppUserModelId(),
      guid: _getGuid(),
    );

    const webSettings = WebInitializationSettings();

    final initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
      macOS: iosSettings,
      linux: linuxSettings,
      windows: windowsSettings,
      web: webSettings,
    );

    await _plugin.initialize(settings: initSettings);

    // 请求通知权限（iOS/macOS/Android 13+）
    await _requestPermissions();

    _initialized = true;
  }

  /// 获取 Windows AppUserModelId（开发环境用占位符）
  static String _getAppUserModelId() {
    // 开发阶段使用占位值
    // 打包 MSIX 时需替换为应用的 AppUserModelId
    return 'xuejing.app';
  }

  /// 获取 Windows 通知 GUID（开发环境用占位符）
  static String _getGuid() {
    // 开发阶段使用占位 GUID（打包 MSIX 时需替换为真实值）
    return '00000000-0000-0000-0000-000000000001';
  }

  /// 请求系统通知权限
  static Future<void> _requestPermissions() async {
    try {
      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        await androidPlugin.requestNotificationsPermission();
      }

      final iosPlugin = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      if (iosPlugin != null) {
        await iosPlugin.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
      }

      final macosPlugin = _plugin.resolvePlatformSpecificImplementation<
          MacOSFlutterLocalNotificationsPlugin>();
      if (macosPlugin != null) {
        await macosPlugin.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
      }
    } catch (e) {
      // ignore: avoid_print
      print('[NotificationService] 请求权限失败: $e');
    }
  }

  /// 取消所有通知
  static Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  /// 取消指定 ID 的通知
  static Future<void> cancel({required int id}) async {
    await _plugin.cancel(id: id);
  }

  // ============ 每日打卡提醒 ============

  /// 调度每日打卡提醒
  ///
  /// [hour] 小时（24小时制），[minute] 分钟。
  /// 使用每天同一时间重复的定时通知。
  static Future<void> scheduleDailyReminder(int hour, int minute) async {
    await cancel(id: _dailyReminderId);

    final now = DateTime.now();
    var scheduledDate = DateTime(now.year, now.month, now.day, hour, minute);
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    await _plugin.zonedSchedule(
      id: _dailyReminderId,
      title: '📋 今日打卡提醒',
      body: '别忘了完成今日学习任务哦！',
      scheduledDate: tz.TZDateTime.from(scheduledDate, tz.local),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_reminder',
          '每日打卡提醒',
          channelDescription: '每天提醒你完成学习任务',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  // ============ 番茄钟完成通知 ============

  /// 立即显示番茄钟完成通知
  static Future<void> showPomodoroComplete() async {
    await _plugin.show(
      id: _pomodoroCompleteId,
      title: '🍅 番茄钟完成',
      body: '专注时间到了，休息一下吧！',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'pomodoro',
          '番茄钟通知',
          channelDescription: '番茄钟专注完成提醒',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  }

  // ============ 计划续订提醒 ============

  /// 调度计划续订提醒（当前周的最后一天触发）
  static Future<void> schedulePlanRenewal(int currentWeek, int totalDays) async {
    await cancel(id: _planRenewalId);

    // 第 7 天（或总天数不足时用总天数）晚上 20:00 提醒
    final reminderDay = totalDays < 7 ? totalDays : 7;
    final now = DateTime.now();
    // 计算本周 reminderDay 的日期
    final todayWeekday = now.weekday; // 1=周一, 7=周日
    final daysUntilReminder = reminderDay - todayWeekday;
    final reminderDate = DateTime(
      now.year,
      now.month,
      now.day + (daysUntilReminder > 0 ? daysUntilReminder : 7 + daysUntilReminder),
      20, 0,
    );

    if (reminderDate.isBefore(now) && reminderDate.day == now.day && reminderDate.hour < now.hour) {
      // 如果已经过了今天的提醒时间，则不调度
      return;
    }

    await _plugin.zonedSchedule(
      id: _planRenewalId,
      title: '🔄 计划续订提醒',
      body: '本周学习任务即将完成，点击续订下周计划吧！',
      scheduledDate: tz.TZDateTime.from(reminderDate, tz.local),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'plan_renewal',
          '计划续订提醒',
          channelDescription: '提醒你续订每周学习计划',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );
  }

  // ============ 连续天数预警 ============

  /// 调度连续打卡中断预警（当天晚上 21:00 触发）
  static Future<void> scheduleStreakWarning() async {
    await cancel(id: _streakWarningId);

    final now = DateTime.now();
    final warningTime = DateTime(now.year, now.month, now.day, 21, 0);
    if (warningTime.isBefore(now)) return;

    await _plugin.zonedSchedule(
      id: _streakWarningId,
      title: '⚠️ 连续打卡预警',
      body: '今天还没完成学习任务，坚持就是胜利！',
      scheduledDate: tz.TZDateTime.from(warningTime, tz.local),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'streak_warning',
          '连续打卡预警',
          channelDescription: '连续打卡中断时提醒',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  // ============ 根据设置统一调度 ============

  /// 根据当前设置调度所有通知
  ///
  /// 在设置变更后调用，统一处理启用/关闭。
  static Future<void> applySettings({
    required bool dailyReminder,
    required String dailyReminderTime,
    required bool pomodoroNotification,
    required bool planRenewalReminder,
    required bool streakWarning,
  }) async {
    if (!_initialized) return;

    // 每日打卡提醒
    if (dailyReminder) {
      final parts = dailyReminderTime.split(':');
      final hour = int.tryParse(parts[0]) ?? 20;
      final minute = int.tryParse(parts[1]) ?? 0;
      await scheduleDailyReminder(hour, minute);
    } else {
      await cancel(id: _dailyReminderId);
    }

    // 番茄钟完成通知（由番茄钟完成时即时触发，不调度定时）
    if (!pomodoroNotification) {
      // 无定时通知可取消
    }

    // 计划续订提醒
    if (!planRenewalReminder) {
      await cancel(id: _planRenewalId);
    }

    // 连续天数预警
    if (!streakWarning) {
      await cancel(id: _streakWarningId);
    }
  }
}
