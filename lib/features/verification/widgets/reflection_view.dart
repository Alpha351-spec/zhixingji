import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

/// 反思验证视图
///
/// 显示反思引导提示，用户输入文字反思，提交后由 AI 评判。
class ReflectionView extends StatefulWidget {
  final String taskTitle;
  final String taskDescription;

  const ReflectionView({
    super.key,
    required this.taskTitle,
    required this.taskDescription,
  });

  @override
  State<ReflectionView> createState() => _ReflectionViewState();
}

class _ReflectionViewState extends State<ReflectionView> {
  final TextEditingController _controller = TextEditingController();
  final int _minChars = 30;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          // 反思引导
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.bubbleAI,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '反思引导',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '请回顾「${widget.taskTitle}」的学习过程，写下你的反思：\n'
                  '- 学到了什么核心概念？\n'
                  '- 遇到了什么困难？\n'
                  '- 有什么新的疑问？',
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textPrimary,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // 文本输入
          Expanded(
            child: TextField(
              controller: _controller,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              decoration: InputDecoration(
                hintText: '在此写下你的反思（至少 $_minChars 字）...',
                hintStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 14),
                filled: true,
                fillColor: AppColors.card,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.borderCard),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.borderCard),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // 字数统计 + 提交按钮
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _controller,
            builder: (context, value, _) {
              final count = value.text.trim().length;
              final canSubmit = count >= _minChars;
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$count / $_minChars 字',
                    style: TextStyle(
                      fontSize: 12,
                      color: canSubmit ? AppColors.accent : AppColors.textTertiary,
                    ),
                  ),
                  ElevatedButton(
                    onPressed: canSubmit
                        ? () => Navigator.of(context).pop(_controller.text.trim())
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: AppColors.borderCard,
                    ),
                    child: const Text('提交反思'),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
