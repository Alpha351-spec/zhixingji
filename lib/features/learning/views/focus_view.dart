import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/lock_screen_service.dart';
import '../../../core/services/settings_service.dart';
import '../../../data/models/task.dart';
import '../widgets/timer_ring.dart';

/// 专注视图（番茄钟）
///
/// 当前任务标签 → 计时圆环 → 控制按钮 → 时长滚轮选择器 → 快捷出口
///
/// 软锁屏：根据设置页的「软锁屏」开关判定，开启后番茄钟运行期间 App 进入后台时
/// 显示全屏锁屏覆盖层，阻止用户切换到其他应用。
class FocusView extends StatefulWidget {
  final List<Task> tasks;
  final String currentTaskTitle;
  final VoidCallback onReturnToTasks;

  /// 锁屏状态回调，通知父组件是否锁定视图切换
  final ValueChanged<bool> onLockChanged;

  const FocusView({
    super.key,
    required this.tasks,
    required this.currentTaskTitle,
    required this.onReturnToTasks,
    required this.onLockChanged,
  });

  @override
  State<FocusView> createState() => _FocusViewState();
}

/// 番茄钟状态
enum TimerState { ready, running, paused, completed }

class _FocusViewState extends State<FocusView> with WidgetsBindingObserver {
  late int _sessionDuration = SettingsService.current.defaultFocusDuration;
  late int _timeRemaining = _sessionDuration * 60;
  TimerState _timerState = TimerState.ready;
  late String _currentTask;
  String _completionMessage = '';
  Timer? _timer;

  /// 小时滚轮控制器
  late FixedExtentScrollController _hourController;

  /// 分钟滚轮控制器
  late FixedExtentScrollController _minuteController;

  /// 强制锁屏开关（从设置读取）
  bool get _lockScreen => SettingsService.current.softLockScreen;

  /// 是否已获得悬浮窗权限
  bool _hasOverlayPermission = false;

  @override
  void initState() {
    super.initState();
    _currentTask = widget.currentTaskTitle;
    WidgetsBinding.instance.addObserver(this);

    // 初始化滚轮控制器，定位到当前时长
    final initHours = _sessionDuration ~/ 60;
    final initMinutes = _sessionDuration % 60;
    _hourController = FixedExtentScrollController(initialItem: initHours);
    _minuteController = FixedExtentScrollController(initialItem: initMinutes);

    // 初始化锁屏服务回调
    LockScreenService.onAbandonFocus = _onAbandonFocus;

    // 检查权限
    _checkOverlayPermission();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _hourController.dispose();
    _minuteController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    // 退出时关闭锁屏并解锁
    LockScreenService.hideLockScreen();
    widget.onLockChanged(false);
    super.dispose();
  }

  // ============ 生命周期监听 ============

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    debugPrint('[FocusView] 生命周期: $state, lockScreen=$_lockScreen, timerState=$_timerState');

