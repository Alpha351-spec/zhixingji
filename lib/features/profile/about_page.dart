import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// 关于我们页面（参考微信关于页布局）
///
/// 布局结构：
/// - 左上角返回按钮
/// - 上部居中：应用图标 → 应用名 → 版本号
/// - 中部：三个功能按钮行（功能介绍 / 意见反馈 / 检查更新）
/// - 底部：隐私政策、服务协议等法律信息
class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        centerTitle: false,
        title: const SizedBox.shrink(),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios,
            size: 20,
            color: AppColors.textPrimary,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          // ========== 上部：品牌信息区 ==========
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 24),

                  // 应用图标
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: AppColors.borderCard,
                        width: 0.5,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: Image.asset(
                        'assets/images/app_icon.png',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 应用名
                  const Text(
                    '知行计',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // 版本号
                  const Text(
                    'Version 0.2.0',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textTertiary,
                    ),
                  ),

                  const SizedBox(height: 40),

                  // ========== 中部：功能按钮列表 ==========
                  _listTile(
                    title: '功能介绍',
                    onTap: () => _showFeatureIntro(context),
                  ),
                  _divider(),

                  _listTile(
                    title: '意见反馈',
                    onTap: () => _showFeedback(context),
                  ),
                  _divider(),

                  _listTile(
                    title: '检查更新',
                    onTap: () => _checkUpdate(context),
                  ),
                ],
              ),
            ),
          ),

          // ========== 底部：法律信息区 ==========
          Padding(
            padding: const EdgeInsets.only(left: 20, right: 20, bottom: 16),
            child: Column(
              children: [
                // 隐私政策和服务协议
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 4,
                  runSpacing: 2,
                  children: [
                    _linkText('《软件许可及服务协议》', () => _showAgreement(context)),
                    _linkText('《隐私保护指引》', () => _showPrivacy(context)),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  '知行计团队 版权所有',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textTertiary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Copyright © 2026 知行计. All Rights Reserved.',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.textTertiary.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 列表项（微信风格：左标题 + 右箭头 + 分隔线）
  Widget _listTile({
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: AppColors.textTertiary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  /// 分隔线（左右留边距，微信风格）
  Widget _divider() {
    return const Padding(
      padding: EdgeInsets.only(left: 20),
      child: Divider(
        height: 1,
        thickness: 0.5,
        color: AppColors.borderCard,
      ),
    );
  }

  /// 可点击的法律文本链接
  Widget _linkText(String text, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          color: AppColors.textSecondary,
          decoration: TextDecoration.none,
        ),
      ),
    );
  }

  // ============ 功能按钮处理 ============

  void _showFeatureIntro(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('功能介绍'),
        content: const Text(
          '知行计是一款 AI 驱动的学习计划工具。\n\n'
          '核心功能：\n'
          '• AI 对话诊断：通过多轮对话了解你的目标和现状\n'
          '• 个性化计划：生成 7 天滚动学习任务清单\n'
          '• 番茄钟专注：软锁屏防止手机分心\n'
          '• 学习统计：达成率、专注时长可视化',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  void _showFeedback(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('意见反馈'),
        content: const Text(
          '如有问题或建议，欢迎反馈。\n\n'
          '本应用目前处于内测阶段，感谢您的使用。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  void _checkUpdate(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('当前已是最新版本'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _showAgreement(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('软件许可及服务协议'),
        content: const SingleChildScrollView(
          child: Text(
            '知行计软件许可及服务协议\n\n'
            '欢迎使用知行计。使用本应用即表示您同意以下条款：\n\n'
            '1. 本应用提供 AI 驱动的学习计划生成服务。\n'
            '2. 用户数据存储在本地设备，并支持通过云端同步在多设备间共享（需您手动开启）。\n'
            '3. AI 生成的内容仅供参考，不构成专业建议。\n'
            '4. 请勿将本应用用于违法用途。\n\n'
            '如有疑问，请联系开发者。',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  void _showPrivacy(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('隐私保护指引'),
        content: const SingleChildScrollView(
          child: Text(
            '知行计隐私保护指引\n\n'
            '我们重视您的隐私保护：\n\n'
            '1. 信息收集：本应用生成唯一用户码用于标识您的身份，不收集姓名、身份证等个人身份信息。您主动填写的昵称、手机号、邮箱由您自愿提供。\n'
            '2. 数据存储：学习计划、任务数据、打卡记录默认存储在您的设备本地。如您开启云端同步，相关数据将上传至云端服务器以便多设备共享。\n'
            '3. 网络请求：与 DeepSeek AI API 通信以生成学习计划，与 Supabase 云端数据库通信以同步数据（仅在您开启同步时）。\n'
            '4. 权限说明：\n'
            '   • 网络权限：用于调用 AI 服务和云端同步\n'
            '   • 悬浮窗权限：用于番茄钟锁屏功能\n'
            '   • 通知权限：用于每日打卡提醒、番茄钟完成提醒等\n'
            '   • 精确闹钟权限：用于定时通知调度\n'
            '5. 数据安全：云端数据通过加密传输，仅您本人可访问。您可随时在设置中关闭云端同步，数据将仅保留在本地。\n\n'
            '如有疑问，请联系开发者。',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }
}
