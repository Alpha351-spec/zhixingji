import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/services/settings_service.dart';
import '../../data/models/app_settings.dart';

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

  // 选项常量
  static const List<String> _resourceModeOptions = ['纯净模式', '引导模式', '资源模式'];
  static const List<String> _planDetailOptions = ['精简', '标准', '详细'];
  static const List<String> _focusDurationOptions = ['15', '25', '45'];
  static const List<String> _noiseTypeOptions = ['雨声', '森林', '咖啡馆', '篝火', '纯白噪音'];
  static const List<String> _weekdayNames = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];

  @override
  void initState() {
    super.initState();
    _settings = SettingsService.current;
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

                  // 每日任务数量上限（滑块）
                  _sliderRow(
                    label: '每日任务数量上限',
                    value: _settings.dailyTaskLimit.toDouble(),
                    min: 3,
                    max: 8,
                    divisions: 5,
                    valueLabel: '${_settings.dailyTaskLimit}',
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
                    ),
                  ],
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

  /// 单选行
  Widget _selectRow({
    required String label,
    required String value,
    required List<String> options,
    required ValueChanged<String> onSelected,
  }) {
    return InkWell(
      onTap: () => _showOptionSheet(label, options, value, onSelected),
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
    ValueChanged<String> onSelected,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (context) {
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
