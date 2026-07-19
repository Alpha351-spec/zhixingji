import 'package:flutter/material.dart';

import '../../core/services/white_noise_generator.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

/// 白噪音生成器测试页
///
/// 用于单独测试 [WhiteNoiseGenerator] 的五种声音效果。
/// 点击对应卡片即开始播放，再次点击或点击其他卡片切换。
class NoiseTestPage extends StatefulWidget {
  const NoiseTestPage({super.key});

  @override
  State<NoiseTestPage> createState() => _NoiseTestPageState();
}

class _NoiseTestPageState extends State<NoiseTestPage> {
  final WhiteNoiseGenerator _gen = WhiteNoiseGenerator();
  String? _playingType; // 当前播放的类型 key

  // 五种声音配置
  static const List<({String key, String cn, String desc, IconData icon})>
      _noises = [
    (key: 'white', cn: '纯白噪音', desc: '均匀随机，专注屏蔽', icon: Icons.blur_on),
    (key: 'rain', cn: '雨声', desc: '低通滤波，沉稳雨幕', icon: Icons.water_drop_outlined),
    (key: 'forest', cn: '森林', desc: '虫鸣鸟啼，自然氛围', icon: Icons.park_outlined),
    (key: 'cafe', cn: '咖啡馆', desc: '低频嘈杂，人声嗡嗡', icon: Icons.coffee_outlined),
    (key: 'campfire', cn: '篝火', desc: '低频燃烧，噼啪作响', icon: Icons.local_fire_department_outlined),
  ];

  Future<void> _toggle(String type) async {
    if (_playingType == type) {
      await _gen.stop();
      setState(() => _playingType = null);
    } else {
      await _gen.start(type);
      setState(() => _playingType = type);
    }
  }

  @override
  void dispose() {
    _gen.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text('白噪音测试', style: AppTextStyles.heading),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20, color: AppColors.textSecondary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 20),
            child: Text(
              '点击卡片开始播放，再次点击停止',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textTertiary,
                fontFamily: AppTextStyles.fontFamily,
              ),
            ),
          ),
          ..._noises.map((n) => _noiseCard(n)),
          const SizedBox(height: 24),
          if (_playingType != null)
            Center(
              child: TextButton(
                onPressed: () => _toggle(_playingType!),
                child: const Text('停止播放', style: TextStyle(color: AppColors.accentComplete)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _noiseCard(({String key, String cn, String desc, IconData icon}) n) {
    final isPlaying = _playingType == n.key;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: () => _toggle(n.key),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isPlaying ? AppColors.accent : AppColors.borderCard,
              width: isPlaying ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                n.icon,
                size: 28,
                color: isPlaying ? AppColors.accent : AppColors.textTertiary,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      n.cn,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                        fontFamily: AppTextStyles.fontFamily,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      n.desc,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textTertiary,
                        fontFamily: AppTextStyles.fontFamily,
                      ),
                    ),
                  ],
                ),
              ),
              // 播放状态指示
              if (isPlaying)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.accent,
                  ),
                )
              else
                const Icon(Icons.play_arrow, size: 20, color: AppColors.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}
