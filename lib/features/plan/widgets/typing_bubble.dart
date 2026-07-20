import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

/// AI 正在输入的加载气泡（开发文档第4.2节）
///
/// 左对齐，与 AI 消息气泡样式一致，显示三个跳动的圆点
class TypingBubble extends StatefulWidget {
  const TypingBubble({super.key});

  @override
  State<TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<TypingBubble>
    with TickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: const BoxDecoration(
          color: AppColors.bubbleAI,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(4),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(18),
            bottomRight: Radius.circular(18),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            return AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                // 每个点错开 0.2 秒
                final delay = index * 0.2;
                final t = (_controller.value - delay) % 1.0;
                // 在 0.0~0.5 区间做上跳动画
                final scale = t < 0.5 ? 1.0 + (0.5 - (t - 0.25).abs()) * 0.8 : 1.0;
                final opacity = t < 0.5 ? 1.0 : 0.4;
                return Opacity(
                  opacity: opacity,
                  child: Transform.scale(
                    scale: scale,
                    child: child,
                  ),
                );
              },
              child: Container(
                width: 6,
                height: 6,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: const BoxDecoration(
                  color: AppColors.textTertiary,
                  shape: BoxShape.circle,
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
