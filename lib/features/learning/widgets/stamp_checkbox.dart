import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/app_constants.dart';

/// 打卡印章复选框
///
/// 点击完成时播放朱砂红印章盖章动画：
/// 1. 印章从上方旋转落下（0-300ms）：translateY -40→0, rotate -18°→-8°, scale 1.4→1.15
/// 2. 落地回弹挤压（300-550ms）：scale 1.15→0.92→1.06→1.0
/// 3. 墨迹扩散（280-780ms）：半透明朱砂红圆形 scale 0→2.8
/// 4. 印章定格：opacity 0.88，模拟印泥半透明效果
///
/// 设计依据：AppColors.accentComplete (#C8553D) 朱砂红，注释标注"仅打卡完成瞬间使用"
class StampCheckbox extends StatefulWidget {
  final bool completed;

  final VoidCallback onTap;

  const StampCheckbox({
    super.key,
    required this.completed,
    required this.onTap,
  });

  @override
  State<StampCheckbox> createState() => _StampCheckboxState();
}

class _StampCheckboxState extends State<StampCheckbox>
    with TickerProviderStateMixin {
  late AnimationController _stampController;
  late Animation<double> _scaleAnim;
  late Animation<double> _translateYAnim;
  late Animation<double> _rotateAnim;
  late Animation<double> _opacityAnim;

  late AnimationController _splashController;
  late Animation<double> _splashScale;
  late Animation<double> _splashOpacity;

  bool _wasCompleted = false;

  /// 印章尺寸（比复选框大 6px，覆盖居中）
  static const double _stampSize = AppConstants.checkboxSize + 6;

  @override
  void initState() {
    super.initState();
    _wasCompleted = widget.completed;

    _stampController = AnimationController(
      duration: const Duration(milliseconds: 550),
      vsync: this,
    );

    // 印章缩放：落下 1.4→1.15，回弹 1.15→0.92→1.06→1.0
    _scaleAnim = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 1.4, end: 1.15),
        weight: 55,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.15, end: 0.92),
        weight: 15,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 0.92, end: 1.06),
        weight: 15,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.06, end: 1.0),
        weight: 15,
      ),
    ]).animate(CurvedAnimation(parent: _stampController, curve: Curves.linear));

    // 印章位移：落下阶段 -40→0
    _translateYAnim = Tween<double>(begin: -40, end: 0).animate(
      CurvedAnimation(
        parent: _stampController,
        curve: const Interval(0, 0.55, curve: Curves.easeIn),
      ),
    );

    // 印章旋转：-18°→-8°
    _rotateAnim = Tween<double>(begin: -18, end: -8).animate(
      CurvedAnimation(
        parent: _stampController,
        curve: const Interval(0, 0.55, curve: Curves.easeIn),
      ),
    );

    // 印章透明度：0→1→0.88（定格）
    _opacityAnim = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 1.0),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.88),
        weight: 60,
      ),
    ]).animate(_stampController);

    // 墨迹扩散
    _splashController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _splashScale = Tween<double>(begin: 0, end: 2.8).animate(
      CurvedAnimation(parent: _splashController, curve: Curves.easeOut),
    );
    _splashOpacity = Tween<double>(begin: 0.5, end: 0).animate(
      CurvedAnimation(parent: _splashController, curve: Curves.easeOut),
    );

    // 初始已完成的状态，直接将动画设到定格帧
    if (widget.completed) {
      _stampController.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(StampCheckbox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.completed && !_wasCompleted) {
      // 未完成→完成：触发盖章动画
      HapticFeedback.heavyImpact();
      _stampController.forward(from: 0);
      Future.delayed(const Duration(milliseconds: 280), () {
        if (mounted) _splashController.forward(from: 0);
      });
    } else if (!widget.completed && _wasCompleted) {
      // 完成→未完成：重置
      _stampController.value = 0;
      _splashController.value = 0;
    }
    _wasCompleted = widget.completed;
  }

  @override
  void dispose() {
    _stampController.dispose();
    _splashController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const size = AppConstants.checkboxSize;

    return GestureDetector(
      onTap: _handleTap,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            // 墨迹扩散层（最底层）
            if (widget.completed)
              AnimatedBuilder(
                animation: _splashController,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _splashScale.value,
                    child: Opacity(
                      opacity: _splashOpacity.value,
                      child: child,
                    ),
                  );
                },
                child: Container(
                  width: size,
                  height: size,
                  decoration: const BoxDecoration(
                    color: AppColors.accentComplete,
                    shape: BoxShape.circle,
                  ),
                ),
              ),

            // 复选框底（未完成时显示边框，完成时被印章覆盖）
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: widget.completed
                    ? AppColors.accentComplete
                    : AppColors.transparent,
                border: widget.completed
                    ? null
                    : Border.all(
                        color: AppColors.checkboxBorder,
                        width: 1.5,
                      ),
                borderRadius:
                    BorderRadius.circular(AppConstants.checkboxRadius),
              ),
            ),

            // 印章层（最顶层，动画期间及完成后显示）
            if (widget.completed)
              Positioned(
                left: -(AppConstants.checkboxSize + 6 - size) / 2,
                top: -(AppConstants.checkboxSize + 6 - size) / 2,
                child: AnimatedBuilder(
                  animation: _stampController,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(0, _translateYAnim.value),
                      child: Transform.rotate(
                        angle: _rotateAnim.value * 3.14159265 / 180,
                        child: Transform.scale(
                          scale: _scaleAnim.value,
                          child: Opacity(
                            opacity: _opacityAnim.value,
                            child: child,
                          ),
                        ),
                      ),
                    );
                  },
                  child: _buildStamp(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _handleTap() {
    if (!widget.completed) {
      HapticFeedback.mediumImpact();
    }
    widget.onTap();
  }

  /// 构建印章视觉
  Widget _buildStamp() {
    return Container(
      width: _stampSize,
      height: _stampSize,
      decoration: BoxDecoration(
        color: AppColors.accentComplete,
        borderRadius: BorderRadius.circular(5),
      ),
      alignment: Alignment.center,
      child: const Text(
        '完成',
        style: TextStyle(
          color: AppColors.white,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.3,
          height: 1.0,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
