/// 学习诊断档案模型（AI 生成的诊断 JSON 的一部分）
class Diagnosis {
  final String currentLevel;
  final String learningStyle;
  final String weakAreas;
  final String recommendedApproach;

  /// 截止日期（格式 YYYY-MM-DD，空字符串表示无截止日期）
  final String deadline;

  /// 计划总天数
  final int totalDays;

  const Diagnosis({
    required this.currentLevel,
    required this.learningStyle,
    this.weakAreas = '',
    this.recommendedApproach = '',
    this.deadline = '',
    this.totalDays = 0,
  });

  /// 是否有截止日期
  bool get hasDeadline => deadline.isNotEmpty;

  factory Diagnosis.fromJson(Map<String, dynamic> json) {
    return Diagnosis(
      currentLevel: json['current_level'] as String? ?? '',
      learningStyle: json['learning_style'] as String? ?? '',
      weakAreas: json['weak_areas'] as String? ?? '',
      recommendedApproach: json['recommended_approach'] as String? ?? '',
      deadline: json['deadline'] as String? ?? '',
      totalDays: json['total_days'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'current_level': currentLevel,
      'learning_style': learningStyle,
      'weak_areas': weakAreas,
      'recommended_approach': recommendedApproach,
      'deadline': deadline,
      'total_days': totalDays,
    };
  }
}
