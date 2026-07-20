import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/navigation/main_scaffold.dart';

/// 启动页
///
/// 参考 minimalist splash 布局：
/// - 上 1/3：Slogan「以知为引 以行作沙」
/// - 下 1/4：App 图标 + 品牌名「知行计」
/// - 背景：宣纸底色 + 半透明墨绿装饰图形
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeIn;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fadeIn = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );
    _controller.forward();

    // 2 秒后跳转主页
    Future.delayed(const Duration(milliseconds: 2000), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => const MainScaffold(),
            transitionsBuilder: (_, anim, __, child) {
              return FadeTransition(opacity: anim, child: child);
            },
            transitionDuration: const Duration(milliseconds: 400),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // 装饰图形层
          const _DecorativeShapes(),

          // 内容层
          FadeTransition(
            opacity: _fadeIn,
            child: SafeArea(
              child: Column(
                children: [
                  // Slogan 区域（上 1/3 处）
                  Expanded(
                    flex: 3,
                    child: Container(
                      alignment: Alignment.bottomCenter,
                      padding: EdgeInsets.only(bottom: screenHeight * 0.04),
                      child: const _Slogan(),
                    ),
                  ),
                  // 中间留白
                  Expanded(
                    flex: 2,
                    child: Container(),
                  ),
                  // Logo + 品牌名（下 1/4 处）
                  Expanded(
                    flex: 1,
                    child: Container(
                      alignment: Alignment.topCenter,
                      child: const _BrandLogo(),
                    ),
                  ),
                  SizedBox(height: screenHeight * 0.06),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Slogan 文字
///
/// 使用思源宋体 Medium，字间距宽松，墨色
class _Slogan extends StatelessWidget {
  const _Slogan();

  @override
  Widget build(BuildContext context) {
    return const Text(
      '以知为引 以行作沙',
      style: TextStyle(
        fontFamily: 'NotoSerifSC',
        fontWeight: FontWeight.w500,
        fontSize: 22,
        height: 1.6,
        letterSpacing: 6,
        color: AppColors.textPrimary,
      ),
    );
  }
}

/// 品牌 Logo + 名称
class _BrandLogo extends StatelessWidget {
  const _BrandLogo();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        // App 图标
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.asset(
            'assets/images/app_icon.png',
            width: 36,
            height: 36,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(width: 10),
        // 品牌名
        const Text(
          '知行计',
          style: TextStyle(
            fontFamily: 'NotoSansSC',
            fontWeight: FontWeight.w600,
            fontSize: 18,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

/// 装饰图形
///
/// 两个半透明的松烟墨绿色不规则形状，
/// 营造东方禅意的层次感
class _DecorativeShapes extends StatelessWidget {
  const _DecorativeShapes();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.infinite,
      painter: _DecorativePainter(),
    );
  }
}

class _DecorativePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // 右上方装饰叶片
    final paint1 = Paint()
      ..color = const Color(0xFF5B7B6A).withValues(alpha: 0.06)
      ..style = PaintingStyle.fill;

    final path1 = Path();
    final w = size.width;
    final h = size.height;
    path1.moveTo(w * 0.65, h * 0.08);
    path1.quadraticBezierTo(w * 1.05, h * 0.12, w * 0.95, h * 0.35);
    path1.quadraticBezierTo(w * 0.75, h * 0.30, w * 0.65, h * 0.08);
    canvas.drawPath(path1, paint1);

    // 左下方装饰叶片
    final paint2 = Paint()
      ..color = const Color(0xFF5B7B6A).withValues(alpha: 0.05)
      ..style = PaintingStyle.fill;

    final path2 = Path();
    path2.moveTo(w * 0.05, h * 0.72);
    path2.quadraticBezierTo(w * -0.05, h * 0.92, w * 0.30, h * 0.88);
    path2.quadraticBezierTo(w * 0.25, h * 0.68, w * 0.05, h * 0.72);
    canvas.drawPath(path2, paint2);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
