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

  /// 序列化为数据库行
  Map<String, dynamic> toDb() {
    return {
      'sender': sender == MessageSender.ai ? 'ai' : 'user',
      'message_type': type == MessageType.planCard ? 'planCard' : 'text',
      'text': text,
      'raw_response': rawResponse,
      'created_at': DateTime.now().toIso8601String(),
    };
  }

  /// 从数据库行反序列化
  factory ChatMessage.fromDb(Map<String, dynamic> row) {
    return ChatMessage(
      id: row['id'] as int,
      text: row['text'] as String? ?? '',
      sender: row['sender'] == 'ai' ? MessageSender.ai : MessageSender.user,
      type: row['message_type'] == 'planCard'
          ? MessageType.planCard
          : MessageType.text,
      rawResponse: row['raw_response'] as String?,
    );
  }
}

enum MessageSender { ai, user }

enum MessageType {
  /// 普通文本消息
  text,

  /// 计划卡片（特殊AI消息，开发文档第4.2节）
  planCard,
}
