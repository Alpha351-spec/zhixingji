import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:just_audio/just_audio.dart';

/// 白噪音生成器 —— 代码合成 WAV 音频流，循环播放
///
/// 使用 [just_audio] 的 [StreamAudioSource] 将内存中生成的 WAV 字节流
/// 作为音频源播放。白噪音是循环信号，生成数秒样本循环播放即可，
/// 无需依赖任何外部音频文件。
///
/// 五种声音（禅意氛围设计）：
/// - white    纯白噪音：全频段均匀，柔和包裹，屏蔽外界
/// - rain     雨声：绵密细雨 + 偶尔屋檐滴水，清净沉浸
/// - forest   森林：风过树梢 + 远处溪流 + 偶尔鸟鸣，空灵自然
/// - cafe     咖啡馆：人声嗡嗡 + 杯碟轻碰 + 机器底噪，温暖人间
/// - campfire 篝火：木柴噼啪 + 火焰呼呼，温暖安定
class WhiteNoiseGenerator {
  // ============ 音频参数 ============
  static const int sampleRate = 44100;
  static const int numChannels = 1;
  static const int bitsPerSample = 16;
  static const int loopSeconds = 8; // 8 秒循环，减少循环感

  // ============ 音量控制 ============
  /// 默认音量（最大音量的 45%）
  static const double defaultVolume = 0.45;

  // ============ 平滑启停参数 ============
  static const Duration fadeInDuration = Duration(seconds: 1);
  static const Duration fadeOutDuration = Duration(seconds: 2);
  static const int _fadeSteps = 50;
  static const Duration _fadeInterval = Duration(milliseconds: 40);

  // 中文类型名 → 英文 key
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
  bool _isStopping = false;
  String _currentType = 'white';
  Timer? _fadeTimer;

  bool get isPlaying => _isPlaying;
  String get currentType => _currentType;

