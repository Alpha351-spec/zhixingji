import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

/// 验证结果视图
///
/// 显示验证通过或未通过的结果，通过时播放印章动画。
class VerificationResultView extends StatefulWidget {
  final bool passed;
  final String feedback;
  final String? suggestion;
  final VoidCallback onRetry;
  final VoidCallback onComplete;

  const VerificationResultView({
    super.key,
    required this.passed,
    required this.feedback,
    this.suggestion,
    required this.onRetry,
    required this.onComplete,
  });

  @override
  State<VerificationResultView> createState() => _VerificationResultViewState();
}

class _VerificationResultViewState extends State<VerificationResultView>
    with SingleTickerProviderStateMixin {
  late AnimationController _stampController;
  late Animation<double> _scaleAnim;
  late Animation<double> _opacityAnim;

  @override
  void initState() {
    super.initState();
    _stampController = AnimationController(
      duration: const Duration(milliseconds: 550),
      vsync: this,
    );
    _scaleAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.4, end: 1.15), weight: 55),
      TweenSequenceItem(tween: Tween(begin: 1.15, end: 0.92), weight: 15),
      TweenSequenceItem(tween: Tween(begin: 0.92, end: 1.06), weight: 15),
      TweenSequenceItem(tween: Tween(begin: 1.06, end: 1.0), weight: 15),
    ]).animate(_stampController);
    _opacityAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.88), weight: 60),
    ]).animate(_stampController);

    if (widget.passed) {
      _stampController.forward();
    }
  }

  @override
  void dispose() {
    _stampController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 印章图标或失败图标
            if (widget.passed)
              AnimatedBuilder(
                animation: _stampController,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _scaleAnim.value,
                    child: Opacity(opacity: _opacityAnim.value, child: child),
                  );
                },
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.accentComplete,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    '完成',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              )
            else
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.bubbleAI,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.lightbulb_outline,
                  size: 40,
                  color: AppColors.textSecondary,
                ),
              ),
            const SizedBox(height: 24),
            // 标题
            Text(
              widget.passed ? '验证通过' : '还需巩固',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: widget.passed ? AppColors.accentComplete : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            // 反馈
            Text(
              widget.feedback,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.6,
              ),
            ),
            // 建议（未通过时显示）
            if (!widget.passed && widget.suggestion != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.bubbleAI,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  widget.suggestion!,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textPrimary,
                    height: 1.5,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 32),
            // 按钮
            if (widget.passed)
              ElevatedButton(
                onPressed: widget.onComplete,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentComplete,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 48),
                ),
                child: const Text('完成打卡'),
              )
            else ...[
              ElevatedButton(
                onPressed: widget.onRetry,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 48),
                ),
                child: const Text('重新验证'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: widget.onComplete,
                child: const Text(
                  '继续学习后再来',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
