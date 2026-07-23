import 'dart:convert';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/message_filter.dart';
import '../../core/utils/rate_limiter.dart';
import '../../data/database/database_helper.dart';
import '../../data/models/chat_message.dart';
import '../../data/services/ai_service.dart';
import '../../services/sync_service.dart';
import 'widgets/message_bubble.dart';
import 'widgets/plan_card.dart';
import 'widgets/typing_bubble.dart';
import 'widgets/chat_input_bar.dart';
import 'widgets/quick_choices.dart';

/// 计划页（Tab 2，开发文档第4.2节）
///
/// 通过与 DeepSeek AI 多轮对话，诊断学习状况并生成个性化学习计划。
/// 支持分级调整：
/// - 微调一下：保留诊断信息，只重新生成7天任务
/// - 换个思路：清空对话，重新开始完整AI诊断
class PlanPage extends StatefulWidget {
  /// 计划保存成功后的回调（跳转到学习页）
  final VoidCallback onPlanGenerated;

  const PlanPage({super.key, required this.onPlanGenerated});

  @override
  State<PlanPage> createState() => _PlanPageState();
}

/// 对话阶段，用于控制快捷选项的显示
enum _ChatPhase {
  normal,
  awaitingDeadline,
  awaitingDuration,
}

class _PlanPageState extends State<PlanPage> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<ChatMessage> _messages = [];
  int _nextId = 1;
  bool _isLoading = false;

  /// 已保存计划的消息 ID 集合
  final Set<int> _savedPlanIds = {};

  /// 正在微调中的计划卡片消息 ID 集合
  final Set<int> _adjustingPlanIds = {};

  /// 当前对话阶段（控制快捷选项的显示）
  _ChatPhase _phase = _ChatPhase.normal;

  /// 对话消息频率限制（防抖，3秒冷却）
  final RateLimiter _messageLimiter = RateLimiter(Duration(seconds: 3));

  /// 计划生成频率限制（60秒冷却，防止重置后立即重新生成）
  final RateLimiter _planGenerationLimiter = RateLimiter(Duration(seconds: 60));

  @override
  void initState() {
    super.initState();
    _loadChatHistory();
  }

  /// 从数据库加载聊天记录
  Future<void> _loadChatHistory() async {
    try {
      final rows = await DatabaseHelper.getAllChatHistory();
      if (rows.isEmpty) {
        // 无历史记录，添加欢迎消息
        _addWelcomeMessage();
        return;
      }
      setState(() {
        _messages.clear();
        for (final row in rows) {
          _messages.add(ChatMessage.fromDb(row));
        }
        _nextId = (_messages.last.id) + 1;
      });
      _scrollToBottom();
    } catch (e) {
      // 加载失败时添加欢迎消息
      _addWelcomeMessage();
    }
  }

  /// 添加欢迎消息
  void _addWelcomeMessage() {
    setState(() {
      _messages.add(ChatMessage(
        id: _nextId++,
        text: '你好！我是你的规划助手「知行计」。\n你想达成什么目标？',
        sender: MessageSender.ai,
      ));
    });
  }

  /// 保存消息到数据库
  Future<void> _saveMessage(ChatMessage msg) async {
    try {
      await DatabaseHelper.insertChatMessage(msg.toDb());
      SyncService.triggerAutoSync();
    } catch (_) {}
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// 构建发送给 API 的对话历史
  List<Map<String, String>> _buildHistory() {
    final history = <Map<String, String>>[];
    for (final msg in _messages) {
      if (msg.isPlanCard) continue;
      if (msg.isUser) {
        history.add({'role': 'user', 'content': msg.text});
      } else {
        final content = msg.rawResponse ?? msg.text;
        history.add({'role': 'assistant', 'content': content});
      }
    }
    return history;
  }

  /// 检测 AI 回复是否包含截止日期相关问题
  _ChatPhase _detectPhase(String response) {
    final lower = response.toLowerCase();
    if (lower.contains('截止日期') ||
        lower.contains('截止') ||
        lower.contains('考试') ||
        lower.contains('考证') ||
        lower.contains('面试') ||
        (lower.contains('硬性') && lower.contains('日期'))) {
      return _ChatPhase.awaitingDeadline;
    }
    return _ChatPhase.normal;
  }

  /// 处理用户发送消息
  Future<void> _handleSend() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _isLoading) return;

    final result = MessageFilter.check(text);
    if (!result.passed) {
      _showSnackBar(result.reason ?? '消息不合法');
      return;
    }

    if (!_messageLimiter.canRequest) {
      _showSnackBar('发送太快了，请等 ${_messageLimiter.remainingSeconds} 秒后再试');
      return;
    }
    _messageLimiter.record();

    _sendMessage(text);
  }

  /// 发送消息（文本或快捷选项）
  Future<void> _sendMessage(String text) async {
    if (text.isEmpty || _isLoading) return;

    if (!AIService.isConfigured) {
      _showSnackBar('请先在 app_constants.dart 中填写 DeepSeek API Key');
      return;
    }

    setState(() {
      _phase = _ChatPhase.normal;
      final userMsg = ChatMessage(
        id: _nextId++,
        text: text,
        sender: MessageSender.user,
      );
      _messages.add(userMsg);
      _isLoading = true;
    });
    _inputController.clear();
    _scrollToBottom();
    _saveMessage(_messages.last);

    // P0-4: 检测是否有活跃计划，有则走微调流程
    final activePlan = await _getActivePlanData();
    if (activePlan != null) {
      await _handleAdjustWithActivePlan(text, activePlan);
      return;
    }

    try {
      final history = _buildHistory();
      final aiResponse = await AIService.chat(history);
      _handleAIResponse(aiResponse);
    } catch (e) {
      setState(() {
        _isLoading = false;
        final errStr = e.toString();
        final friendlyMsg = errStr.contains('余额不足')
            ? 'AI 服务余额不足，请前往 DeepSeek 平台充值后重试。'
            : '抱歉，出了点问题：$e\n请检查网络连接和 API Key 后重试。';
        final errMsg = ChatMessage(
          id: _nextId++,
          text: friendlyMsg,
          sender: MessageSender.ai,
        );
        _messages.add(errMsg);
      });
      _saveMessage(_messages.last);
      _scrollToBottom();
    }
  }

  /// 从数据库获取活跃计划数据
  ///
  /// 返回包含 diagnosisJson 和 planJson 的 Map，无活跃计划时返回 null
  Future<Map<String, dynamic>?> _getActivePlanData() async {
    try {
      final plan = await DatabaseHelper.getPlan();
      if (plan == null) return null;

      final diagnosisStr = plan['diagnosis_json'] as String? ?? '';
      final tasksStr = plan['tasks_json'] as String? ?? '[]';
      if (diagnosisStr.isEmpty || tasksStr.isEmpty) return null;

      final diagnosis = jsonDecode(diagnosisStr) as Map<String, dynamic>;
      final tasks = jsonDecode(tasksStr) as List;
      final goal = plan['goal'] as String? ?? '';

      return {
        'diagnosis': diagnosis,
        'plan': {
          'goal': goal,
          'tasks': tasks,
        },
      };
    } catch (e) {
      return null;
    }
  }

  /// 使用活跃计划数据进行微调
  Future<void> _handleAdjustWithActivePlan(
    String userFeedback,
    Map<String, dynamic> planData,
  ) async {
    try {
      final diagnosisJson = planData['diagnosis'] as Map<String, dynamic>;
      final planJson = planData['plan'] as Map<String, dynamic>;

      final aiResponse = await AIService.adjustPlan(
        diagnosisJson: jsonEncode(diagnosisJson),
        currentPlanJson: jsonEncode(planJson),
        feedback: userFeedback,
      );

      // 解析 AI 回复
      final newJson = AIService.extractJson(aiResponse);
      if (newJson != null && newJson['plan'] != null) {
        // 微调成功，显示新的计划卡片
        final mergedPlan = newJson['plan'] as Map<String, dynamic>;
        final mergedResponse = jsonEncode({
          'diagnosis': diagnosisJson,
          'plan': mergedPlan,
        });
        final introText = AIService.extractIntroText(aiResponse);
        final combinedResponse = introText.isNotEmpty
            ? '$introText\n```json\n$mergedResponse\n```'
            : '```json\n$mergedResponse\n```';

        setState(() {
          _isLoading = false;
          if (introText.isNotEmpty) {
            _messages.add(ChatMessage(
              id: _nextId++,
              text: introText,
              sender: MessageSender.ai,
              rawResponse: combinedResponse,
            ));
          }
          _messages.add(ChatMessage(
            id: _nextId++,
            text: '',
            sender: MessageSender.ai,
            type: MessageType.planCard,
            rawResponse: combinedResponse,
          ));
        });
        _scrollToBottom();
      } else {
        // 解析失败，友好提示
        setState(() {
          _isLoading = false;
          _messages.add(ChatMessage(
            id: _nextId++,
            text: '我理解你想调整计划。不过刚才的回复格式出了点问题，'
                '你可以试试点击下方计划卡片的「微调」按钮，'
                '选择具体的调整方向（节奏太紧/太简单/加练习），我会更精准地帮你调整。',
            sender: MessageSender.ai,
          ));
        });
        _scrollToBottom();
      }
    } catch (e) {
      // 微调失败，友好提示不崩溃
      setState(() {
        _isLoading = false;
        _messages.add(ChatMessage(
          id: _nextId++,
          text: '抱歉，调整计划时出了点问题：$e\n'
              '你可以稍后重试，或点击计划卡片的「微调」按钮进行调整。',
          sender: MessageSender.ai,
        ));
      });
      _scrollToBottom();
    }
  }

  /// 处理 AI 回复
  void _handleAIResponse(String response) {
    final hasPlan = AIService.containsPlan(response);
    final newPhase = _detectPhase(response);

    if (hasPlan) {
      _planGenerationLimiter.record();
    }

    setState(() {
      _isLoading = false;

      if (hasPlan) {
        final introText = AIService.extractIntroText(response);

        if (introText.isNotEmpty) {
          final msg = ChatMessage(
            id: _nextId++,
            text: introText,
            sender: MessageSender.ai,
            rawResponse: response,
          );
          _messages.add(msg);
          _saveMessage(msg);
        }

        final cardMsg = ChatMessage(
          id: _nextId++,
          text: '',
          sender: MessageSender.ai,
          type: MessageType.planCard,
          rawResponse: response,
        );
        _messages.add(cardMsg);
        _saveMessage(cardMsg);
        _phase = _ChatPhase.normal;
      } else {
        final msg = ChatMessage(
          id: _nextId++,
          text: response,
          sender: MessageSender.ai,
          rawResponse: response,
        );
        _messages.add(msg);
        _saveMessage(msg);
        _phase = newPhase;
      }
    });

    _scrollToBottom();
  }

  // ============ 微调计划 ============

  /// 点击"微调一下"：弹出微调对话框
  Future<void> _handleAdjust(int planCardMsgId) async {
    final msgIndex = _messages.indexWhere((m) => m.id == planCardMsgId);
    if (msgIndex < 0) return;
    final rawResponse = _messages[msgIndex].rawResponse!;
    final json = AIService.extractJson(rawResponse);
    if (json == null) return;

    final feedback = await _showAdjustDialog();
    if (feedback == null || feedback.isEmpty) return;

    // 频率限制
    if (!_planGenerationLimiter.canRequest) {
      _showSnackBar(
        '刚生成过计划，请等 ${_planGenerationLimiter.remainingSeconds} 秒后再微调',
      );
      return;
    }

    setState(() => _adjustingPlanIds.add(planCardMsgId));

    try {
      final diagnosisJson = json['diagnosis'] as Map<String, dynamic>? ?? {};
      final planJson = json['plan'] as Map<String, dynamic>? ?? {};

      final aiResponse = await AIService.adjustPlan(
        diagnosisJson: jsonEncode(diagnosisJson),
        currentPlanJson: jsonEncode(planJson),
        feedback: feedback,
      );

      // 合并：保留原 diagnosis + 新 plan
      final newJson = AIService.extractJson(aiResponse);
      if (newJson != null && newJson['plan'] != null) {
        final mergedPlan = newJson['plan'] as Map<String, dynamic>;
        // 构造合并后的 rawResponse
        final mergedResponse = jsonEncode({
          'diagnosis': diagnosisJson,
          'plan': mergedPlan,
        });
        // 加上 AI 的引导文本
        final introText = AIService.extractIntroText(aiResponse);
        final combinedResponse = introText.isNotEmpty
            ? '$introText\n```json\n${jsonEncode({
                'diagnosis': diagnosisJson,
                'plan': mergedPlan,
              })}\n```'
            : '```json\n${jsonEncode({
                'diagnosis': diagnosisJson,
                'plan': mergedPlan,
              })}\n```';

        setState(() {
          // 替换计划卡片的 rawResponse
          _messages[msgIndex] = ChatMessage(
            id: _messages[msgIndex].id,
            text: '',
            sender: MessageSender.ai,
            type: MessageType.planCard,
            rawResponse: combinedResponse,
          );
          _adjustingPlanIds.remove(planCardMsgId);
        });
        _showSnackBar('计划已微调');
      } else {
        setState(() => _adjustingPlanIds.remove(planCardMsgId));
        _showSnackBar('微调失败，请重试');
      }
    } catch (e) {
      setState(() => _adjustingPlanIds.remove(planCardMsgId));
      _showSnackBar('微调失败：$e');
    }
  }

  /// 显示微调对话框，返回用户选择的反馈
  Future<String?> _showAdjustDialog() {
    final textController = TextEditingController();
    var selectedOption = '';

    return showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('微调计划'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '选择调整方向，AI 会保留你的诊断信息重新生成任务',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              // 快捷选项
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _adjustOptionPill('节奏太紧', selectedOption, (v) {
                    setDialogState(() {
                      selectedOption = v;
                      textController.clear();
                    });
                  }),
                  _adjustOptionPill('太简单', selectedOption, (v) {
                    setDialogState(() {
                      selectedOption = v;
                      textController.clear();
                    });
                  }),
                  _adjustOptionPill('加练习', selectedOption, (v) {
                    setDialogState(() {
                      selectedOption = v;
                      textController.clear();
                    });
                  }),
                ],
              ),
              const SizedBox(height: 12),
              // 手动输入
              TextField(
                controller: textController,
                decoration: const InputDecoration(
                  hintText: '或输入你的调整需求...',
                  hintStyle: TextStyle(fontSize: 13, color: AppColors.textTertiary),
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                maxLines: 2,
                onChanged: (text) {
                  setDialogState(() {
                    selectedOption = '';
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () {
                final text = textController.text.trim();
                if (text.isNotEmpty) {
                  Navigator.of(context).pop(text);
                } else if (selectedOption.isNotEmpty) {
                  Navigator.of(context).pop(selectedOption);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: AppColors.white,
              ),
              child: const Text('生成'),
            ),
          ],
        ),
      ),
    );
  }

  /// 微调选项胶囊
  Widget _adjustOptionPill(
    String label,
    String selected,
    ValueChanged<String> onTap,
  ) {
    final isSelected = selected == label;
    return GestureDetector(
      onTap: () => onTap(label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accent : AppColors.background,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: isSelected ? AppColors.white : AppColors.textSecondary,
            fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
          ),
        ),
      ),
    );
  }

  // ============ 截止日期 / 周期快捷选项 ============

  Future<void> _handleDeadlineChoice(String choice) async {
    if (choice == '有截止日期') {
      final selectedDate = await _pickDate();
      if (selectedDate != null) {
        final dateStr =
            '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}';
        await _sendMessage('我的截止日期是 $dateStr');
      }
    } else {
      setState(() {
        _phase = _ChatPhase.awaitingDuration;
        final msg = ChatMessage(
          id: _nextId++,
          text: '没有，长期学习',
          sender: MessageSender.user,
        );
        _messages.add(msg);
      });
      _saveMessage(_messages.last);
      _scrollToBottom();
    }
  }

  Future<void> _handleDurationChoice(String choice) async {
    await _sendMessage('我选择 $choice 的周期');
  }

  Future<DateTime?> _pickDate() async {
    final now = DateTime.now();
    return await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 7)),
      firstDate: now.add(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365)),
      helpText: '选择截止日期',
      cancelText: '取消',
      confirmText: '确定',
    );
  }

  // ============ 换个思路（原重置） ============

  /// 处理"换个思路"：清空对话和活跃计划，重新开始完整诊断
  Future<void> _handleRestart() async {
    if (!_planGenerationLimiter.canRequest) {
      _showSnackBar(
        '刚生成过计划，请等 ${_planGenerationLimiter.remainingSeconds} 秒后再重新开始',
      );
      return;
    }

    // 清空数据库聊天记录和活跃计划
    try {
      await DatabaseHelper.clearChatHistory();
      await DatabaseHelper.deletePlan();
    } catch (_) {}

    setState(() {
      _messages.clear();
      _savedPlanIds.clear();
      _adjustingPlanIds.clear();
      _phase = _ChatPhase.normal;
      _nextId = 1;
      _messages.add(ChatMessage(
        id: _nextId++,
        text: '你好！我是你的规划助手「知行计」。\n你想达成什么目标？',
        sender: MessageSender.ai,
      ));
      _isLoading = false;
    });
    _saveMessage(_messages.last);
    SyncService.triggerAutoSync();
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // 顶部标题 + 换个思路按钮
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('专属计划', style: AppTextStyles.greeting),
                  TextButton(
                    onPressed: _handleRestart,
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.refresh, size: 14, color: AppColors.accent),
                        SizedBox(width: 4),
                        Text(
                          '换个思路',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.accent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // 消息列表
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                itemCount: _messages.length +
                    (_isLoading ? 1 : 0) +
                    (_shouldShowQuickChoices() ? 1 : 0),
                itemBuilder: (context, index) {
                  if (_isLoading && index == _messages.length) {
                    return const Padding(
                      padding: EdgeInsets.only(bottom: 16),
                      child: TypingBubble(),
                    );
                  }

                  final quickChoiceIndex =
                      _messages.length + (_isLoading ? 1 : 0);
                  if (_shouldShowQuickChoices() &&
                      index == quickChoiceIndex) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _buildQuickChoices(),
                    );
                  }

                  final msg = _messages[index];
                  if (msg.isPlanCard) {
                    final isSaved = _savedPlanIds.contains(msg.id);
                    final isAdjusting = _adjustingPlanIds.contains(msg.id);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: PlanCard(
                        rawResponse: msg.rawResponse!,
                        isSaved: isSaved,
                        isAdjusting: isAdjusting,
                        onPlanSaved: () {
                          setState(() {
                            _savedPlanIds.add(msg.id);
                          });
                          widget.onPlanGenerated();
                        },
                        onAdjust: () => _handleAdjust(msg.id),
                      ),
                    );
                  }
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: MessageBubble(message: msg),
                  );
                },
              ),
            ),

            // 输入区
            ChatInputBar(
              controller: _inputController,
              onSend: _handleSend,
              isLoading: _isLoading,
            ),
          ],
        ),
      ),
    );
  }

  bool _shouldShowQuickChoices() {
    return !_isLoading &&
        (_phase == _ChatPhase.awaitingDeadline ||
            _phase == _ChatPhase.awaitingDuration);
  }

  Widget _buildQuickChoices() {
    if (_phase == _ChatPhase.awaitingDeadline) {
      return QuickChoices(
        mode: QuickChoiceMode.deadline,
        onSelect: _handleDeadlineChoice,
      );
    } else {
      return QuickChoices(
        mode: QuickChoiceMode.duration,
        onSelect: _handleDurationChoice,
      );
    }
  }
}
