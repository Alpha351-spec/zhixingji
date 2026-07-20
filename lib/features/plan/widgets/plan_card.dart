import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/models/task.dart';
import '../../../data/services/ai_service.dart';
import '../../../data/services/plan_repository.dart';

/// 计划卡片（开发文档第4.2节 特殊AI消息）
///
/// 白底+1px #E0E0E0边框，圆角18px
/// 展示计划概要（学习目标、任务数、天数）+ "开始学习"按钮
///
/// 点击"开始学习"后，从 [rawResponse] 中解析计划并保存到 SQLite，
/// 然后回调 [onPlanSaved] 跳转到学习页。
class PlanCard extends StatefulWidget {
  /// AI 的完整原始回复（含 JSON 计划）
  final String rawResponse;

  /// 计划保存成功后的回调
  final VoidCallback onPlanSaved;

  /// 是否已保存（true 时按钮显示"已开始学习"并禁用）
  final bool isSaved;

  /// 是否正在微调中
  final bool isAdjusting;

  /// 点击"微调一下"的回调
  final VoidCallback? onAdjust;

  const PlanCard({
    super.key,
    required this.rawResponse,
    required this.onPlanSaved,
    this.isSaved = false,
    this.isAdjusting = false,
    this.onAdjust,
  });

  @override
  State<PlanCard> createState() => _PlanCardState();
}

class _PlanCardState extends State<PlanCard> {
  bool _isSaving = false;

  /// 从 rawResponse 中解析出计划概要信息
  Map<String, dynamic>? _planSummary;

  @override
  void initState() {
    super.initState();
    _parsePlanSummary();
  }

  void _parsePlanSummary() {
    final json = AIService.extractJson(widget.rawResponse);
    if (json != null && json['plan'] != null) {
      _planSummary = json['plan'] as Map<String, dynamic>;
    }
  }

  /// 清理 Markdown 标记（简单处理 ** 加粗和 * 斜体）
  String _cleanMarkdown(String text) {
    return text
        .replaceAll('**', '')
        .replaceAll('*', '')
        .replaceAll('##', '')
        .replaceAll('#', '');
  }

  Future<void> _handleStartLearning() async {
    if (_isSaving || widget.isSaved) return;

    setState(() => _isSaving = true);

    // 解析并保存计划到 SQLite
    final plan = await PlanRepository.savePlanFromAI(widget.rawResponse);

    if (!mounted) return;

    if (plan != null) {
      // 保存成功，触发回调（PlanPage 会标记 isSaved 并跳转）
      widget.onPlanSaved();
      // 重置加载状态，后续 isSaved=true 会接管按钮禁用
      setState(() => _isSaving = false);
    } else {
      // 保存失败，恢复按钮状态并提示错误
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('计划保存失败，请重试'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final goal = _cleanMarkdown(
        _planSummary?['goal'] as String? ?? '');
    final tasksJson = _planSummary?['tasks'] as List? ?? [];
    final taskCount = tasksJson.length;

    // 解析任务列表用于展示概要
    final tasks = tasksJson
        .map((e) => Task.fromJson(e as Map<String, dynamic>))
        .toList();
    final totalDays = tasks.isNotEmpty
        ? tasks.map((t) => t.day).reduce((a, b) => a > b ? a : b)
        : 0;

    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.85,
        ),
        child: IntrinsicWidth(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.white,
              border: Border.all(color: AppColors.borderPlanCard, width: 1),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // 标题
                const Center(
                  child: Text(
                    '你的专属计划已生成',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 16),

                // 目标
                if (goal.isNotEmpty) ...[
                  _infoRow(Icons.flag_outlined, '目标', goal),
                  const SizedBox(height: 12),
                ],

                // 计划概要：任务数 + 天数
                if (taskCount > 0) ...[
                  _infoRow(
                    Icons.calendar_today_outlined,
                    '计划周期',
                    '$totalDays 天 · 共 $taskCount 个任务',
                  ),
                  const SizedBox(height: 16),
                ],

                // 任务预览列表（最多显示前3个）
                if (tasks.isNotEmpty) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          '任务预览',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...tasks.take(3).map((t) => Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    margin: const EdgeInsets.only(top: 6),
                                    width: 4,
                                    height: 4,
                                    decoration: const BoxDecoration(
                                      color: AppColors.accent,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // 用 Expanded 包裹，防止文本撑破 Row
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Day ${t.day} · ${_cleanMarkdown(t.title)}',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                        if (t.description.isNotEmpty)
                                          Text(
                                            _cleanMarkdown(t.description),
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: AppColors.textTertiary,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            )),
                        if (tasks.length > 3)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              '还有 ${tasks.length - 3} 个任务...',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textTertiary,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // 开始学习按钮
                Center(
                  child: SizedBox(
                    height: 40,
                    child: ElevatedButton(
                      onPressed: (_isSaving || widget.isSaved)
                          ? null
                          : _handleStartLearning,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: widget.isSaved
                            ? AppColors.accentLight
                            : AppColors.accent,
                        foregroundColor: AppColors.white,
                        disabledBackgroundColor: AppColors.accentLight,
                        disabledForegroundColor: AppColors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppConstants.buttonRadius),
                        ),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.white,
                              ),
                            )
                          : widget.isSaved
                              ? const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.check, size: 16),
                                    SizedBox(width: 4),
                                    Text('已开始执行',
                                        style: AppTextStyles.pillButton),
                                  ],
                                )
                              : const Text('开始执行',
                                  style: AppTextStyles.pillButton),
                    ),
                  ),
                ),

                // 微调一下按钮（弱化样式）
                if (widget.onAdjust != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: TextButton(
                      onPressed: (widget.isSaved || widget.isAdjusting)
                          ? null
                          : widget.onAdjust,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.accent,
                      ),
                      child: widget.isAdjusting
                          ? const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.accent,
                                  ),
                                ),
                                SizedBox(width: 6),
                                Text(
                                  '微调中...',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ],
                            )
                          : const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.tune, size: 14),
                                SizedBox(width: 4),
                                Text(
                                  '微调一下',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 信息行：图标 + 标签 + 值
  ///
  /// 使用 Expanded 包裹文本，防止长文本撑破 Row
  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.accent),
        const SizedBox(width: 8),
        // 用 Expanded 包裹，限制文本宽度不超出容器
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textTertiary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
