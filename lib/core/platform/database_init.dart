/// 平台特定的数据库初始化
///
/// 使用条件导出：移动端用 sqflite，桌面端用 sqflite_common_ffi
export 'database_init_native.dart'
    if (dart.library.html) 'database_init_stub.dart';
