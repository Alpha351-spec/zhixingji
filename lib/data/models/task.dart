/// 任务模型（开发文档第5节 tasks_json 结构）
///
/// ```json
/// {
///   "day": 1,
///   "title": "理解变量与数据类型",
///   "description": "学习Python中的数字、字符串...",
///   "resource_keywords": "Python 变量 教程",
///   "encouragement": "迈出第一步！",
///   "completed": 0,
///   "focus_minutes": 0
/// }
/// ```
class Task {
  final int day;
  final String title;
  final String description;
  final String resourceKeywords;
  final String encouragement;
  final bool completed;
  final int focusMinutes;
  final String verificationType;

  const Task({
    required this.day,
    required this.title,
    required this.description,
    this.resourceKeywords = '',
    this.encouragement = '',
    this.completed = false,
    this.focusMinutes = 0,
    this.verificationType = 'none',
  });

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      day: json['day'] as int? ?? 1,
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      resourceKeywords: json['resource_keywords'] as String? ?? '',
      encouragement: json['encouragement'] as String? ?? '',
      completed: (json['completed'] as int?) == 1,
      focusMinutes: json['focus_minutes'] as int? ?? 0,
      verificationType: json['verification_type'] as String? ?? 'none',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'day': day,
      'title': title,
      'description': description,
      'resource_keywords': resourceKeywords,
      'encouragement': encouragement,
      'completed': completed ? 1 : 0,
      'focus_minutes': focusMinutes,
      'verification_type': verificationType,
    };
  }

  Task copyWith({
    int? day,
    String? title,
    String? description,
    String? resourceKeywords,
    String? encouragement,
    bool? completed,
    int? focusMinutes,
    String? verificationType,
  }) {
    return Task(
      day: day ?? this.day,
      title: title ?? this.title,
      description: description ?? this.description,
      resourceKeywords: resourceKeywords ?? this.resourceKeywords,
      encouragement: encouragement ?? this.encouragement,
      completed: completed ?? this.completed,
      focusMinutes: focusMinutes ?? this.focusMinutes,
      verificationType: verificationType ?? this.verificationType,
    );
  }
}
