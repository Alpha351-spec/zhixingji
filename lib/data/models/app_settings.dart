/// 应用设置模型
///
/// 三大分类：学习偏好、通知与提醒、专注模式
class AppSettings {
  // ========== 一、学习偏好 ==========
  /// 资源显示模式：纯净模式 / 引导模式 / 资源模式
  final String resourceMode;

  /// 每日任务数：1-8，AI 生成计划时每天安排的任务数量
  final int dailyTaskLimit;

  /// 计划详细程度：精简 / 标准 / 详细
  final String planDetailLevel;

  /// 每周休息日（多选，存 weekday 数字 1-7）
  final List<int> restDays;

  // ========== 二、通知与提醒 ==========
  /// 每日打卡提醒开关
  final bool dailyReminder;

  /// 每日打卡提醒时间（24小时制，如 "20:00"）
  final String dailyReminderTime;

  /// 番茄钟完成通知
  final bool pomodoroNotification;

  /// 计划续订提醒
  final bool planRenewalReminder;

  /// 连续天数预警
  final bool streakWarning;

  // ========== 三、专注模式 ==========
  /// 软锁屏
  final bool softLockScreen;

  /// 默认专注时长（分钟）：15 / 25 / 45
  final int defaultFocusDuration;

  /// 专注白噪音
  final bool whiteNoise;

  /// 白噪音类型：雨声 / 森林 / 篝火 / 纯白噪音
  final String whiteNoiseType;

  const AppSettings({
    this.resourceMode = '纯净模式',
    this.dailyTaskLimit = 5,
    this.planDetailLevel = '标准',
    this.restDays = const [],
    this.dailyReminder = true,
    this.dailyReminderTime = '20:00',
    this.pomodoroNotification = true,
    this.planRenewalReminder = true,
    this.streakWarning = true,
    this.softLockScreen = true,
    this.defaultFocusDuration = 25,
    this.whiteNoise = false,
    this.whiteNoiseType = '雨声',
  });

  AppSettings copyWith({
    String? resourceMode,
    int? dailyTaskLimit,
    String? planDetailLevel,
    List<int>? restDays,
    bool? dailyReminder,
    String? dailyReminderTime,
    bool? pomodoroNotification,
    bool? planRenewalReminder,
    bool? streakWarning,
    bool? softLockScreen,
    int? defaultFocusDuration,
    bool? whiteNoise,
    String? whiteNoiseType,
  }) {
    return AppSettings(
      resourceMode: resourceMode ?? this.resourceMode,
      dailyTaskLimit: dailyTaskLimit ?? this.dailyTaskLimit,
      planDetailLevel: planDetailLevel ?? this.planDetailLevel,
      restDays: restDays ?? this.restDays,
      dailyReminder: dailyReminder ?? this.dailyReminder,
      dailyReminderTime: dailyReminderTime ?? this.dailyReminderTime,
      pomodoroNotification:
          pomodoroNotification ?? this.pomodoroNotification,
      planRenewalReminder:
          planRenewalReminder ?? this.planRenewalReminder,
      streakWarning: streakWarning ?? this.streakWarning,
      softLockScreen: softLockScreen ?? this.softLockScreen,
      defaultFocusDuration:
          defaultFocusDuration ?? this.defaultFocusDuration,
      whiteNoise: whiteNoise ?? this.whiteNoise,
      whiteNoiseType: whiteNoiseType ?? this.whiteNoiseType,
    );
  }

  Map<String, dynamic> toJson() => {
        'resourceMode': resourceMode,
        'dailyTaskLimit': dailyTaskLimit,
        'planDetailLevel': planDetailLevel,
        'restDays': restDays,
        'dailyReminder': dailyReminder,
        'dailyReminderTime': dailyReminderTime,
        'pomodoroNotification': pomodoroNotification,
        'planRenewalReminder': planRenewalReminder,
        'streakWarning': streakWarning,
        'softLockScreen': softLockScreen,
        'defaultFocusDuration': defaultFocusDuration,
        'whiteNoise': whiteNoise,
        'whiteNoiseType': whiteNoiseType,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
        resourceMode: json['resourceMode'] as String? ?? '纯净模式',
        dailyTaskLimit: json['dailyTaskLimit'] as int? ?? 5,
        planDetailLevel: json['planDetailLevel'] as String? ?? '标准',
        restDays: (json['restDays'] as List<dynamic>?)
                ?.map((e) => e as int)
                .toList() ??
            const [],
        dailyReminder: json['dailyReminder'] as bool? ?? true,
        dailyReminderTime: json['dailyReminderTime'] as String? ?? '20:00',
        pomodoroNotification:
            json['pomodoroNotification'] as bool? ?? true,
        planRenewalReminder:
            json['planRenewalReminder'] as bool? ?? true,
        streakWarning: json['streakWarning'] as bool? ?? true,
        softLockScreen: json['softLockScreen'] as bool? ?? true,
        defaultFocusDuration: json['defaultFocusDuration'] as int? ?? 25,
        whiteNoise: json['whiteNoise'] as bool? ?? false,
        whiteNoiseType: json['whiteNoiseType'] as String? ?? '雨声',
      );
}