    if (!_lockScreen || _timerState != TimerState.running) return;

    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        // App 进入后台 → 显示锁屏
        debugPrint('[FocusView] App 进入后台，显示锁屏');
        LockScreenService.showLockScreen(_timeRemaining);
        break;
      case AppLifecycleState.resumed:
        // App 回到前台 → 关闭锁屏
        debugPrint('[FocusView] App 回到前台，关闭锁屏');
        LockScreenService.hideLockScreen();
        break;
      default:
        break;
    }
  }

  // ============ 悬浮窗权限 ============

  Future<void> _checkOverlayPermission() async {
    final granted = await LockScreenService.canDrawOverlays();
    setState(() => _hasOverlayPermission = granted);
  }

  Future<void> _ensureOverlayPermission() async {
    if (_hasOverlayPermission) return;

    // 先检查一次（用户可能已在系统设置中开启）
    await _checkOverlayPermission();
    if (_hasOverlayPermission) return;

    // 引导用户去设置
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('需要"显示在其他应用上层"权限才能使用锁屏功能'),
          duration: Duration(seconds: 3),
        ),
      );
    }
    await LockScreenService.requestOverlayPermission();

    // 延迟检查用户是否已授权
    await Future.delayed(const Duration(seconds: 1));
    await _checkOverlayPermission();
  }

  // ============ 番茄钟逻辑 ============

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_timeRemaining <= 1) {
          _timeRemaining = 0;
          _timerState = TimerState.completed;
          _completionMessage = '你已专注 $_sessionDuration 分钟，真棒！';
          timer.cancel();
          // 完成后自动解锁 + 关闭锁屏
          if (_lockScreen) {
            LockScreenService.hideLockScreen();
            widget.onLockChanged(false);
          }
        } else {
          _timeRemaining--;
          // 同步更新原生锁屏上的倒计时
          if (_lockScreen) {
            LockScreenService.updateCountdown(_timeRemaining);
          }
        }
      });
    });
  }

  void _pauseTimer() {
    _timer?.cancel();
  }

  void _toggleTimer() {
    // 时长为 0 时禁止开始专注
    if (_timerState == TimerState.ready && _sessionDuration == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请先设置专注时长'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    if (_timerState == TimerState.completed) {
      setState(() {
        _timer?.cancel();
        _timeRemaining = _sessionDuration * 60;
        _timerState = TimerState.ready;
        _completionMessage = '';
      });
      return;
    }

    if (_timerState == TimerState.running) {
      setState(() => _timerState = TimerState.paused);
      _pauseTimer();
      return;
    }

    if (_timerState == TimerState.paused) {
      setState(() => _timerState = TimerState.running);
      _startTimer();
      return;
    }

    // ready 状态：开始专注前检查锁屏权限
    if (_timerState == TimerState.ready) {
      if (_lockScreen) {
        _startFocusWithOverlayCheck();
      } else {
        setState(() => _timerState = TimerState.running);
        _startTimer();
      }
    }
  }

  /// 开始专注（带悬浮窗权限检查）
  Future<void> _startFocusWithOverlayCheck() async {
    // 先检查权限
    final hasPermission = await LockScreenService.canDrawOverlays();

    if (hasPermission) {
      // 已有权限，直接开始
      if (!mounted) return;
      setState(() {
        _hasOverlayPermission = true;
        _timerState = TimerState.running;
      });
      _startTimer();
      return;
    }

    // 没有权限，弹对话框引导用户授权
    if (!mounted) return;
    final shouldRequest = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('需要悬浮窗权限'),
        content: const Text('软锁屏功能需要"显示在其他应用上层"权限才能正常工作。\n\n点击"去设置"后，请在系统设置中开启权限，然后返回应用。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('去设置'),
          ),
        ],
      ),
    );

    if (shouldRequest != true) {
      // 用户取消，不开始专注
      return;
    }

    // 跳转系统设置
    await LockScreenService.requestOverlayPermission();

    // 等待用户从设置页返回（给足够时间）
    if (!mounted) return;

    // 弹提示让用户确认已授权
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('已开启权限？'),
        content: const Text('如果您已在系统设置中开启权限，请点击"已开启"开始专注。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('再等等'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('已开启'),
          ),
        ],
      ),
    );

    // 重新检查权限
    final nowHasPermission = await LockScreenService.canDrawOverlays();
    if (!mounted) return;

    setState(() => _hasOverlayPermission = nowHasPermission);

    if (nowHasPermission) {
      setState(() => _timerState = TimerState.running);
      _startTimer();
    } else {
      // 仍然没有权限，提示用户
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('未获得悬浮窗权限，无法使用锁屏功能。可在设置中关闭锁屏后开始专注。'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _changeDuration(int duration) {
    _timer?.cancel();
    setState(() {
      _sessionDuration = duration;
      _timeRemaining = duration * 60;
      _timerState = TimerState.ready;
      _completionMessage = '';
    });
    // 同步滚轮位置（跳到中间区域以支持无限滚动）
    final hours = duration ~/ 60;
    final minutes = duration % 60;
    const offset = 30000; // 与 _WheelColumn._virtualCount~/2 对齐
    if (_hourController.hasClients) {
      _hourController.animateToItem(
        offset + hours,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
    if (_minuteController.hasClients) {
      _minuteController.animateToItem(
        offset + minutes,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  // ============ 锁屏逻辑 ============

  void _showLockWarning() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('专注锁定中，请先暂停或完成专注'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  /// 用户点击原生锁屏上的"放弃专注"
  void _onAbandonFocus() {
    debugPrint('[FocusView] 用户放弃专注');
    // 终止计时器
    _timer?.cancel();
    setState(() {
      _timerState = TimerState.ready;
      _timeRemaining = _sessionDuration * 60;
      _completionMessage = '';
    });
    widget.onLockChanged(false);

    // 关闭锁屏（安全起见）
    LockScreenService.hideLockScreen();

    // 弹出提示
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('专注已放弃'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  /// 尝试返回任务列表（锁屏时拦截）
  void _tryReturnToTasks() {
    if (_lockScreen && _timerState == TimerState.running) {
      _showLockWarning();
      return;
    }
    widget.onReturnToTasks();
  }

  // ============ 辅助 getter ============

  String get _timeDisplay {
    if (_timerState == TimerState.completed) return '完成';
    final hours = _timeRemaining ~/ 3600;
    final minutes = (_timeRemaining % 3600) ~/ 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';
  }

  double get _progress {
    if (_timerState == TimerState.completed) return 1.0;
    final total = _sessionDuration * 60;
    if (total == 0) return 0.0;
    return (total - _timeRemaining) / total;
  }

  Color get _buttonColor {
    // 0:0 且未开始时禁用
    if (_timerState == TimerState.ready && _sessionDuration == 0) {
      return AppColors.textTertiary;
    }
    return _timerState == TimerState.paused ||
            _timerState == TimerState.completed
        ? AppColors.accentLight
        : AppColors.accent;
  }

  // ============ UI 构建 ============

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Column(
            children: [
              const SizedBox(height: 24),

              // 当前任务标签
              _taskLabel(),

              const SizedBox(height: 40),

              // 计时圆环（ready 状态中心为滚轮选择器）
              TimerRing(
                timeDisplay: _timeDisplay,
                subtitle: '专注中 · $_sessionDuration分钟',
                progress: _progress,
                isCompleted: _timerState == TimerState.completed,
                centerWidget: _timerState == TimerState.ready
                    ? _durationWheel()
                    : null,
              ),

              const SizedBox(height: 36),

              // 控制按钮 + 重置按钮
              _controlButton(),

              const SizedBox(height: 16),

              // 重置按钮（非 ready 状态显示）
              if (_timerState != TimerState.ready) _resetButton(),

              const SizedBox(height: 24),

              // 完成提示
              if (_completionMessage.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Text(
                    _completionMessage,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.accent,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// 当前任务胶囊标签（纯显示，不可展开）
  Widget _taskLabel() {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.white,
          border: Border.all(color: AppColors.borderButton, width: 0.5),
          borderRadius: BorderRadius.circular(AppConstants.buttonRadius),
        ),
        child: Text(
          '正在专注：$_currentTask',
          style: AppTextStyles.subtitle,
        ),
      ),
    );
  }

  /// 圆形控制按钮
  Widget _controlButton() {
    return GestureDetector(
      onTap: _toggleTimer,
      child: Container(
        width: AppConstants.controlButtonSize,
        height: AppConstants.controlButtonSize,
        decoration: BoxDecoration(
          color: _buttonColor,
          shape: BoxShape.circle,
        ),
        child: Icon(
          _timerState == TimerState.completed
              ? Icons.check
              : _timerState == TimerState.running
                  ? Icons.pause
                  : Icons.play_arrow,
          color: AppColors.white,
          size: 28,
        ),
      ),
    );
  }

  /// 重置计时器
  void _resetTimer() {
    _timer?.cancel();
    // 关闭锁屏
    if (_lockScreen) {
      LockScreenService.hideLockScreen();
      widget.onLockChanged(false);
    }
    setState(() {
      _timerState = TimerState.ready;
      _timeRemaining = _sessionDuration * 60;
      _completionMessage = '';
    });
  }

  /// 重置按钮
  Widget _resetButton() {
    return TextButton.icon(
      onPressed: _resetTimer,
      icon: const Icon(Icons.refresh, size: 16, color: AppColors.textTertiary),
      label: const Text(
        '重置',
        style: TextStyle(
          fontSize: 13,
          color: AppColors.textTertiary,
        ),
      ),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

  /// 圆环内的双列滚轮时长选择器（小时：分钟）
  ///
  /// 仅在 ready 状态显示，嵌入圆环中心。
  /// 左列 0-23 小时，右列 0-59 分钟。
  Widget _durationWheel() {
    final currentHours = _sessionDuration ~/ 60;
    final currentMinutes = _sessionDuration % 60;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 100,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // 选中行高亮条
              Positioned(
                top: 30,
                child: Container(
                  width: 180,
                  height: 40,
                  decoration: BoxDecoration(
                    border: Border.symmetric(
                      horizontal: BorderSide(
                        color: AppColors.borderCard,
                        width: 0.5,
                      ),
                    ),
                  ),
                ),
              ),

              // 双列滚轮
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // 小时列
                  _wheelColumn(
                    controller: _hourController,
                    itemCount: 24,
                    selectedValue: currentHours,
                    suffix: '时',
                    onChanged: (value) => _onWheelChanged(),
                  ),

                  // 分隔符
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      ':',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        color: AppColors.accent,
                        fontFamily: AppTextStyles.fontFamilyMono,
                      ),
                    ),
                  ),

                  // 分钟列
                  _wheelColumn(
                    controller: _minuteController,
                    itemCount: 60,
                    selectedValue: currentMinutes,
                    suffix: '分',
                    onChanged: (value) => _onWheelChanged(),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '上下滚动选择时长',
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textTertiary,
          ),
        ),
      ],
    );
  }

  /// 滚轮变化时更新总时长
  void _onWheelChanged() {
    final hours = _hourController.selectedItem % 24;
    final minutes = _minuteController.selectedItem % 60;
    final total = hours * 60 + minutes;
    if (total != _sessionDuration) {
      _timer?.cancel();
      setState(() {
        _sessionDuration = total;
        _timeRemaining = total * 60;
        _timerState = TimerState.ready;
        _completionMessage = '';
      });
    }
  }

  /// 单列滚轮（实时跟踪居中项以更新加粗样式）
  Widget _wheelColumn({
    required FixedExtentScrollController controller,
    required int itemCount,
    required int selectedValue,
    required String suffix,
    required ValueChanged<int> onChanged,
  }) {
    return _WheelColumn(
      controller: controller,
      itemCount: itemCount,
      initialSelected: selectedValue,
      suffix: suffix,
      onChanged: onChanged,
    );
  }
}

/// 滚轮列组件
///
/// 使用 ValueNotifier 持有当前选中索引，滚动时只更新 notifier，
/// 不调用 setState，避免重建 ListWheelScrollView 扰动滚动状态。
/// 每个 item 通过 ValueListenableBuilder 独立监听，只有新旧两个 item 更新样式。
/// 通过大倍数 + 取模映射实现无限循环滚动。
class _WheelColumn extends StatefulWidget {
  final FixedExtentScrollController controller;
  final int itemCount;
  final int initialSelected;
  final String suffix;
  final ValueChanged<int> onChanged;

  const _WheelColumn({
    required this.controller,
    required this.itemCount,
    required this.initialSelected,
    required this.suffix,
    required this.onChanged,
  });

  @override
  State<_WheelColumn> createState() => _WheelColumnState();
}

class _WheelColumnState extends State<_WheelColumn> {
  /// 当前选中索引（0 ~ itemCount-1，实际值）
  late final ValueNotifier<int> _selectedNotifier;

  /// 用于实现无限滚动的虚拟 item 总数
  static const int _virtualCount = 60000;

  /// 虚拟索引偏移量，使初始位置在中间，可上下无限滚动
  late final int _offset;

  @override
  void initState() {
    super.initState();
    _selectedNotifier = ValueNotifier<int>(widget.initialSelected);
    // 让初始位置位于中间，便于上下滚动
    _offset = (_virtualCount ~/ 2) - (_virtualCount ~/ 2) % widget.itemCount;
    // 跳转到带偏移的初始位置（下一帧执行，确保 controller 已 attach）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.controller.hasClients) {
        widget.controller.jumpToItem(_offset + widget.initialSelected);
      }
    });
  }

  @override
  void didUpdateWidget(_WheelColumn oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 外部同步（如重置）时跟随 initialSelected
    if (widget.initialSelected != _selectedNotifier.value) {
      _selectedNotifier.value = widget.initialSelected;
    }
  }

  @override
  void dispose() {
    _selectedNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 70,
      height: 100,
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification is ScrollEndNotification) {
            // 通知实际值（取模后）
            widget.onChanged(
              widget.controller.selectedItem % widget.itemCount,
            );
          }
          return false;
        },
        child: ListWheelScrollView.useDelegate(
          controller: widget.controller,
          itemExtent: 40,
          perspective: 0.003,
          diameterRatio: 1.5,
          physics: const FixedExtentScrollPhysics(),
          onSelectedItemChanged: (index) {
            // 只更新 notifier，不调用 setState
            _selectedNotifier.value = index % widget.itemCount;
          },
          childDelegate: ListWheelChildBuilderDelegate(
            childCount: _virtualCount,
            builder: (context, virtualIndex) {
              final realIndex = virtualIndex % widget.itemCount;
              // 每个 item 独立监听 notifier，只有自身是/否选中时才重建
              return ValueListenableBuilder<int>(
                valueListenable: _selectedNotifier,
                builder: (context, selected, _) {
                  final isSelected = realIndex == selected;
                  return Center(
                    child: Text(
                      '$realIndex${widget.suffix}',
                      style: TextStyle(
                        fontSize: isSelected ? 30 : 18,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w300,
                        color: isSelected
                            ? AppColors.accent
                            : AppColors.textTertiary,
                        fontFamily: AppTextStyles.fontFamilyMono,
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
