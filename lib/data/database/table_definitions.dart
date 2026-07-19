/// 数据库表定义（开发文档第5节）
class TableDefinitions {
  TableDefinitions._();

  /// 数据库名称
  static const String dbName = 'zhixue_daka.db';

  /// 数据库版本
  static const int dbVersion = 4;

  /// 当前活跃计划表
  static const String tableCurrentPlan = 'current_plan';

  /// 用户学习统计表
  static const String tableUserStats = 'user_stats';

  /// 验证记录表
  static const String tableVerificationRecords = 'verification_records';

  /// 建表 SQL：当前活跃计划（v3：新增 deadline、total_days、current_week）
  static const String createCurrentPlanTable = '''
    CREATE TABLE IF NOT EXISTS $tableCurrentPlan (
      id INTEGER PRIMARY KEY,
      goal TEXT NOT NULL,
      diagnosis_json TEXT NOT NULL,
      tasks_json TEXT NOT NULL,
      created_at TEXT NOT NULL,
      deadline TEXT NOT NULL DEFAULT '',
      total_days INTEGER NOT NULL DEFAULT 0,
      current_week INTEGER NOT NULL DEFAULT 1
    )
  ''';

  /// 建表 SQL：用户学习统计
  static const String createUserStatsTable = '''
    CREATE TABLE IF NOT EXISTS $tableUserStats (
      id INTEGER PRIMARY KEY,
      total_days_completed INTEGER NOT NULL DEFAULT 0,
      total_focus_minutes INTEGER NOT NULL DEFAULT 0,
      current_streak INTEGER NOT NULL DEFAULT 0,
      last_completed_date TEXT
    )
  ''';

  /// 建表 SQL：验证记录表（v4 新增）
  static const String createVerificationRecordsTable = '''
    CREATE TABLE IF NOT EXISTS $tableVerificationRecords (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      task_day INTEGER NOT NULL,
      plan_id INTEGER NOT NULL,
      verification_type TEXT NOT NULL,
      questions_json TEXT,
      user_answer TEXT,
      ai_evaluation TEXT,
      passed INTEGER NOT NULL,
      created_at TEXT NOT NULL
    )
  ''';

  /// v3 → v4：新增 verification_records 表
  static const String upgradeV3ToV4 = '''
    CREATE TABLE IF NOT EXISTS $tableVerificationRecords (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      task_day INTEGER NOT NULL,
      plan_id INTEGER NOT NULL,
      verification_type TEXT NOT NULL,
      questions_json TEXT,
      user_answer TEXT,
      ai_evaluation TEXT,
      passed INTEGER NOT NULL,
      created_at TEXT NOT NULL
    )
  ''';

  /// v1 → v2：新增 user_stats 表
  static const String upgradeV1ToV2 = '''
    CREATE TABLE IF NOT EXISTS $tableUserStats (
      id INTEGER PRIMARY KEY,
      total_days_completed INTEGER NOT NULL DEFAULT 0,
      total_focus_minutes INTEGER NOT NULL DEFAULT 0,
      current_streak INTEGER NOT NULL DEFAULT 0,
      last_completed_date TEXT
    )
  ''';

  /// v2 → v3：current_plan 表新增 deadline、total_days、current_week 字段
  /// SQLite 的 ALTER TABLE 只支持 ADD COLUMN，不支持修改已有列
  static const List<String> upgradeV2ToV3 = [
    "ALTER TABLE $tableCurrentPlan ADD COLUMN deadline TEXT NOT NULL DEFAULT ''",
    'ALTER TABLE $tableCurrentPlan ADD COLUMN total_days INTEGER NOT NULL DEFAULT 0',
    'ALTER TABLE $tableCurrentPlan ADD COLUMN current_week INTEGER NOT NULL DEFAULT 1',
  ];
}
