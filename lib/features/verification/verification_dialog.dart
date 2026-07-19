import 'dart:convert';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/task.dart';
import '../../data/models/verification_record.dart';
import '../../data/database/database_helper.dart';
import '../../data/services/ai_service.dart';
import 'widgets/quiz_view.dart';
import 'widgets/reflection_view.dart';
import 'widgets/verification_result_view.dart';

/// 验证页面状态
enum _VerificationPhase { loading, quiz, reflection, evaluating, result, error }

/// 打卡验证页面（全屏路由）
///
/// 根据 task.verificationType 决定验证方式：
/// - quiz: AI 生成题目 → 用户答题 → AI 评判
/// - reflection: 用户写反思 → AI 评判
/// - none: 不应进入此页面（调用方应直接打卡）
///
/// 注意：QuizView 和 ReflectionView 内部通过 Navigator.pop 返回结果，
/// 因此在 VerificationDialog 中使用 Navigator.push 包裹它们，
/// 通过 await 接收 pop 的返回值，避免直接嵌入 body 导致关闭整个页面。
class VerificationDialog extends StatefulWidget {
  final Task task;
  final int planId;

  const VerificationDialog({
    super.key,
    required this.task,
    required this.planId,
  });

  @override
  State<VerificationDialog> createState() => _VerificationDialogState();
}

