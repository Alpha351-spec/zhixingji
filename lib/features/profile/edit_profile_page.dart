import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_colors.dart';
import '../../core/services/user_profile_service.dart';
import '../../data/models/user_profile.dart';
import '../../services/user_service.dart';

/// 个人信息编辑页
///
/// 极简风格，参考微信个人资料编辑页布局：
/// - 顶部头像区（居中，可点击替换）
/// - 基础身份组：用户码（只读）、昵称（必填）、手机号（选填）、邮箱（选填）
/// - 底部保存按钮
class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  late TextEditingController _nicknameController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;

  @override
  void initState() {
    super.initState();
    final p = UserProfileService.current;
    _nicknameController = TextEditingController(text: p.nickname);
    _phoneController = TextEditingController(text: p.phone);
    _emailController = TextEditingController(text: p.email);
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    final nickname = _nicknameController.text.trim();
    if (nickname.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请填写昵称')),
      );
      return;
    }

    // 邮箱格式校验（若填写了）
    final email = _emailController.text.trim();
    if (email.isNotEmpty) {
      final emailRegex = RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$');
      if (!emailRegex.hasMatch(email)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('邮箱格式不正确')),
        );
        return;
      }
    }

    // 手机号格式校验（若填写了）
    final phone = _phoneController.text.trim();
    if (phone.isNotEmpty) {
      final phoneRegex = RegExp(r'^1[3-9]\d{9}$');
      if (!phoneRegex.hasMatch(phone)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('手机号格式不正确')),
        );
        return;
      }
    }

    final profile = UserProfile(
      userId: UserService.userId,
      nickname: nickname,
      avatarPath: UserProfileService.current.avatarPath,
      phone: phone,
      email: email,
    );

    final ok = await UserProfileService.save(profile);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ok ? '已保存' : '保存失败')),
      );
      if (ok) {
        Navigator.of(context).pop(true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios,
            size: 20,
            color: AppColors.textPrimary,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          '编辑资料',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // ========== 头像区 ==========
                  GestureDetector(
                    onTap: () => _showAvatarHint(),
                    child: Container(
                      width: double.infinity,
                      color: AppColors.white,
                      padding: const EdgeInsets.symmetric(vertical: 28),
                      child: Center(
                        child: Stack(
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.borderCard,
                                  width: 0.5,
                                ),
                              ),
                              child: ClipOval(
                                child: Image.asset(
                                  'assets/images/app_icon.png',
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                width: 26,
                                height: 26,
                                decoration: BoxDecoration(
                                  color: AppColors.accent,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: AppColors.white,
                                    width: 2,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.camera_alt,
                                  size: 13,
                                  color: AppColors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // 隐私提示已移除（资料支持云端同步）

                  const SizedBox(height: 8),

                  // ========== 基础身份组 ==========
                  Container(
                    color: AppColors.white,
                    child: Column(
                      children: [
                        // 用户码（只读，由 UserService 统一管理）
                        _readOnlyRow(
                          label: '用户码',
                          value: UserService.userId,
                          hint: '用于云端同步和身份识别',
                        ),
                        _divider(),

                        // 昵称（必填）
                        _inputRow(
                          label: '昵称',
                          required: true,
                          child: TextField(
                            controller: _nicknameController,
                            decoration: const InputDecoration(
                              hintText: '请输入昵称',
                              hintStyle:
                                  TextStyle(color: AppColors.textTertiary),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                              counterText: '',
                              filled: false,
                            ),
                            style: const TextStyle(
                              fontSize: 15,
                              color: AppColors.textPrimary,
                            ),
                            textAlign: TextAlign.right,
                            maxLength: 12,
                          ),
                        ),
                        _divider(),

                        // 手机号（选填）
                        _inputRow(
                          label: '手机号',
                          child: TextField(
                            controller: _phoneController,
                            decoration: const InputDecoration(
                              hintText: '选填',
                              hintStyle:
                                  TextStyle(color: AppColors.textTertiary),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                              counterText: '',
                              filled: false,
                            ),
                            style: const TextStyle(
                              fontSize: 15,
                              color: AppColors.textPrimary,
                            ),
                            textAlign: TextAlign.right,
                            keyboardType: TextInputType.phone,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(11),
                            ],
                          ),
                        ),
                        _divider(),

                        // 邮箱（选填）
                        _inputRow(
                          label: '邮箱',
                          child: TextField(
                            controller: _emailController,
                            decoration: const InputDecoration(
                              hintText: '选填',
                              hintStyle:
                                  TextStyle(color: AppColors.textTertiary),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                              counterText: '',
                              filled: false,
                            ),
                            style: const TextStyle(
                              fontSize: 15,
                              color: AppColors.textPrimary,
                            ),
                            textAlign: TextAlign.right,
                            keyboardType: TextInputType.emailAddress,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),

          // ========== 底部保存按钮 ==========
          Container(
            color: AppColors.white,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: SafeArea(
              top: false,
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton(
                      onPressed: _handleSave,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: AppColors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        '保存',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 只读行（如用户ID）
  Widget _readOnlyRow({
    required String label,
    required String value,
    String? hint,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 15,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(width: 12),
          if (hint != null)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(
                hint,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textTertiary,
                ),
              ),
            ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  /// 文本输入行
  Widget _inputRow({
    required String label,
    bool required = false,
    required Widget child,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: label,
                  style: const TextStyle(
                    fontSize: 15,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (required)
                  const TextSpan(
                    text: ' *',
                    style: TextStyle(
                      fontSize: 15,
                      color: AppColors.accentComplete,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: child),
        ],
      ),
    );
  }

  /// 分隔线
  Widget _divider() {
    return const Padding(
      padding: EdgeInsets.only(left: 20),
      child: Divider(height: 1, thickness: 0.5, color: AppColors.borderCard),
    );
  }

  void _showAvatarHint() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('头像自定义功能开发中，当前使用默认图标'),
        duration: Duration(seconds: 2),
      ),
    );
  }
}
