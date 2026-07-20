/// 聊天消息模型（开发文档第4.2节 计划页对话）
class ChatMessage {
  final int id;
  final String text;
  final MessageSender sender;
  final MessageType type;

  /// AI 计划卡片消息专有：存储 AI 的完整原始回复（含 JSON）
  /// 用于点击"开始学习"时解析并保存到 SQLite。
  final String? rawResponse;

  const ChatMessage({
    required this.id,
    required this.text,
    required this.sender,
    this.type = MessageType.text,
    this.rawResponse,
  });

  bool get isAI => sender == MessageSender.ai;
  bool get isUser => sender == MessageSender.user;
  bool get isPlanCard => type == MessageType.planCard;
}

enum MessageSender { ai, user }

enum MessageType {
  /// 普通文本消息
  text,

  /// 计划卡片（特殊AI消息，开发文档第4.2节）
  planCard,
}
