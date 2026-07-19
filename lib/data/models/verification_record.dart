/// 验证记录模型
///
/// 对应数据库 verification_records 表，记录每次打卡验证的完整信息。
class VerificationRecord {
  final int? id;
  final int taskDay;
  final int planId;
  final String verificationType;
  final String? questionsJson;
  final String? userAnswer;
  final String? aiEvaluation;
  final bool passed;
  final String createdAt;

  const VerificationRecord({
    this.id,
    required this.taskDay,
    required this.planId,
    required this.verificationType,
    this.questionsJson,
    this.userAnswer,
    this.aiEvaluation,
    required this.passed,
    required this.createdAt,
  });

  factory VerificationRecord.fromMap(Map<String, dynamic> map) {
    return VerificationRecord(
      id: map['id'] as int?,
      taskDay: map['task_day'] as int,
      planId: map['plan_id'] as int,
      verificationType: map['verification_type'] as String,
      questionsJson: map['questions_json'] as String?,
      userAnswer: map['user_answer'] as String?,
      aiEvaluation: map['ai_evaluation'] as String?,
      passed: (map['passed'] as int) == 1,
      createdAt: map['created_at'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'task_day': taskDay,
      'plan_id': planId,
      'verification_type': verificationType,
      'questions_json': questionsJson,
      'user_answer': userAnswer,
      'ai_evaluation': aiEvaluation,
      'passed': passed ? 1 : 0,
      'created_at': createdAt,
    };
  }
}
