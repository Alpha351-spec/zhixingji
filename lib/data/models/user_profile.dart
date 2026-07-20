/// 用户个人信息模型
///
/// 基础身份信息：用户码、昵称、手机号、邮箱
///
/// 注意：用户码由 [UserService] 统一生成管理，
/// 本模型只负责存储和展示，不自行生成。
class UserProfile {
  /// 用户码（系统自动生成，只读，格式如 ZXX#12345678）
  ///
  /// 由 UserService 统一生成，本字段仅用于持久化展示。
  final String userId;

  /// 昵称（必填）
  final String nickname;

  /// 头像路径（本地文件路径，空表示用默认图标）
  final String avatarPath;

  /// 手机号（选填）
  final String phone;

  /// 邮箱（选填）
  final String email;

  const UserProfile({
    this.userId = '',
    this.nickname = '',
    this.avatarPath = '',
    this.phone = '',
    this.email = '',
  });

  bool get isEmpty => nickname.isEmpty && userId.isEmpty;

  UserProfile copyWith({
    String? userId,
    String? nickname,
    String? avatarPath,
    String? phone,
    String? email,
  }) {
    return UserProfile(
      userId: userId ?? this.userId,
      nickname: nickname ?? this.nickname,
      avatarPath: avatarPath ?? this.avatarPath,
      phone: phone ?? this.phone,
      email: email ?? this.email,
    );
  }

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'nickname': nickname,
        'avatarPath': avatarPath,
        'phone': phone,
        'email': email,
      };

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      userId: json['userId'] as String? ?? '',
      nickname: json['nickname'] as String? ?? '',
      avatarPath: json['avatarPath'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      email: json['email'] as String? ?? '',
    );
  }
}
