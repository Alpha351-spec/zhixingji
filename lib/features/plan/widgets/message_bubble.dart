import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../data/models/chat_message.dart';
import '../../../data/services/ai_service.dart';

/// 消息气泡（开发文档第4.2节）
///
/// AI消息：左对齐，无头像，气泡背景#F7F9FC，圆角18px(左上角4px)，最大宽度80%
/// 用户消息：右对齐，气泡背景#E8F8F5，圆角18px(右上角4px)
class MessageBubble extends StatelessWidget {
  final ChatMessage message;

  const MessageBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    String displayText = message.text;

    // AI 消息：清理 Markdown 标记和 JSON 数据
    if (message.isAI) {
      // 如果包含 JSON 计划，只显示引导文本部分
      if (AIService.containsPlan(message.text) ||
          AIService.extractJson(message.text) != null) {
        displayText = AIService.extractIntroText(message.text);
      }
      // 清理 Markdown 标记
      displayText = _cleanMarkdown(displayText);
    }

    // 如果清理后为空，不显示气泡
    if (displayText.isEmpty) return const SizedBox.shrink();

    return Align(
      alignment: message.isAI ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: message.isAI ? AppColors.bubbleAI : AppColors.bubbleUser,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(message.isAI ? 4 : 18),
            topRight: Radius.circular(message.isAI ? 18 : 4),
            bottomLeft: const Radius.circular(18),
            bottomRight: const Radius.circular(18),
          ),
        ),
        child: Text(
          displayText,
          style: AppTextStyles.body,
        ),
      ),
    );
  }

  /// 清理 Markdown 标记
  String _cleanMarkdown(String text) {
    return text
        .replaceAll('**', '')
        .replaceAll('*', '')
        .replaceAll('##', '')
        .replaceAll('#', '')
        .replaceAll('`', '');
  }
}
