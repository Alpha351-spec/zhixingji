import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/constants/app_constants.dart';

/// 底部导航栏（开发文档第3节）
///
/// 三个Tab：学习(书本/对勾) | 计划(对话气泡) | 我的(人像)
/// 高度72px，白底+0.5px上边框
class BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const BottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  static const List<_NavItem> _items = [
    _NavItem(icon: Icons.menu_book_outlined, label: '学习'),
    _NavItem(icon: Icons.chat_bubble_outline, label: '计划'),
    _NavItem(icon: Icons.person_outline, label: '我的'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: AppConstants.bottomNavHeight,
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(
          top: BorderSide(color: AppColors.borderCard, width: 0.5),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: List.generate(_items.length, (index) {
            final item = _items[index];
            final isActive = index == currentIndex;
            return Expanded(
              child: GestureDetector(
                onTap: () => onTap(index),
                behavior: HitTestBehavior.opaque,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // 激活态顶部小圆点
                    if (isActive)
                      Container(
                        width: 4,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 6),
                        decoration: const BoxDecoration(
                          color: AppColors.accent,
                          shape: BoxShape.circle,
                        ),
                      )
                    else
                      const SizedBox(height: 10),
                    Icon(
                      item.icon,
                      size: 20,
                      color: isActive
                          ? AppColors.accent
                          : AppColors.navInactive,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.label,
                      style: AppTextStyles.navLabel.copyWith(
                        color: isActive
                            ? AppColors.accent
                            : AppColors.navInactive,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;

  const _NavItem({required this.icon, required this.label});
}
