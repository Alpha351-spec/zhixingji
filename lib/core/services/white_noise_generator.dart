import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_sound/flutter_sound.dart';

/// 白噪音生成器 —— 实时合成 PCM 音频流
///
/// 使用 flutter_sound 的流式播放器，通过 [feedUint8FromStream]
/// 推送实时生成的 16-bit PCM 数据，无需任何外部音频文件。
///
/// 五种声音：
/// - white    纯白噪音（均匀随机）
/// - rain     模拟雨声（低通滤波白噪音）
/// - forest   模拟森林（背景虫鸣 + 随机鸟鸣）
/// - cafe     模拟咖啡馆（低频嘈杂 + 中频人声嗡嗡）
/// - campfire 模拟篝火（低频噪音 + 偶尔噼啪声）
class WhiteNoiseGenerator {
  // ============ 音频参数 ============
  static const int sampleRate = 44100; // 采样率
  static const int numChannels = 1; // 单声道
  static const int bufferMs = 100; // 每次推送的时长（毫秒）
  static const int samplesPerBuffer = sampleRate * bufferMs ~/ 1000; // 4410

  // 中文类型名 → 英文 key（方便设置页直接传中文）
  static const Map<String, String> cnToEn = {
    '纯白噪音': 'white',
    '雨声': 'rain',
    '森林': 'forest',
    '咖啡馆': 'cafe',
    '篝火': 'campfire',
  };

  final FlutterSoundPlayer _player = FlutterSoundPlayer();
  Timer? _timer;
  final Random _rng = Random();

  bool _isPlaying = false;
  bool _initialized = false;
  String _currentType = 'white';

  // ============ 滤波器 / 振荡器状态（跨采样连续）============
  double _filterState = 0; // 一阶低通滤波器上一次输出
  double _phase = 0; // 正弦波相位（鸟鸣 / 嗡嗡声）
  int _sampleCount = 0; // 全局采样计数（用于触发周期性事件）

  bool get isPlaying => _isPlaying;
  String get currentType => _currentType;

  /// 开始播放指定类型的声音
  ///
  /// [type] 可传英文 key（white/rain/forest/cafe/campfire）或中文名（雨声 等）。
  /// 如果正在播放同一类型则直接返回；若换了类型则无缝切换。
  Future<void> start(String type) async {
    final t = cnToEn[type] ?? type;

    if (_isPlaying && _currentType == t) return;

    await _ensureInit();

    if (!_isPlaying) {
      await _player.startPlayerFromStream(
        codec: Codec.pcm16,
        interleaved: true,
        numChannels: numChannels,
        sampleRate: sampleRate,
        bufferSize: samplesPerBuffer,
      );
    }

    _currentType = t;
    _isPlaying = true;
    _resetState();

    // 每 100ms 生成一块 PCM 并推送
    _timer = Timer.periodic(
      const Duration(milliseconds: bufferMs),
      (_) => _generateAndFeed(),
    );
  }

  /// 停止播放（不释放资源，可再次 start）
  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    _isPlaying = false;
    if (_initialized && _player.isPlaying) {
      await _player.stopPlayer();
    }
  }

  /// 释放资源（销毁后不可再用）
  Future<void> dispose() async {
    await stop();
    if (_initialized) {
      await _player.closePlayer();
      _initialized = false;
    }
  }

  // ============ 内部实现 ============

  Future<void> _ensureInit() async {
    if (_initialized) return;
    await _player.openPlayer();
    _initialized = true;
  }

  void _resetState() {
    _filterState = 0;
    _phase = 0;
    _sampleCount = 0;
  }

  /// 生成一块 PCM 数据并推送到播放器
  void _generateAndFeed() {
    final data = Int16List(samplesPerBuffer);
    for (var i = 0; i < samplesPerBuffer; i++) {
      final sample = _genSample();
      // double [-1.0, 1.0] → int16 [-32768, 32767]
      data[i] = (sample * 32767).round().clamp(-32768, 32767);
    }
    // feedUint8FromStream 直接接受字节流
    _player.feedUint8FromStream(data.buffer.asUint8List());
  }

  /// 根据当前类型生成单个采样值（范围 [-1.0, 1.0]）
  double _genSample() {
    _sampleCount++;
    switch (_currentType) {
      case 'white':
        return _white();
      case 'rain':
        return _rain();
      case 'forest':
        return _forest();
      case 'cafe':
        return _cafe();
      case 'campfire':
        return _campfire();
      default:
        return _white();
    }
  }

  // ---- 纯白噪音：均匀分布随机 ----
  double _white() {
    return (_rng.nextDouble() * 2 - 1) * 0.3;
  }

  // ---- 雨声：低通滤波后的白噪音 ----
  double _rain() {
    final noise = _rng.nextDouble() * 2 - 1;
    _filterState = _filterState * 0.96 + noise * 0.04;
    return _filterState * 0.5;
  }

  // ---- 森林：背景虫鸣 + 周期性鸟鸣 ----
  double _forest() {
    // 背景低频虫鸣
    var s = (_rng.nextDouble() * 2 - 1) * 0.05;

    // 每 ~2 秒触发一段鸟鸣（持续约 0.5 秒）
    final pos = _sampleCount % sampleRate;
    if (pos < 22050) {
      // 在鸟鸣段内：生成频率渐变的正弦波
      _phase += 2 * pi * (1500 + pos * 0.02) / sampleRate;
      s += sin(_phase) * 0.15;
      // 加入随机性让鸟鸣不那么死板
      s *= _rng.nextDouble() * 0.4 + 0.6;
    } else {
      _phase = 0;
    }
    return s;
  }

  // ---- 咖啡馆：低频嘈杂 + 中频人声嗡嗡 ----
  double _cafe() {
    // 低频背景噪音（低通滤波）
    final noise = _rng.nextDouble() * 2 - 1;
    _filterState = _filterState * 0.98 + noise * 0.02;
    final background = _filterState * 0.3;

    // 中频人声嗡嗡（150-300Hz 的调幅正弦波）
    _phase += 2 * pi * 220 / sampleRate;
    final murmur = sin(_phase) * 0.06 * (_rng.nextDouble() * 0.6 + 0.4);

    return background + murmur;
  }

  // ---- 篝火：低频噪音 + 随机噼啪声 ----
  double _campfire() {
    // 持续的低频噪音
    final noise = _rng.nextDouble() * 2 - 1;
    _filterState = _filterState * 0.99 + noise * 0.01;
    var s = _filterState * 0.3;

    // 偶尔的噼啪声（约每 0.5 秒一次）
    if (_rng.nextDouble() > 0.996) {
      s += (_rng.nextDouble() * 2 - 1) * 0.6;
    }
    return s;
  }
}
