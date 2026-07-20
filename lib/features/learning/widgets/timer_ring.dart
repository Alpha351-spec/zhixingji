import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/constants/app_constants.dart';

/// 计时圆环
///
/// 直径240px，圆环粗2px（底色边框色，进度色松烟墨绿）
/// 中心：剩余时间 + 副标题，或自定义中心内容（如滚轮选择器）
class TimerRing extends StatelessWidget {
  final String timeDisplay;
  final String subtitle;
  final double progress; // 0.0 ~ 1.0
  final bool isCompleted;

  /// 自定义中心内容（优先于 timeDisplay/subtitle）
  final Widget? centerWidget;

  const TimerRing({
    super.key,
    required this.timeDisplay,
    required this.subtitle,
    required this.progress,
    this.isCompleted = false,
    this.centerWidget,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: AppConstants.timerRingDiameter,
      height: AppConstants.timerRingDiameter,
      child: Stack(
        children: [
          // 圆环
          CustomPaint(
            size: const Size(
              AppConstants.timerRingDiameter,
              AppConstants.timerRingDiameter,
            ),
            painter: _RingPainter(progress: progress),
          ),
          // 中心内容
          Center(
            child: centerWidget ??
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      timeDisplay,
                      style: AppTextStyles.timer,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isCompleted ? '完成 ✨' : subtitle,
                      style: AppTextStyles.timerSubtitle,
                    ),
                  ],
                ),
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;

  _RingPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - AppConstants.timerRingStroke) / 2;

    // 底色圆环
    final trackPaint = Paint()
      ..color = AppColors.progressTrack
      ..style = PaintingStyle.stroke
      ..strokeWidth = AppConstants.timerRingStroke;
    canvas.drawCircle(center, radius, trackPaint);

    // 进度圆环
    final progressPaint = Paint()
      ..color = AppColors.accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = AppConstants.timerRingStroke
      ..strokeCap = StrokeCap.round;

    final sweepAngle = 2 * 3.141592653589793 * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -3.141592653589793 / 2, // 从顶部开始
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
