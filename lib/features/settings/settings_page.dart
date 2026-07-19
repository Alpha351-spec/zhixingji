import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/services/settings_service.dart';
import '../../core/services/white_noise_generator.dart';
import '../../data/models/app_settings.dart';
import '../../services/supabase_config.dart';
import '../../services/user_service.dart';
import '../../services/sync_service.dart';

/// 设置页
///
/// 三大分类：学习偏好、通知与提醒、专注模式
/// 使用微信风格分组列表布局。
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late AppSettings _settings;

  // 白噪音试听播放器（用于选项弹窗中的试听）
  final WhiteNoiseGenerator _previewPlayer = WhiteNoiseGenerator();
  String? _previewingType; // 当前正在试听的类型

  // 同步状态
  bool _isSyncing = false;

  // 选项常量
  static const List<String> _resourceModeOptions = ['纯净模式', '引导模式', '资源模式'];
  static const List<String> _planDetailOptions = ['精简', '标准', '详细'];
  static const List<String> _focusDurationOptions = ['15', '25', '45'];
  static const List<String> _noiseTypeOptions = ['雨声', '森林', '篝火', '纯白噪音'];
  static const List<String> _weekdayNames = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];

  @override
  void initState() {
    super.initState();
    _settings = SettingsService.current;
  }

  @override
  void dispose() {
    _previewPlayer.dispose();
    super.dispose();
  }

  /// 试听/停止试听某个白噪音类型
  Future<void> _togglePreview(String type) async {
    if (_previewingType == type) {
      await _previewPlayer.stop();
      setState(() => _previewingType = null);
    } else {
      // 如果已有其他在播放，先停止（stop 是异步淡出，这里直接换源）
      await _previewPlayer.start(type);
      setState(() => _previewingType = type);
    }
  }

  /// 手动触发云端同步
  Future<void> _syncData() async {
    if (!SupabaseConfig.isConfigured) {
      _showSyncResult('云端未配置，无法同步');
      return;
    }
    if (_isSyncing) return;

    setState(() {
      _isSyncing = true;
    });

    await SyncService.syncAll(UserService.userId);

    if (mounted) {
      setState(() {
        _isSyncing = false;
      });
      _showSyncResult('数据同步完成');
    }
  }

  /// 显示同步结果提示
  void _showSyncResult(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _update(AppSettings newSettings) async {
    setState(() => _settings = newSettings);
    await SettingsService.save(newSettings);
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
          icon: const Icon(Icons.arrow_back_ios, size: 20, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          '设置',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),

            // ========== 一、学习偏好 ==========
            _sectionTitle('学习偏好'),
            Container(
              color: AppColors.white,
              child: Column(
                children: [
                  _selectRow(
                    label: '资源显示模式',
                    value: _settings.resourceMode,
                    options: _resourceModeOptions,
                    onSelected: (v) => _update(_settings.copyWith(resourceMode: v)),
                  ),
                  _divider(),

                  // 每日任务数（滑块）
                  _sliderRow(
                    label: '每日任务数',
                    value: _settings.dailyTaskLimit.toDouble(),
                    min: 1,
                    max: 8,
                    divisions: 7,
                    valueLabel: '${_settings.dailyTaskLimit} 个/天',
                    onChanged: (v) => _update(_settings.copyWith(dailyTaskLimit: v.round())),
                  ),
                  _divider(),

                  _selectRow(
                    label: '计划详细程度',
                    value: _settings.planDetailLevel,
                    options: _planDetailOptions,
                    onSelected: (v) => _update(_settings.copyWith(planDetailLevel: v)),
                  ),
                  _divider(),

                  // 每周休息日（多选）
                  _multiSelectRow(
                    label: '每周休息日',
                    selectedValues: _settings.restDays
                        .map((d) => _weekdayNames[d - 1])
                        .toList(),
                    options: _weekdayNames,
                    onConfirm: (selected) {
                      final days = selected
                          .map((name) => _weekdayNames.indexOf(name) + 1)
                          .toList()
                        ..sort();
                      _update(_settings.copyWith(restDays: days));
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // ========== 二、通知与提醒 ==========
            _sectionTitle('通知与提醒'),
            Container(
              color: AppColors.white,
              child: Column(
                children: [
                  // 每日打卡提醒（开关 + 时间）
                  _switchRow(
                    label: '每日打卡提醒',
                    value: _settings.dailyReminder,
                    onChanged: (v) => _update(_settings.copyWith(dailyReminder: v)),
                    trailing: _settings.dailyReminder
                        ? GestureDetector(
                            onTap: () => _pickTime(),
                            child: Text(
                              _settings.dailyReminderTime,
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppColors.accent,
                              ),
                            ),
                          )
                        : null,
                  ),
                  _divider(),

                  _switchRow(
                    label: '番茄钟完成通知',
                    value: _settings.pomodoroNotification,
                    onChanged: (v) => _update(_settings.copyWith(pomodoroNotification: v)),
                  ),
                  _divider(),

                  _switchRow(
                    label: '计划续订提醒',
                    value: _settings.planRenewalReminder,
                    onChanged: (v) => _update(_settings.copyWith(planRenewalReminder: v)),
                  ),
                  _divider(),

                  _switchRow(
                    label: '连续天数预警',
                    value: _settings.streakWarning,
                    onChanged: (v) => _update(_settings.copyWith(streakWarning: v)),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // ========== 三、专注模式 ==========
            _sectionTitle('专注模式'),
            Container(
              color: AppColors.white,
              child: Column(
                children: [
                  _switchRow(
                    label: '软锁屏',
                    value: _settings.softLockScreen,
                    onChanged: (v) => _update(_settings.copyWith(softLockScreen: v)),
                  ),
                  _divider(),

                  _selectRow(
                    label: '默认专注时长',
                    value: '${_settings.defaultFocusDuration}分钟',
                    options: _focusDurationOptions.map((e) => '$e分钟').toList(),
                    onSelected: (v) {
                      final mins = int.parse(v.replaceAll('分钟', ''));
                      _update(_settings.copyWith(defaultFocusDuration: mins));
                    },
                  ),
                  _divider(),

                  _switchRow(
                    label: '专注白噪音',
                    value: _settings.whiteNoise,
                    onChanged: (v) => _update(_settings.copyWith(whiteNoise: v)),
                  ),
                  if (_settings.whiteNoise) ...[
                    _divider(),
                    _selectRow(
                      label: '白噪音类型',
                      value: _settings.whiteNoiseType,
                      options: _noiseTypeOptions,
                      onSelected: (v) => _update(_settings.copyWith(whiteNoiseType: v)),
                      onPreview: _togglePreview,
                      previewingValue: _previewingType,
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 8),

            // ========== 四、数据管理 ==========
            _sectionTitle('数据管理'),
            Container(
              color: AppColors.white,
              child: Column(
                children: [
                  // 云端同步状态
                  _listTile(
                    icon: Icons.cloud_upload_outlined,
                    iconColor: AppColors.accent,
                    title: '同步数据到云端',
                    trailing: _isSyncing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.accent,
                            ),
                          )
                        : Icon(
                            Icons.chevron_right,
                            color: AppColors.textTertiary,
                            size: 20,
                          ),
                    onTap: _isSyncing ? null : _syncData,
                  ),
                  _divider(),
                  // 用户码显示
                  _listTile(
                    icon: Icons.person_outline,
                    iconColor: AppColors.textSecondary,
                    title: '用户码',
                    trailing: Text(
                      UserService.userId,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textTertiary,
                        fontFamily: AppTextStyles.fontFamily,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // ============ 组件构建 ============

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  Widget _divider() {
    return const Padding(
      padding: EdgeInsets.only(left: 20),
      child: Divider(height: 1, thickness: 0.5, color: AppColors.borderCard),
    );
  }

  /// 列表项（图标 + 标题 + 尾部组件）
  Widget _listTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 22, color: iconColor),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            if (trailing != null) trailing,
          ],
        ),
      ),
    );
  }

  /// 单选行
  ///
  /// [onPreview] 和 [previewingValue] 用于白噪音试听：传入后选项弹窗中每项
  /// 右侧会显示一个试听按钮，点击切换播放/停止。
  Widget _selectRow({
    required String label,
    required String value,
    required List<String> options,
    required ValueChanged<String> onSelected,
    ValueChanged<String>? onPreview,
    String? previewingValue,
  }) {
    return InkWell(
      onTap: () => _showOptionSheet(
        label,
        options,
        value,
        onSelected,
        onPreview: onPreview,
        previewingValue: previewingValue,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 15, color: AppColors.textPrimary),
            ),
            const Spacer(),
            Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.chevron_right,
              size: 18,
              color: AppColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }

  /// 滑块行
  Widget _sliderRow({
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String valueLabel,
    required ValueChanged<double> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 15,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                Text(
                  valueLabel,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: AppColors.accent,
              inactiveTrackColor: AppColors.borderCard,
              thumbColor: AppColors.accent,
              overlayColor: AppColors.accent.withValues(alpha: 0.12),
              trackHeight: 3,
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  /// 开关行
  Widget _switchRow({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 15,
              color: AppColors.textPrimary,
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 12),
            trailing,
          ],
          const Spacer(),
          Transform.scale(
            scale: 0.85,
            child: Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: AppColors.white,
              activeTrackColor: AppColors.accent,
              inactiveThumbColor: AppColors.white,
              inactiveTrackColor: AppColors.borderCard,
              trackOutlineColor: WidgetStateProperty.resolveWith(
                (states) => AppColors.transparent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 多选行
  Widget _multiSelectRow({
    required String label,
    required List<String> selectedValues,
    required List<String> options,
    required ValueChanged<List<String>> onConfirm,
  }) {
    final displayText = selectedValues.isEmpty
        ? '无'
        : selectedValues.length == options.length
            ? '每天'
            : selectedValues.length == 1
                ? selectedValues.first
                : '${selectedValues.length}天';

    return InkWell(
      onTap: () => _showMultiSelectSheet(label, options, selectedValues, onConfirm),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 15, color: AppColors.textPrimary),
            ),
            const Spacer(),
            Text(
              displayText,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.chevron_right,
              size: 18,
              color: AppColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }

  // ============ 弹窗 ============

  void _showOptionSheet(
    String title,
    List<String> options,
    String current,
    ValueChanged<String> onSelected, {
    ValueChanged<String>? onPreview,
    String? previewingValue,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (context) {
        // 弹窗内独立的试听状态，与外部 _previewingType 同步
        var localPreviewing = previewingValue;
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const Divider(height: 1, thickness: 0.5),
                  ...options.map((opt) {
                    final isSelected = opt == current;
                    final isPreviewing = localPreviewing == opt;
                    return InkWell(
                      onTap: () {
                        onSelected(opt);
                        Navigator.of(context).pop();
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 14),
                        child: Row(
                          children: [
                            // 试听图标（仅当 onPreview 不为 null 时显示），放在选项名左边
                            if (onPreview != null) ...[
                              GestureDetector(
                                onTap: () {
                                  onPreview(opt);
                                  setModalState(() {
                                    // 切换试听状态：点正在播放的 → 停止；点其他的 → 换源
                                    localPreviewing =
                                        localPreviewing == opt ? null : opt;
                                  });
                                },
                                child: Icon(
                                  isPreviewing
                                      ? Icons.graphic_eq
                                      : Icons.volume_up_outlined,
                                  size: 20,
                                  color: isPreviewing
                                      ? AppColors.accent
                                      : AppColors.textTertiary,
                                ),
                              ),
                              const SizedBox(width: 12),
                            ],
                            Text(
                              opt,
                              style: TextStyle(
                                fontSize: 15,
                                color: isSelected
                                    ? AppColors.accent
                                    : AppColors.textPrimary,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                            ),
                            const Spacer(),
                            if (isSelected)
                              const Icon(
                                Icons.check,
                                size: 18,
                                color: AppColors.accent,
                              ),
                          ],
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 8),
                ],
              ),
            );
          },
        );
      },
    ).then((_) {
      // 弹窗关闭时停止试听
      if (_previewingType != null) {
        _togglePreview(_previewingType!);
      }
    });
  }

  void _showMultiSelectSheet(
    String title,
    List<String> options,
    List<String> currentSelected,
    ValueChanged<List<String>> onConfirm,
  ) {
    List<String> tempSelected = List.from(currentSelected);

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const Divider(height: 1, thickness: 0.5),
                  ...options.map((opt) {
                    final isSelected = tempSelected.contains(opt);
                    return InkWell(
                      onTap: () {
                        setModalState(() {
                          if (isSelected) {
                            tempSelected.remove(opt);
                          } else {
                            tempSelected.add(opt);
                          }
                        });
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 14),
                        child: Row(
                          children: [
                            Text(
                              opt,
                              style: TextStyle(
                                fontSize: 15,
                                color: isSelected
                                    ? AppColors.accent
                                    : AppColors.textPrimary,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                            ),
                            const Spacer(),
                            if (isSelected)
                              const Icon(
                                Icons.check,
                                size: 18,
                                color: AppColors.accent,
                              ),
                          ],
                        ),
                      ),
                    );
                  }),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('取消'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              onConfirm(tempSelected);
                              Navigator.of(context).pop();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.accent,
                              foregroundColor: AppColors.white,
                              elevation: 0,
                            ),
                            child: const Text('确定'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _pickTime() async {
    final parts = _settings.dailyReminderTime.split(':');
    final initial = TimeOfDay(
      hour: int.parse(parts[0]),
      minute: int.parse(parts[1]),
    );
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: AppColors.accent,
                ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      final timeStr =
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      _update(_settings.copyWith(dailyReminderTime: timeStr));
    }
  }
}
