import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:just_audio/just_audio.dart';

/// 白噪音播放器 —— 播放 assets/music 下的预录音频，循环播放
///
/// 四种声音：
/// - 雨声     → white noise.mp3
/// - 森林     → campfire.mp3
/// - 篝火     → forest birds.mp3
/// - 纯白噪音 → rain ambience.mp3
///
/// 特性：
/// - 音量均衡：默认音量为最大音量的 45%
/// - 无缝循环：音频自然循环
/// - 平滑启停：开始时 1 秒淡入，停止时 2 秒淡出
class WhiteNoiseGenerator {
  /// 默认音量（最大音量的 45%）
  static const double defaultVolume = 0.45;

  /// 中文类型名 → 资产文件路径（完整路径，含 assets/ 前缀）
  static const Map<String, String> typeToAsset = {
    '雨声': 'assets/music/white noise.mp3',
    '森林': 'assets/music/campfire.mp3',
    '篝火': 'assets/music/forest birds.mp3',
    '纯白噪音': 'assets/music/rain ambience.mp3',
  };

  final AudioPlayer _player = AudioPlayer();

  bool _isPlaying = false;
  bool _isStopping = false;
  String _currentType = '雨声';
  Timer? _fadeTimer;

  // 缓存已加载的音频字节（避免重复加载）
  final Map<String, Uint8List> _cache = {};

  bool get isPlaying => _isPlaying;
  String get currentType => _currentType;

  /// 开始播放指定类型的声音
  ///
  /// [type] 传中文名（雨声/森林/篝火/纯白噪音）。
  /// 开始时音量从零渐强（约 1 秒）到默认音量。
  Future<void> start(String type) async {
    if (_isPlaying && _currentType == type) return;

    // 取消正在进行的淡出
    _fadeTimer?.cancel();
    _isStopping = false;

    _currentType = type;
    final assetPath = typeToAsset[type];
    if (assetPath == null) return;

    // 从 rootBundle 读取音频字节（带缓存）
    final bytes = await _loadAsset(assetPath);

    // 先停止当前播放（避免切换时的冲突）
    if (_isPlaying) {
      await _player.stop();
    }

    // 从音量 0 开始，避免突兀
    await _player.setVolume(0);
    await _player.setAudioSource(
      _WavAudioSource(bytes),
      initialPosition: Duration.zero,
    );
    await _player.setLoopMode(LoopMode.one);
    await _player.play();
    _isPlaying = true;

    // 1 秒淡入到默认音量
    _fadeIn();
  }

  /// 停止播放（音量渐弱约 2 秒后停止）
  Future<void> stop() async {
    if (!_isPlaying || _isStopping) return;
    _isStopping = true;
    _fadeTimer?.cancel();
    _fadeOut();
  }

  /// 释放资源（销毁后不可再用）
  Future<void> dispose() async {
    _fadeTimer?.cancel();
    await _player.dispose();
    _isPlaying = false;
  }

  // ============ 内部实现 ============

  /// 加载资产字节（带缓存）
  Future<Uint8List> _loadAsset(String path) async {
    if (_cache.containsKey(path)) return _cache[path]!;
    final data = await rootBundle.load(path);
    _cache[path] = data.buffer.asUint8List();
    return _cache[path]!;
  }

  /// 1 秒淡入：从 0 渐强到 defaultVolume
  void _fadeIn() {
    const steps = 50;
    const interval = Duration(milliseconds: 20);
    var step = 0;
    _fadeTimer = Timer.periodic(interval, (timer) {
      step++;
      if (_isStopping || !_isPlaying) {
        timer.cancel();
        return;
      }
      final vol = defaultVolume * (step / steps);
      _player.setVolume(vol.clamp(0.0, defaultVolume));
      if (step >= steps) {
        _player.setVolume(defaultVolume);
        timer.cancel();
      }
    });
  }

  /// 2 秒淡出：从默认音量渐弱到 0，然后停止
  void _fadeOut() {
    const steps = 100;
    const interval = Duration(milliseconds: 20);
    var step = 0;
    _fadeTimer = Timer.periodic(interval, (timer) {
      step++;
      final vol = defaultVolume * (1 - step / steps);
      _player.setVolume(vol > 0 ? vol : 0);
      if (step >= steps) {
        _player.stop();
        _isPlaying = false;
        _isStopping = false;
        timer.cancel();
      }
    });
  }
}

/// 将内存中的音频字节流包装为 just_audio 的 AudioSource
class _WavAudioSource extends StreamAudioSource {
  final Uint8List _bytes;

  _WavAudioSource(this._bytes);

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    start ??= 0;
    end ??= _bytes.length;
    return StreamAudioResponse(
      sourceLength: _bytes.length,
      contentLength: end - start,
      offset: start,
      stream: Stream.value(_bytes.sublist(start, end)),
      contentType: 'audio/mpeg',
    );
  }
}
