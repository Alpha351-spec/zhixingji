/// 消息过滤器
///
/// 用于在用户消息发送给 AI 之前进行拦截：
/// 1. 敏感词检测（政治、色情、暴力、赌博、辱骂等）
/// 2. 无意义消息检测（纯标点、单字、重复字符、乱码等）
class MessageFilter {
  MessageFilter._();

  /// 检测结果
  static const _ok = FilterResult(passed: true);

  /// 过滤消息，返回检测结果
  static FilterResult check(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return const FilterResult(
        passed: false,
        reason: '消息不能为空',
      );
    }

    // 1. 无意义消息检测
    final meaningless = _checkMeaningless(trimmed);
    if (meaningless != null) return meaningless;

    // 2. 敏感词检测
    final sensitive = _checkSensitive(trimmed);
    if (sensitive != null) return sensitive;

    return _ok;
  }

  // ============ 无意义消息检测 ============

  static FilterResult? _checkMeaningless(String text) {
    // 去除所有空格和标点后的纯文本
    final cleanText = text.replaceAll(
      RegExp(r'[\s\p{P}\p{S}]+', unicode: true),
      '',
    );

    // 纯标点/符号，无实际文字
    if (cleanText.isEmpty) {
      return const FilterResult(
        passed: false,
        reason: '请输入有效的内容，不要只发标点符号哦',
      );
    }

    // 有效文字过短（只有1个字）
    if (cleanText.length == 1) {
      // 允许单个中文字（如"好"、"是"、"对"）
      final singleChar = cleanText;
      if (_validSingleChars.contains(singleChar)) {
        return null; // 通过
      }
      return FilterResult(
        passed: false,
        reason: '「$singleChar」太简短了，能多说一点吗？',
      );
    }

    // 纯数字（且不是日期格式）
    if (RegExp(r'^\d+$').hasMatch(cleanText)) {
      // 允许日期格式如 2026-08-15
      if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(text.trim())) {
        return null;
      }
      return const FilterResult(
        passed: false,
        reason: '请输入具体的需求，而不是纯数字',
      );
    }

    // 重复字符（如"啊啊啊啊啊"、"哈哈哈哈哈"、"。。。。。。"）
    if (cleanText.length >= 3) {
      final firstChar = cleanText[0];
      var allSame = true;
      for (var i = 1; i < cleanText.length; i++) {
        if (cleanText[i] != firstChar) {
          allSame = false;
          break;
        }
      }
      if (allSame) {
        return FilterResult(
          passed: false,
          reason: '不要发送重复内容哦，请输入有意义的内容',
        );
      }
    }

    // 连续相同字符占比过高（如"哈哈哈哈学习"）
    final charCount = <String, int>{};
    for (final char in cleanText.split('')) {
      charCount[char] = (charCount[char] ?? 0) + 1;
    }
    final maxCount = charCount.values.fold(0, (a, b) => a > b ? a : b);
    if (cleanText.length >= 4 && maxCount / cleanText.length > 0.6) {
      return const FilterResult(
        passed: false,
        reason: '消息中重复内容太多，请输入有意义的内容',
      );
    }

    // 纯英文单字母组合（如"asdf"、"qwer"键盘乱敲）
    if (RegExp(r'^[a-zA-Z]+$').hasMatch(cleanText) &&
        cleanText.length <= 6 &&
        _isKeyboardMash(cleanText)) {
      return const FilterResult(
        passed: false,
        reason: '请输入有意义的内容，不要随机输入字符',
      );
    }

    return null; // 通过
  }

  /// 检测是否为键盘乱敲（连续键盘上的相邻按键）
  static bool _isKeyboardMash(String text) {
    const keyboardRows = [
      'qwertyuiop',
      'asdfghjkl',
      'zxcvbnm',
    ];
    final lower = text.toLowerCase();

    for (final row in keyboardRows) {
      // 检查是否大部分字符在同一行连续
      var consecutive = 0;
      for (var i = 0; i < lower.length - 1; i++) {
        final idx1 = row.indexOf(lower[i]);
        final idx2 = row.indexOf(lower[i + 1]);
        if (idx1 >= 0 && idx2 >= 0 && (idx1 - idx2).abs() <= 1) {
          consecutive++;
        }
      }
      if (consecutive >= lower.length - 2 && lower.length >= 3) {
        return true;
      }
    }
    return false;
  }

  // ============ 敏感词检测 ============

  static FilterResult? _checkSensitive(String text) {
    final lower = text.toLowerCase();

    for (final word in _sensitiveWords) {
      if (text.contains(word) || lower.contains(word)) {
        return FilterResult(
          passed: false,
          reason: '检测到敏感内容，请保持文明交流，专注于你的目标话题',
        );
      }
    }

    return null; // 通过
  }

  /// 允许的单字回复
  static const _validSingleChars = {
    '好', '是', '对', '嗯', '行', '可以', '没',
  };

  /// 敏感词库
  ///
  /// 精简版，覆盖常见类别：
  /// - 辱骂
  /// - 色情
  /// - 暴力/毒品
  /// - 赌博
  /// - 政治敏感
  static const _sensitiveWords = <String>{
    // 辱骂
    '傻逼', '操你', '草你', '你妈', '滚蛋', '废物', '贱人', '婊子',
    '王八蛋', '混蛋', '去死', '找死', '畜生', '狗屎', '放屁',
    'fuck', 'shit', 'bitch', 'damn', 'asshole', 'dick',

    // 色情
    '色情', '黄色', '裸体', '裸照', '性交', '做爱', ' AV', 'av片',
    'porn', 'nude', 'sex',

    // 暴力/毒品
    '杀人', '自杀', '跳楼', '上吊', '割腕', '吸毒', '贩毒',
    '大麻', '海洛因', '冰毒', '可卡因',
    '炸弹', '爆炸物', '枪支',

    // 赌博
    '赌博', '赌场', '下注', '博彩', '外围彩',

    // 政治敏感（精简）
    '法轮功', '六四', '天安门事件', '台独', '藏独', '疆独',
  };
}

/// 过滤结果
class FilterResult {
  final bool passed;
  final String? reason;

  const FilterResult({
    required this.passed,
    this.reason,
  });
}