  /// 开始播放指定类型的声音
  ///
  /// [type] 可传英文 key（white/rain/forest/cafe/campfire）或中文名。
  /// 开始时音量从零渐强（约 1 秒）到默认音量。
  Future<void> start(String type) async {
    final t = cnToEn[type] ?? type;
    if (_isPlaying && _currentType == t) return;

    // 取消正在进行的淡出
    _fadeTimer?.cancel();
    _isStopping = false;

    _currentType = t;
    final wavBytes = _generateWav(t);

    // 从音量 0 开始，避免突兀
    await _player.setVolume(0);
    await _player.setAudioSource(
      _WavAudioSource(wavBytes),
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

  // ============ 音量渐变 ============

  /// 1 秒淡入：从 0 渐强到 defaultVolume
  void _fadeIn() {
    var step = 0;
    _fadeTimer = Timer.periodic(_fadeInterval, (timer) {
      step++;
      if (_isStopping || !_isPlaying) {
        timer.cancel();
        return;
      }
      final vol = defaultVolume * (step / _fadeSteps);
      _player.setVolume(vol.clamp(0.0, defaultVolume));
      if (step >= _fadeSteps) {
        _player.setVolume(defaultVolume);
        timer.cancel();
      }
    });
  }

  /// 2 秒淡出：从当前音量渐弱到 0，然后停止
  void _fadeOut() {
    const startVol = defaultVolume;
    var step = 0;
    const totalSteps = _fadeSteps * 2; // 2 秒 = 100 步
    _fadeTimer = Timer.periodic(_fadeInterval, (timer) {
      step++;
      final vol = startVol * (1 - step / totalSteps);
      _player.setVolume(vol > 0 ? vol : 0);
      if (step >= totalSteps) {
        _player.stop();
        _isPlaying = false;
        _isStopping = false;
        timer.cancel();
      }
    });
  }

  // ============ WAV 生成 ============

  /// 生成指定类型的完整 WAV 文件字节流
  Uint8List _generateWav(String type) {
    const numSamples = sampleRate * loopSeconds;
    final dataSize = numSamples * numChannels * (bitsPerSample ~/ 8);
    final fileSize = 36 + dataSize;

    final bytes = ByteData(44 + dataSize);
    _writeWavHeader(bytes, dataSize, fileSize);

    // 用专用生成器生成采样数据
    final gen = _SoundGenerator(type, sampleRate, loopSeconds, _rng);
    final samples = gen.generate();

    // 写入 PCM 数据
    for (var i = 0; i < numSamples; i++) {
      final int16 = (samples[i] * 32767).round().clamp(-32768, 32767);
      bytes.setInt16(44 + i * 2, int16, Endian.little);
    }

    return bytes.buffer.asUint8List();
  }

  void _writeWavHeader(ByteData bytes, int dataSize, int fileSize) {
    // RIFF header
    bytes.setUint8(0, 0x52); // 'R'
    bytes.setUint8(1, 0x49); // 'I'
    bytes.setUint8(2, 0x46); // 'F'
    bytes.setUint8(3, 0x46); // 'F'
    bytes.setUint32(4, fileSize, Endian.little);
    bytes.setUint8(8, 0x57); // 'W'
    bytes.setUint8(9, 0x41); // 'A'
    bytes.setUint8(10, 0x56); // 'V'
    bytes.setUint8(11, 0x45); // 'E'

    // fmt subchunk
    bytes.setUint8(12, 0x66); // 'f'
    bytes.setUint8(13, 0x6D); // 'm'
    bytes.setUint8(14, 0x74); // 't'
    bytes.setUint8(15, 0x20); // ' '
    bytes.setUint32(16, 16, Endian.little);
    bytes.setUint16(20, 1, Endian.little); // PCM
    bytes.setUint16(22, numChannels, Endian.little);
    bytes.setUint32(24, sampleRate, Endian.little);
    bytes.setUint32(28, sampleRate * numChannels * bitsPerSample ~/ 8, Endian.little);
    bytes.setUint16(32, numChannels * bitsPerSample ~/ 8, Endian.little);
    bytes.setUint16(34, bitsPerSample, Endian.little);

    // data subchunk
    bytes.setUint8(36, 0x64); // 'd'
    bytes.setUint8(37, 0x61); // 'a'
    bytes.setUint8(38, 0x74); // 't'
    bytes.setUint8(39, 0x61); // 'a'
    bytes.setUint32(40, dataSize, Endian.little);
  }
}

/// 声音生成器 —— 封装各类型声音的合成算法
///
/// 每种声音都经过精心调校，追求禅意氛围：
/// - 音量适中（幅度 0.2-0.3，配合 player 音量 45%）
/// - 层次丰富（多层叠加，有主体有点缀）
/// - 自然有机（随机事件 + 缓慢起伏）
class _SoundGenerator {
  final String type;
  final int sampleRate;
  final int durationSeconds;
  final Random rng;

  // 滤波器状态（多个独立通道）
  double _lp1 = 0; // 低通 1（主体）
  double _lp2 = 0; // 低通 2（更深）
  double _lp3 = 0; // 低通 3（背景）
  double _hp1 = 0; // 高通

  // 振荡器相位
  double _phase1 = 0;
  double _phase2 = 0;
  double _phase3 = 0;
  double _lfoPhase = 0; // 低频振荡器（缓慢起伏）

  // 随机事件调度
  int _nextEventSample = 0;
  bool _inEvent = false;
  int _eventStart = 0;
  int _eventDuration = 0;
  double _eventFreq = 0;
  double _eventAmp = 0;

  _SoundGenerator(this.type, this.sampleRate, this.durationSeconds, this.rng);

  /// 生成全部采样数据，并处理循环点无缝衔接
  Float64List generate() {
    final numSamples = sampleRate * durationSeconds;
    final samples = Float64List(numSamples);

    // 预热滤波器（0.5 秒，不记录），让滤波器进入稳态
    // 预热阶段不触发随机事件（_inEvent 保持 false，_nextEventSample 设为很大）
    final warmup = sampleRate ~/ 2;
    _nextEventSample = 1 << 30; // 预热期间不触发事件
    for (var i = 0; i < warmup; i++) {
      _genSample();
    }

    // 重置计数器，初始化第一个事件时间
    _sampleCounter = 0;
    _nextEventSample = _randomEventTime();

    // 生成实际样本
    for (var i = 0; i < numSamples; i++) {
      samples[i] = _genSample();
    }

    // 循环点交叉淡入淡出，确保无缝循环
    _crossfadeLoopPoint(samples);

    return samples;
  }

  /// 生成下一个随机事件的时间间隔（样本数）
  int _randomEventTime() {
    switch (type) {
      case 'rain':
        // 滴水：0.8-3 秒
        return sampleRate * 4 ~/ 5 + rng.nextInt(sampleRate * 11 ~/ 5);
      case 'forest':
        // 鸟鸣：2-6 秒
        return sampleRate * 2 + rng.nextInt(sampleRate * 4);
      case 'cafe':
        // 杯碟：3-10 秒
        return sampleRate * 3 + rng.nextInt(sampleRate * 7);
      case 'campfire':
        // 噼啪：0.1-0.8 秒
        return sampleRate ~/ 10 + rng.nextInt(sampleRate * 7 ~/ 10);
      default:
        return sampleRate * durationSeconds; // 无事件
    }
  }

  /// 根据类型生成单个采样值（[-1.0, 1.0]）
  double _genSample() {
    switch (type) {
      case 'white':
        return _genWhite();
      case 'rain':
        return _genRain();
      case 'forest':
        return _genForest();
      case 'cafe':
        return _genCafe();
      case 'campfire':
        return _genCampfire();
      default:
        return _genWhite();
    }
  }

  // ============ 纯白噪音 ============
  // 全频段均匀分布，轻微低通使其更柔和，像被柔软空气包裹
  double _genWhite() {
    final noise = rng.nextDouble() * 2 - 1;
    // 轻微低通（alpha=0.3），去掉刺耳的高频尖峰
    _lp1 = _lp1 * 0.7 + noise * 0.3;
    return _lp1 * 0.22;
  }

  // ============ 雨声 ============
  // 主体：绵密细雨（低通白噪，沙沙声）
  // 高频：轻微嘶嘶（高通残余）
  // 点缀：偶尔屋檐滴水（低频衰减脉冲）
  double _genRain() {
    final noise = rng.nextDouble() * 2 - 1;

    // 主体：低通滤波，模拟绵密细雨的沙沙声
    _lp1 = _lp1 * 0.92 + noise * 0.08; // 截止约 2kHz
    var s = _lp1 * 0.30;

    // 高频嘶嘶：高通残余，像无数细针落布面
    final hp = noise - _lp1;
    _hp1 = _hp1 * 0.85 + hp * 0.15;
    s += _hp1 * 0.06;

    // 偶尔屋檐滴水：低频衰减正弦脉冲
    _processEvent();
    if (_inEvent) {
      final elapsed = _currentSample() - _eventStart;
      if (elapsed < _eventDuration) {
        // 指数衰减包络
        final env = exp(-elapsed / _eventDuration * 4);
        _phase1 += 2 * pi * _eventFreq / sampleRate;
        s += sin(_phase1) * env * _eventAmp;
      } else {
        _inEvent = false;
        _phase1 = 0;
        _nextEventSample = _currentSample() + _randomEventTime();
      }
    }

    return s;
  }

  // ============ 森林 ============
  // 底层：风吹树叶沙沙声（极低通 + LFO 起伏）
  // 中层：远处溪流潺潺（带通噪声）
  // 点缀：偶尔鸟鸣（频率渐变正弦波，山谷回荡感）
  double _genForest() {
    final noise = rng.nextDouble() * 2 - 1;

    // 底层风声：极低通 + LFO 缓慢起伏
    _lp3 = _lp3 * 0.97 + noise * 0.03;
    _lfoPhase += 2 * pi * 0.08 / sampleRate; // 0.08Hz LFO
    final lfo = (sin(_lfoPhase) * 0.5 + 0.5);
    var s = _lp3 * 0.20 * (0.6 + lfo * 0.4);

    // 中层溪流：中频带通噪声
    _lp2 = _lp2 * 0.88 + noise * 0.12; // 截止约 3kHz
    final bandpass = _lp2 - _lp3; // 减去低频得到中频
    s += bandpass * 0.08;

    // 偶尔鸟鸣：清脆短促，频率渐变
    _processEvent();
    if (_inEvent) {
      final elapsed = _currentSample() - _eventStart;
      if (elapsed < _eventDuration) {
        // 鸟鸣包络：快速上升 + 缓慢下降
        final t = elapsed / _eventDuration;
        final env = t < 0.1 ? t * 10 : exp(-(t - 0.1) * 4);
        // 频率从 _eventFreq 渐变到 _eventFreq * 1.3
        final freq = _eventFreq * (1 + t * 0.3);
        _phase1 += 2 * pi * freq / sampleRate;
        s += sin(_phase1) * env * _eventAmp;
      } else {
        _inEvent = false;
        _phase1 = 0;
        _nextEventSample = _currentSample() + _randomEventTime();
      }
    }

    return s;
  }

  // ============ 咖啡馆 ============
  // 低频：模糊人声嗡嗡（多正弦波叠加 + 随机幅度调制）
  // 底噪：机器运转（极低通噪声）
  // 点缀：偶尔杯碟轻碰（短促高频脉冲）
  double _genCafe() {
    final noise = rng.nextDouble() * 2 - 1;

    // 底噪：机器运转，极低通
    _lp3 = _lp3 * 0.98 + noise * 0.02;
    var s = _lp3 * 0.12;

    // 人声嗡嗡：3 个低频正弦波 + 随机幅度调制
    _phase1 += 2 * pi * 120 / sampleRate; // 120Hz
    _phase2 += 2 * pi * 180 / sampleRate; // 180Hz
    _phase3 += 2 * pi * 240 / sampleRate; // 240Hz
    final mod1 = (rng.nextDouble() * 0.6 + 0.4);
    final mod2 = (rng.nextDouble() * 0.6 + 0.4);
    final mod3 = (rng.nextDouble() * 0.6 + 0.4);
    s += (sin(_phase1) * 0.04 * mod1 +
        sin(_phase2) * 0.035 * mod2 +
        sin(_phase3) * 0.03 * mod3);

    // 偶尔杯碟轻碰：短促高频脉冲
    _processEvent();
    if (_inEvent) {
      final elapsed = _currentSample() - _eventStart;
      if (elapsed < _eventDuration) {
        // 快速衰减
        final env = exp(-elapsed / _eventDuration * 6);
        _phase1 += 2 * pi * _eventFreq / sampleRate;
        // 加入噪声让声音更真实
        s += (sin(_phase1) + noise * 0.5) * env * _eventAmp;
      } else {
        _inEvent = false;
        _phase1 = 0;
        _nextEventSample = _currentSample() + _randomEventTime();
      }
    }

    return s;
  }

  // ============ 篝火 ============
  // 背景：火焰呼呼声（低通噪声 + LFO 起伏）
  // 主体：木柴噼啪（随机高频脉冲，强弱不一）
  double _genCampfire() {
    final noise = rng.nextDouble() * 2 - 1;

    // 背景火焰呼呼：低通 + 缓慢起伏
    _lp3 = _lp3 * 0.96 + noise * 0.04;
    _lfoPhase += 2 * pi * 0.12 / sampleRate; // 0.12Hz LFO
    final lfo = (sin(_lfoPhase) * 0.5 + 0.5);
    var s = _lp3 * 0.22 * (0.5 + lfo * 0.5);

    // 噼啪声：随机触发，指数衰减脉冲
    _processEvent();
    if (_inEvent) {
      final elapsed = _currentSample() - _eventStart;
      if (elapsed < _eventDuration) {
        // 快速衰减，模拟木柴爆裂
        final env = exp(-elapsed / _eventDuration * 5);
        _phase1 += 2 * pi * _eventFreq / sampleRate;
        s += (sin(_phase1) * 0.6 + noise * 0.4) * env * _eventAmp;
      } else {
        _inEvent = false;
        _phase1 = 0;
        _nextEventSample = _currentSample() + _randomEventTime();
      }
    }

    return s;
  }

  // ============ 事件处理辅助 ============

  int _sampleCounter = 0;

  int _currentSample() => _sampleCounter;

  /// 检查是否触发随机事件，并设置事件参数
  void _processEvent() {
    _sampleCounter++;
    if (!_inEvent && _sampleCounter >= _nextEventSample) {
      _inEvent = true;
      _eventStart = _sampleCounter;
      _setEventParams();
    }
  }

  /// 根据声音类型设置事件参数
  void _setEventParams() {
    switch (type) {
      case 'rain':
        // 屋檐滴水：低频，50ms，中等音量
        _eventDuration = sampleRate ~/ 20;
        _eventFreq = 80 + rng.nextDouble() * 60; // 80-140Hz
        _eventAmp = 0.12;
        break;
      case 'forest':
        // 鸟鸣：中高频，100-200ms，清脆
        _eventDuration = sampleRate ~/ 8 + rng.nextInt(sampleRate ~/ 6);
        _eventFreq = 1500 + rng.nextDouble() * 1200; // 1.5-2.7kHz
        _eventAmp = 0.14;
        break;
      case 'cafe':
        // 杯碟：高频，30-60ms，清脆不刺耳
        _eventDuration = sampleRate ~/ 25 + rng.nextInt(sampleRate ~/ 30);
        _eventFreq = 2500 + rng.nextDouble() * 1500; // 2.5-4kHz
        _eventAmp = 0.08;
        break;
      case 'campfire':
        // 噼啪：高频，20-80ms，随机强弱
        _eventDuration = sampleRate ~/ 30 + rng.nextInt(sampleRate ~/ 15);
        _eventFreq = 800 + rng.nextDouble() * 2000; // 0.8-2.8kHz
        _eventAmp = 0.08 + rng.nextDouble() * 0.18; // 0.08-0.26 随机强弱
        break;
    }
  }

  // ============ 循环点无缝处理 ============

  /// 在样本末尾做交叉淡入淡出，使循环点不可感知
  ///
  /// 将最后 [fadeLen] 个样本与开头的 [fadeLen] 个样本交叉混合：
  /// 结尾逐渐过渡到开头的内容，这样循环回到 0 时声音连续。
  void _crossfadeLoopPoint(Float64List samples) {
    final fadeLen = sampleRate ~/ 10; // 100ms 交叉淡入淡出
    final n = samples.length;

    // 保存开头样本的副本
    final begin = Float64List.fromList(
      samples.sublist(0, fadeLen),
    );

    // 结尾交叉淡入淡出到开头
    for (var i = 0; i < fadeLen; i++) {
      final t = i / fadeLen;
      final idx = n - fadeLen + i;
      samples[idx] = samples[idx] * (1 - t) + begin[i] * t;
    }
  }
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
