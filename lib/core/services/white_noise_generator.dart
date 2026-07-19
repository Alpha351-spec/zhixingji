import 'dart:math';
import 'dart:typed_data';

import 'package:just_audio/just_audio.dart';

/// 白噪音生成器 —— 代码合成 WAV 音频流，循环播放
///
/// 使用 [just_audio] 的 [StreamAudioSource] 将内存中生成的 WAV 字节流
/// 作为音频源播放。白噪音是循环信号，生成数秒样本循环播放即可，
/// 无需依赖任何外部音频文件。
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
  static const int bitsPerSample = 16; // 16-bit PCM
  static const int loopSeconds = 5; // 循环样本时长（秒）

  // 中文类型名 → 英文 key（方便设置页直接传中文）
  static const Map<String, String> cnToEn = {
    '纯白噪音': 'white',
    '雨声': 'rain',
    '森林': 'forest',
    '咖啡馆': 'cafe',
    '篝火': 'campfire',
  };

  final AudioPlayer _player = AudioPlayer();
  final Random _rng = Random();

  bool _isPlaying = false;
  String _currentType = 'white';

  bool get isPlaying => _isPlaying;
  String get currentType => _currentType;

  /// 开始播放指定类型的声音
  ///
  /// [type] 可传英文 key（white/rain/forest/cafe/campfire）或中文名（雨声 等）。
  /// 如果正在播放同一类型则直接返回；若换了类型则无缝切换。
  Future<void> start(String type) async {
    final t = cnToEn[type] ?? type;
    if (_isPlaying && _currentType == t) return;

    _currentType = t;
    final wavBytes = _generateWav(t);
    await _player.setAudioSource(
      _WavAudioSource(wavBytes),
      initialPosition: Duration.zero,
    );
    await _player.setLoopMode(LoopMode.one);
    await _player.play();
    _isPlaying = true;
  }

  /// 停止播放（不释放资源，可再次 start）
  Future<void> stop() async {
    await _player.stop();
    _isPlaying = false;
  }

  /// 释放资源（销毁后不可再用）
  Future<void> dispose() async {
    await _player.dispose();
    _isPlaying = false;
  }

  // ============ WAV 生成 ============

  /// 生成指定类型的完整 WAV 文件字节流
  Uint8List _generateWav(String type) {
    final numSamples = sampleRate * loopSeconds;
    final dataSize = numSamples * numChannels * (bitsPerSample ~/ 8);
    final fileSize = 36 + dataSize; // RIFF 头 44 字节 - 8 = 36

    final bytes = ByteData(44 + dataSize);

    // ---- RIFF header ----
    bytes.setUint8(0, 0x52); // 'R'
    bytes.setUint8(1, 0x49); // 'I'
    bytes.setUint8(2, 0x46); // 'F'
    bytes.setUint8(3, 0x46); // 'F'
    bytes.setUint32(4, fileSize, Endian.little);
    bytes.setUint8(8, 0x57); // 'W'
    bytes.setUint8(9, 0x41); // 'A'
    bytes.setUint8(10, 0x56); // 'V'
    bytes.setUint8(11, 0x45); // 'E'

    // ---- fmt subchunk ----
    bytes.setUint8(12, 0x66); // 'f'
    bytes.setUint8(13, 0x6D); // 'm'
    bytes.setUint8(14, 0x74); // 't'
    bytes.setUint8(15, 0x20); // ' '
    bytes.setUint32(16, 16, Endian.little); // subchunk size
    bytes.setUint16(20, 1, Endian.little); // audio format = PCM
    bytes.setUint16(22, numChannels, Endian.little);
    bytes.setUint32(24, sampleRate, Endian.little);
    bytes.setUint32(28, sampleRate * numChannels * bitsPerSample ~/ 8, Endian.little); // byte rate
    bytes.setUint16(32, numChannels * bitsPerSample ~/ 8, Endian.little); // block align
    bytes.setUint16(34, bitsPerSample, Endian.little);

    // ---- data subchunk ----
    bytes.setUint8(36, 0x64); // 'd'
    bytes.setUint8(37, 0x61); // 'a'
    bytes.setUint8(38, 0x74); // 't'
    bytes.setUint8(39, 0x61); // 'a'
    bytes.setUint32(40, dataSize, Endian.little);

    // ---- PCM 采样数据 ----
    double filterState = 0;
    double phase = 0;
    for (var i = 0; i < numSamples; i++) {
      final sample = _genSample(type, i, filterState, phase);
      // 更新状态（引用传递模拟）
      filterState = sample.filterState;
      phase = sample.phase;

      final int16 = (sample.value * 32767).round().clamp(-32768, 32767);
      bytes.setInt16(44 + i * 2, int16, Endian.little);
    }

    return bytes.buffer.asUint8List();
  }

  /// 生成单个采样值（范围 [-1.0, 1.0]），同时返回更新后的滤波器/相位状态
  _SampleResult _genSample(
    String type,
    int i,
    double filterState,
    double phase,
  ) {
    switch (type) {
      case 'white':
        return _SampleResult((_rng.nextDouble() * 2 - 1) * 0.3, filterState, phase);
      case 'rain':
        final noise = _rng.nextDouble() * 2 - 1;
        final fs = filterState * 0.96 + noise * 0.04;
        return _SampleResult(fs * 0.5, fs, phase);
      case 'forest':
        return _forest(i, phase);
      case 'cafe':
        return _cafe(i, filterState, phase);
      case 'campfire':
        return _campfire(filterState);
      default:
        return _SampleResult((_rng.nextDouble() * 2 - 1) * 0.3, filterState, phase);
    }
  }

  // ---- 森林：背景虫鸣 + 周期性鸟鸣 ----
  _SampleResult _forest(int i, double phase) {
    var s = (_rng.nextDouble() * 2 - 1) * 0.05; // 背景低频虫鸣
    final pos = i % sampleRate;
    var newPhase = phase;
    if (pos < 22050) {
      // 鸟鸣段：频率渐变正弦波
      newPhase += 2 * pi * (1500 + pos * 0.02) / sampleRate;
      s += sin(newPhase) * 0.15;
      s *= _rng.nextDouble() * 0.4 + 0.6;
    } else {
      newPhase = 0;
    }
    return _SampleResult(s, 0, newPhase);
  }

  // ---- 咖啡馆：低频嘈杂 + 中频人声嗡嗡 ----
  _SampleResult _cafe(int i, double filterState, double phase) {
    final noise = _rng.nextDouble() * 2 - 1;
    final fs = filterState * 0.98 + noise * 0.02;
    final background = fs * 0.3;
    final newPhase = phase + 2 * pi * 220 / sampleRate;
    final murmur = sin(newPhase) * 0.06 * (_rng.nextDouble() * 0.6 + 0.4);
    return _SampleResult(background + murmur, fs, newPhase);
  }

  // ---- 篝火：低频噪音 + 随机噼啪声 ----
  _SampleResult _campfire(double filterState) {
    final noise = _rng.nextDouble() * 2 - 1;
    final fs = filterState * 0.99 + noise * 0.01;
    var s = fs * 0.3;
    if (_rng.nextDouble() > 0.996) {
      s += (_rng.nextDouble() * 2 - 1) * 0.6;
    }
    return _SampleResult(s, fs, 0);
  }
}

/// 采样结果（值 + 更新后的滤波器/相位状态）
class _SampleResult {
  final double value; // [-1.0, 1.0]
  final double filterState;
  final double phase;
  _SampleResult(this.value, this.filterState, this.phase);
}

/// 将内存中的 WAV 字节流包装为 just_audio 的 AudioSource
class _WavAudioSource extends StreamAudioSource {
  final Uint8List _wavBytes;

  _WavAudioSource(this._wavBytes);

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    start ??= 0;
    end ??= _wavBytes.length;
    return StreamAudioResponse(
      sourceLength: _wavBytes.length,
      contentLength: end - start,
      offset: start,
      stream: Stream.value(_wavBytes.sublist(start, end)),
      contentType: 'audio/wav',
    );
  }
}
