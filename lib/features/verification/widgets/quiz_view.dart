import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

/// 答题验证视图
///
/// 接收 AI 生成的题目 JSON，显示选择题供用户作答。
class QuizView extends StatefulWidget {
  /// AI 生成的题目 JSON 字符串
  final String questionsJson;

  const QuizView({super.key, required this.questionsJson});

  @override
  State<QuizView> createState() => _QuizViewState();
}

class _QuizViewState extends State<QuizView> {
  List<Map<String, dynamic>> _questions = [];
  final List<int> _userAnswers = [];
  int _currentIndex = 0;
  bool _parseError = false;

  @override
  void initState() {
    super.initState();
    _parseQuestions();
  }

  void _parseQuestions() {
    try {
      // 提取 JSON 代码块
      var jsonStr = widget.questionsJson;
      final jsonMatch = RegExp(r'```json\s*([\s\S]*?)\s*```').firstMatch(jsonStr);
      if (jsonMatch != null) {
        jsonStr = jsonMatch.group(1)!;
      }
      final data = jsonDecode(jsonStr);
      final questions = data['questions'] as List;
      _questions = questions.map((q) => q as Map<String, dynamic>).toList();
      _userAnswers.clear();
      for (var i = 0; i < _questions.length; i++) {
        _userAnswers.add(-1);
      }
    } catch (e) {
      setState(() {
        _parseError = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_parseError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.textTertiary),
            const SizedBox(height: 12),
            const Text('题目解析失败', style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('返回'),
            ),
          ],
        ),
      );
    }

    if (_questions.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: AppColors.accent));
    }

    final question = _questions[_currentIndex];
    final options = question['options'] as List;
    final isLast = _currentIndex == _questions.length - 1;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 进度指示
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 16),
            child: Row(
              children: [
                Text(
                  '第 ${_currentIndex + 1} / ${_questions.length} 题',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          // 题目
          Text(
            question['question'] as String? ?? '',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          // 选项
          ...List.generate(options.length, (i) {
            final isSelected = _userAnswers[_currentIndex] == i;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _userAnswers[_currentIndex] = i;
                  });
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.bubbleUser : AppColors.card,
                    border: Border.all(
                      color: isSelected ? AppColors.accent : AppColors.borderCard,
                      width: isSelected ? 1.5 : 1,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? AppColors.accent : AppColors.borderCard,
                            width: 1.5,
                          ),
                          color: isSelected ? AppColors.accent : Colors.transparent,
                        ),
                        child: isSelected
                            ? const Icon(Icons.check, size: 14, color: Colors.white)
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          options[i] as String,
                          style: TextStyle(
                            fontSize: 14,
                            color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
          const Spacer(),
          // 导航按钮
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (_currentIndex > 0)
                TextButton(
                  onPressed: () {
                    setState(() => _currentIndex--);
                  },
                  child: const Text('上一题', style: TextStyle(color: AppColors.textSecondary)),
                )
              else
                const SizedBox(width: 80),
              ElevatedButton(
                onPressed: _userAnswers[_currentIndex] == -1
                    ? null
                    : () {
                        if (isLast) {
                          // 提交
                          Navigator.of(context).pop(_userAnswers);
                        } else {
                          setState(() => _currentIndex++);
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppColors.borderCard,
                ),
                child: Text(isLast ? '提交验证' : '下一题'),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
