import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'table_definitions.dart';

/// SQLite 数据库助手（开发文档第5节）
///
/// 管理两张表：
/// - [TableDefinitions.tableCurrentPlan]：当前活跃学习计划
/// - [TableDefinitions.tableUserStats]：用户学习统计
///
/// 数据库文件：zhixue_daka.db
class DatabaseHelper {
  static Database? _database;

  /// 获取数据库单例
  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// 初始化数据库
  static Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, TableDefinitions.dbName);

    return await openDatabase(
      path,
      version: TableDefinitions.dbVersion,
      onCreate: (db, version) async {
        // 首次创建：同时建所有表
        await db.execute(TableDefinitions.createCurrentPlanTable);
        await db.execute(TableDefinitions.createUserStatsTable);
        await db.execute(TableDefinitions.createVerificationRecordsTable);
        await db.execute(TableDefinitions.createChatHistoryTable);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        // v1 → v2：新增 user_stats 表
        if (oldVersion < 2) {
          await db.execute(TableDefinitions.upgradeV1ToV2);
        }
        // v2 → v3：current_plan 新增 deadline、total_days、current_week
        if (oldVersion < 3) {
          for (final sql in TableDefinitions.upgradeV2ToV3) {
            try {
              await db.execute(sql);
            } catch (_) {
              // 字段可能已存在，忽略
            }
          }
        }
        // v3 → v4：新增 verification_records 表
        if (oldVersion < 4) {
          await db.execute(TableDefinitions.upgradeV3ToV4);
        }
        // v4 → v5：新增 chat_history 表
        if (oldVersion < 5) {
          await db.execute(TableDefinitions.upgradeV4ToV5);
        }
      },
    );
  }

  // ============ current_plan 操作 ============

  /// 保存或更新当前计划（id 固定为1）
  static Future<int> upsertPlan(Map<String, dynamic> plan) async {
    final db = await database;
    return await db.insert(
      TableDefinitions.tableCurrentPlan,
      plan,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 获取当前活跃计划
  static Future<Map<String, dynamic>?> getPlan() async {
    final db = await database;
    final results = await db.query(
      TableDefinitions.tableCurrentPlan,
      where: 'id = ?',
      whereArgs: [1],
      limit: 1,
    );
    if (results.isEmpty) return null;
    return results.first;
  }

  /// 删除当前计划（重新生成时调用）
  static Future<int> deletePlan() async {
    final db = await database;
    return await db.delete(
      TableDefinitions.tableCurrentPlan,
      where: 'id = ?',
      whereArgs: [1],
    );
  }

  // ============ user_stats 操作 ============

  /// 获取用户统计（id 固定为1，首次访问时自动初始化）
  static Future<Map<String, dynamic>> getStats() async {
    final db = await database;
    final results = await db.query(
      TableDefinitions.tableUserStats,
      where: 'id = ?',
      whereArgs: [1],
      limit: 1,
    );

    if (results.isEmpty) {
      // 首次访问，插入默认行
      final defaultStats = {
        'id': 1,
        'total_days_completed': 0,
        'total_focus_minutes': 0,
        'current_streak': 0,
        'last_completed_date': null,
      };
      await db.insert(
        TableDefinitions.tableUserStats,
        defaultStats,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return defaultStats;
    }

    return results.first;
  }

  /// 更新用户统计（整体覆盖，id 固定为1）
  static Future<int> updateStats(Map<String, dynamic> stats) async {
    final db = await database;
    final data = Map<String, dynamic>.from(stats);
    data['id'] = 1; // 确保固定 id

    return await db.insert(
      TableDefinitions.tableUserStats,
      data,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 累加专注时长（增量更新）
  ///
  /// [minutes] 为本次新增的专注分钟数
  static Future<void> addFocusMinutes(int minutes) async {
    final db = await database;
    final stats = await getStats();

    final currentMinutes = stats['total_focus_minutes'] as int? ?? 0;
    await updateStats({
      'total_focus_minutes': currentMinutes + minutes,
    });
  }

  /// 记录完成一天的学习任务（更新连续打卡天数）
  ///
  /// 返回更新后的统计。连续打卡逻辑：
  /// - 如果 last_completed_date 是昨天 → current_streak + 1
  /// - 如果 last_completed_date 是今天 → 不重复计算
  /// - 否则 → current_streak 重置为 1
  static Future<Map<String, dynamic>> recordDayCompleted() async {
    final db = await database;
    final stats = await getStats();

    final now = DateTime.now();
    final today = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    final lastDateStr = stats['last_completed_date'] as String?;
    final currentStreak = stats['current_streak'] as int? ?? 0;
    final totalDays = stats['total_days_completed'] as int? ?? 0;

    int newStreak;
    int newTotalDays = totalDays;

    if (lastDateStr == today) {
      // 今天已完成过，不重复计数
      newStreak = currentStreak;
    } else if (lastDateStr != null) {
      final lastDate = DateTime.tryParse(lastDateStr);
      if (lastDate != null) {
        final yesterday = now.subtract(const Duration(days: 1));
        final yesterdayStr = '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';
        if (lastDateStr == yesterdayStr) {
          // 昨天完成过 → 连续+1
          newStreak = currentStreak + 1;
        } else {
          // 中断 → 重新开始
          newStreak = 1;
        }
      } else {
        newStreak = 1;
      }
      newTotalDays = totalDays + 1;
    } else {
      // 首次完成
      newStreak = 1;
      newTotalDays = 1;
    }

    final updatedStats = {
      'total_days_completed': newTotalDays,
      'total_focus_minutes': stats['total_focus_minutes'],
      'current_streak': newStreak,
      'last_completed_date': today,
    };

    await updateStats(updatedStats);
    return await getStats();
  }

  // ============ verification_records 操作 ============

  /// 插入一条验证记录
  static Future<int> insertVerificationRecord(Map<String, dynamic> record) async {
    final db = await database;
    return await db.insert(
      TableDefinitions.tableVerificationRecords,
      record,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 查询某个任务的所有验证记录
  static Future<List<Map<String, dynamic>>> getVerificationRecords(int taskDay) async {
    final db = await database;
    return await db.query(
      TableDefinitions.tableVerificationRecords,
      where: 'task_day = ?',
      whereArgs: [taskDay],
      orderBy: 'created_at DESC',
    );
  }

  /// 查询某个任务的最近一次验证记录
  static Future<Map<String, dynamic>?> getLatestVerificationRecord(int taskDay) async {
    final db = await database;
    final results = await db.query(
      TableDefinitions.tableVerificationRecords,
      where: 'task_day = ?',
      whereArgs: [taskDay],
      orderBy: 'created_at DESC',
      limit: 1,
    );
    if (results.isEmpty) return null;
    return results.first;
  }

  // ============ chat_history 操作 ============

  /// 插入一条聊天记录
  static Future<int> insertChatMessage(Map<String, dynamic> message) async {
    final db = await database;
    return await db.insert(
      TableDefinitions.tableChatHistory,
      message,
    );
  }

  /// 查询全部聊天记录（按时间正序）
  static Future<List<Map<String, dynamic>>> getAllChatHistory() async {
    final db = await database;
    return await db.query(
      TableDefinitions.tableChatHistory,
      orderBy: 'id ASC',
    );
  }

  /// 清空全部聊天记录
  static Future<void> clearChatHistory() async {
    final db = await database;
    await db.delete(TableDefinitions.tableChatHistory);
  }

  /// 关闭数据库
  static Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}
