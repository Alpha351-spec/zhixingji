import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/user_profile_service.dart';
import 'about_page.dart';
import 'edit_profile_page.dart';
import '../settings/settings_page.dart';

/// 个人中心页（Tab 3）
///
/// 微信风格布局：
/// - 顶部用户信息卡片（点击进入编辑页）
/// - 统计数据区
/// - 设置列表（关于我们 → 跳转独立页面）
class ProfilePage extends StatefulWidget {
  final double todayRate;
  final double weekRate;
  final int totalFocusMinutes;
  final String deadlineLabel;
  final int daysUntilDeadline;
  final VoidCallback? onRegeneratePlan;

  const ProfilePage({
    super.key,
    required this.todayRate,
    required this.weekRate,
    required this.totalFocusMinutes,
    required this.deadlineLabel,
    required this.daysUntilDeadline,
    this.onRegeneratePlan,
  });

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String _nickname = '';

  @override
  void initState() {
    super.initState();
    _refreshNickname();
  }

  void _refreshNickname() {
    setState(() {
      _nickname = UserProfileService.current.nickname;
    });
  }

  Future<void> _openEditProfile() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const EditProfilePage()),
    );
    if (result == true) {
      _refreshNickname();
    }
  }

  @override
  Widget build(BuildContext context) {
    final hours = widget.totalFocusMinutes ~/ 60;
    final minutes = widget.totalFocusMinutes % 60;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // ========== 顶部用户信息卡片 ==========
              // 点击进入个人信息编辑页
              InkWell(
                onTap: _openEditProfile,
                child: Container(
                  color: AppColors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 24),
                  child: Row(
                    children: [
                      // 头像
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.borderCard,
                            width: 0.5,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.asset(
                            'assets/images/app_icon.png',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  _nickname.isEmpty ? '点击设置昵称' : _nickname,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: _nickname.isEmpty
                                        ? AppColors.textTertiary
                                        : AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.accent
                                        .withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    '内测',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.accent,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              '点击编辑个人资料',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textTertiary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right,
                        color: AppColors.textTertiary,
                        size: 22,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 8),

              // ========== 学习统计 ==========
              Container(
                color: AppColors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '学习统计',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // 三列统计
                    Row(
                      children: [
                        _statItem(
                          '今日达成',
                          '${(widget.todayRate * 100).toInt()}%',
                        ),
                        _divider(),
                        _statItem(
                          '周达成率',
                          '${(widget.weekRate * 100).toInt()}%',
                        ),
                        _divider(),
                        _statItem(
                          '专注时长',
                          hours > 0
                              ? '${hours}h${minutes}m'
                              : '${minutes}m',
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // ========== 截止日期（仅在有截止日期时显示）==========
              if (widget.daysUntilDeadline >= 0) ...[
                Container(
                  color: AppColors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.event,
                            size: 20,
                            color: AppColors.accent.withValues(alpha: 0.7),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            widget.deadlineLabel,
                            style: const TextStyle(
                              fontSize: 15,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        widget.daysUntilDeadline > 0
                            ? '还有 ${widget.daysUntilDeadline} 天'
                            : '已到期',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: widget.daysUntilDeadline > 0
                              ? AppColors.accent
                              : AppColors.accentComplete,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],

              // ========== 功能列表 ==========
              Container(
                color: AppColors.white,
                child: Column(
                  children: [
                    // 重新生成计划
                    if (widget.onRegeneratePlan != null)
                      _listTile(
                        icon: Icons.refresh,
                        iconColor: AppColors.accent,
                        title: '重新生成计划',
                        onTap: widget.onRegeneratePlan,
                      ),
                    if (widget.onRegeneratePlan != null)
                      const Divider(height: 1, indent: 52),

                    // 设置
                    _listTile(
                      icon: Icons.settings_outlined,
                      iconColor: AppColors.textSecondary,
                      title: '设置',
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const SettingsPage(),
                          ),
                        );
                      },
                    ),
                    const Divider(height: 1, indent: 52),

                    // 关于我们
                    _listTile(
                      icon: Icons.info_outline,
                      iconColor: AppColors.accent,
                      title: '关于我们',
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const AboutPage(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              // 底部版本号
              Text(
                '知行计 v0.2.0',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textTertiary,
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  /// 三列统计中的单项
  Widget _statItem(String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() {
    return Container(
      width: 1,
      height: 30,
      color: AppColors.borderCard,
    );
  }

  /// 列表项（微信风格：图标 + 标题 + 箭头）
  Widget _listTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 22, color: iconColor),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
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
}
