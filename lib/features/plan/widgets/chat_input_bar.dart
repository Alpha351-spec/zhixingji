import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

/// 底部输入区（开发文档第4.2节）
///
/// 底部固定，白底+0.5px上边框
/// 输入框圆角20px，高40px，背景#F7F9FC
/// 发送按钮40x40圆形，背景#5C8D89
class ChatInputBar extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final bool isLoading;

  const ChatInputBar({
    super.key,
    required this.controller,
    required this.onSend,
    this.isLoading = false,
  });

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  bool _canSend = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
    _onTextChanged();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    final newCanSend =
        widget.controller.text.trim().isNotEmpty && !widget.isLoading;
    if (newCanSend != _canSend) {
      setState(() => _canSend = newCanSend);
    }
  }

  void _handleSend() {
    if (_canSend) {
      widget.onSend();
    }
  }

  @override
  Widget build(BuildContext context) {
    // isLoading 变化时也要更新
    final canSend = widget.controller.text.trim().isNotEmpty &&
        !widget.isLoading;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(
          top: BorderSide(color: AppColors.borderCard, width: 0.5),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 40,
                child: TextField(
                  controller: widget.controller,
                  style: AppTextStyles.body,
                  decoration: InputDecoration(
                    hintText: '输入你的问题...',
                    hintStyle: AppTextStyles.body
                        .copyWith(color: AppColors.textTertiary),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 0,
                    ),
                  ),
                  onSubmitted: (_) => _handleSend(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: canSend ? _handleSend : null,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: canSend ? AppColors.accent : AppColors.progressTrack,
                  shape: BoxShape.circle,
                ),
                child: widget.isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: Padding(
                          padding: EdgeInsets.all(10),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.white,
                          ),
                        ),
                      )
                    : const Icon(
                        Icons.send,
                        size: 16,
                        color: AppColors.white,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