class _VerificationDialogState extends State<VerificationDialog> {
  _VerificationPhase _phase = _VerificationPhase.loading;
  String _questionsJson = '';
  String _feedback = '';
  String _suggestion = '';
  bool _passed = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _startVerification();
  }

  Future<void> _startVerification() async {
    setState(() => _phase = _VerificationPhase.loading);
    try {
      if (widget.task.verificationType == 'quiz') {
        final result = await AIService.generateQuiz(widget.task);
        _questionsJson = result;
        // 不改变 _phase，直接 push QuizView 作为独立路由
        // QuizView 内部会通过 Navigator.pop 返回 List<int> 用户答案
        if (!mounted) return;
        final answers = await Navigator.of(context).push<List<int>>(
          MaterialPageRoute(
            builder: (context) => Scaffold(
              backgroundColor: AppColors.background,
              appBar: AppBar(
                backgroundColor: AppColors.background,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.close, color: AppColors.textSecondary),
                  onPressed: () => Navigator.of(context).pop<List<int>>([]),
                ),
                title: Text(
                  widget.task.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                centerTitle: true,
              ),
              body: QuizView(questionsJson: _questionsJson),
            ),
          ),
        );
        if (answers != null && answers.isNotEmpty) {
          _submitQuiz(answers);
        } else {
          // 用户关闭页面，不评判
          if (mounted) Navigator.of(context).pop(false);
        }
      } else if (widget.task.verificationType == 'reflection') {
        if (!mounted) return;
        // 直接 push ReflectionView 作为独立路由
        // ReflectionView 内部会通过 Navigator.pop 返回 String 反思文本
        final reflection = await Navigator.of(context).push<String>(
          MaterialPageRoute(
            builder: (context) => Scaffold(
              backgroundColor: AppColors.background,
              appBar: AppBar(
                backgroundColor: AppColors.background,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.close, color: AppColors.textSecondary),
                  onPressed: () => Navigator.of(context).pop<String>(''),
                ),
                title: Text(
                  widget.task.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                centerTitle: true,
              ),
              body: ReflectionView(
                taskTitle: widget.task.title,
                taskDescription: widget.task.description,
              ),
            ),
          ),
        );
        if (reflection != null && reflection.isNotEmpty) {
          _submitReflection(reflection);
        } else {
          if (mounted) Navigator.of(context).pop(false);
        }
      }
    } catch (e) {
      // 网络失败：允许跳过验证直接打卡
      setState(() {
        _errorMessage = e.toString();
        _phase = _VerificationPhase.error;
      });
    }
  }

  Future<void> _submitQuiz(List<int> answers) async {
    setState(() => _phase = _VerificationPhase.evaluating);
    try {
      final result = await AIService.evaluateQuiz(
        widget.task,
        _questionsJson,
        answers,
      );
      _parseEvaluationResult(result, answers.toString());
    } catch (e) {
      // 评判失败：默认通过
      _saveAndShowResult(
        passed: true,
        feedback: '网络问题无法评判，已默认通过',
        suggestion: null,
        userAnswer: answers.toString(),
      );
    }
  }

  Future<void> _submitReflection(String text) async {
    setState(() => _phase = _VerificationPhase.evaluating);
    try {
      final result = await AIService.evaluateReflection(widget.task, text);
      _parseEvaluationResult(result, text);
    } catch (e) {
      // 评判失败：默认通过
      _saveAndShowResult(
        passed: true,
        feedback: '网络问题无法评判，已默认通过',
        suggestion: null,
        userAnswer: text,
      );
    }
  }

  void _parseEvaluationResult(String resultJson, String userAnswer) {
    try {
      var jsonStr = resultJson;
      final jsonMatch = RegExp(r'```json\s*([\s\S]*?)\s*```').firstMatch(jsonStr);
      if (jsonMatch != null) {
        jsonStr = jsonMatch.group(1)!;
      }
      final data = jsonDecode(jsonStr);
      _saveAndShowResult(
        passed: data['passed'] as bool? ?? true,
        feedback: data['feedback'] as String? ?? '',
        suggestion: data['suggestion'] as String?,
        userAnswer: userAnswer,
      );
    } catch (_) {
      // 解析失败：默认通过
      _saveAndShowResult(
        passed: true,
        feedback: '验证完成',
        suggestion: null,
        userAnswer: userAnswer,
      );
    }
  }

  Future<void> _saveAndShowResult({
    required bool passed,
    required String feedback,
    required String? suggestion,
    required String userAnswer,
  }) async {
    // 保存验证记录
    final now = DateTime.now();
    final createdAt =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} '
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';

    final record = VerificationRecord(
      taskDay: widget.task.day,
      planId: widget.planId,
      verificationType: widget.task.verificationType,
      questionsJson: _questionsJson.isNotEmpty ? _questionsJson : null,
      userAnswer: userAnswer,
      aiEvaluation: feedback,
      passed: passed,
      createdAt: createdAt,
    );

    try {
      await DatabaseHelper.insertVerificationRecord(record.toMap());
    } catch (_) {
      // 保存失败不阻断流程
    }

    setState(() {
      _passed = passed;
      _feedback = feedback;
      _suggestion = suggestion ?? '';
      _phase = _VerificationPhase.result;
    });
  }

  void _retry() {
    _startVerification();
  }

  void _complete() {
    // 验证通过或用户选择继续学习，关闭页面
    // 返回 true 表示可以打卡，false 表示不打卡
    Navigator.of(context).pop(_passed);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _phase != _VerificationPhase.evaluating,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          elevation: 0,
          leading: _phase == _VerificationPhase.evaluating
              ? const SizedBox.shrink()
              : IconButton(
                  icon: const Icon(Icons.close, color: AppColors.textSecondary),
                  onPressed: () => Navigator.of(context).pop(false),
                ),
          title: Text(
            widget.task.title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          centerTitle: true,
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    switch (_phase) {
      case _VerificationPhase.loading:
        return _buildLoading('正在准备验证内容...');
      case _VerificationPhase.quiz:
        // 不会走到这里，quiz 通过 Navigator.push 处理
        return const SizedBox.shrink();
      case _VerificationPhase.reflection:
        // 不会走到这里，reflection 通过 Navigator.push 处理
        return const SizedBox.shrink();
      case _VerificationPhase.evaluating:
        return _buildLoading('正在评判你的回答...');
      case _VerificationPhase.result:
        return VerificationResultView(
          passed: _passed,
          feedback: _feedback,
          suggestion: _suggestion.isNotEmpty ? _suggestion : null,
          onRetry: _retry,
          onComplete: _complete,
        );
      case _VerificationPhase.error:
        return _buildError();
    }
  }

  Widget _buildLoading(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: AppColors.accent),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.wifi_off, size: 48, color: AppColors.textTertiary),
            const SizedBox(height: 16),
            const Text(
              '网络连接失败',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              '无法连接到 AI 验证服务\n$_errorMessage',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.5),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: _retry,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('重试'),
                ),
                const SizedBox(width: 12),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text(
                    '跳过验证直接打卡',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
