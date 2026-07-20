/// 全局常量（开发文档第6节 API + 第4节 UI 尺寸）
class AppConstants {
  AppConstants._();

  // ============ API 配置（开发文档第6节）============
  /// DeepSeek API 端点
  static const String apiEndpoint =
      'https://api.deepseek.com/v1/chat/completions';

  /// DeepSeek API 密钥（写死，后续引入云函数后移除）
  static const String apiKey = 'sk-8fa1304dd81d4431811c264180c37888';

  /// 使用的模型（deepseek-chat 对应最新版本，支持多轮对话）
  static const String model = 'deepseek-chat';

  /// 生成温度
  static const double temperature = 0.7;

  /// 最大 token 数（联网搜索 Function Calling 需要更多 token）
  static const int maxTokens = 3000;

  // ============ UI 尺寸（开发文档第4节）============

  /// 视图切换器胶囊尺寸 90x34
  static const double switcherWidth = 90;
  static const double switcherHeight = 34;
  static const double switcherRadius = 17;
  static const double switcherSpacing = 8;

  /// 横幅卡片高度 56px
  static const double bannerHeight = 56;

  /// 进度条尺寸（宽80px 高2px）
  static const double progressWidth = 80;
  static const double progressHeight = 2;

  /// 任务卡片内边距 16px，间距12px
  static const double taskCardPadding = 16;
  static const double taskCardSpacing = 12;

  /// 复选框 24x24，圆角4px
  static const double checkboxSize = 24;
  static const double checkboxRadius = 4;

  /// 计时圆环直径 240px，粗2px
  static const double timerRingDiameter = 240;
  static const double timerRingStroke = 2;

  /// 控制按钮 64x64 圆形
  static const double controlButtonSize = 64;

  /// 时长选择胶囊 80x32，圆角16px
  static const double durationPillWidth = 80;
  static const double durationPillHeight = 32;
  static const double durationPillRadius = 16;

  /// 底部导航栏高度 72px
  static const double bottomNavHeight = 72;

  /// 卡片圆角 8px
  static const double cardRadius = 8;

  /// 按钮圆角 6px
  static const double buttonRadius = 6;

  /// 页面边距 16px
  static const double pageMargin = 16;

  // ============ 番茄钟时长 ============
  /// 默认专注时长（分钟）
  static const int defaultFocusDuration = 25;
  /// 最小专注时长（分钟）
  static const int minFocusDuration = 1;
  /// 最大专注时长（分钟）
  static const int maxFocusDuration = 120;
}
