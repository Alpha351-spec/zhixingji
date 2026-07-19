import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/constants/app_constants.dart';
import '../models/task.dart';

/// DeepSeek AI 服务（开发文档第6节）
///
/// 支持联网搜索（通过 Function Calling + DuckDuckGo Instant Answer API）
/// 滚动7天计划模式：初始对话只生成7天任务，完成后通过 renewPlan() 续订
///
/// 联网搜索策略：
/// - 仅在第1轮允许 AI 调用 search_web 工具
/// - 第2轮起强制 tool_choice='none'，AI 必须基于已有信息生成回复
/// - 搜索失败时（如网络不通），AI 仍可基于自身知识生成计划
class AIService {
  AIService._();

  /// 联网搜索工具定义（Function Calling）
  static const List<Map<String, dynamic>> _searchTools = [
    {
      'type': 'function',
      'function': {
        'name': 'search_web',
        'description': '搜索互联网获取最新的资源、教程、文档等信息。当需要推荐具体资源或查找最新信息时调用此工具。注意：最多调用一次。',
        'parameters': {
          'type': 'object',
          'properties': {
            'query': {
              'type': 'string',
              'description': '搜索关键词，如"Python入门教程"或"数据结构学习路线"',
            },
          },
          'required': ['query'],
        },
      },
    },
  ];

  /// 初始对话系统提示词（只生成7天任务）
  static const String _systemPromptBase = '''
你是一个专业的规划助手「学径」。你的任务是通过自然对话了解用户的目标、当前水平、时间安排和截止日期，然后生成一份7天的行动计划。用户的目标不限于学习，也可能是减肥、健身、考试备考、技能训练等任何需要规划的领域。

你可以使用 search_web 工具搜索互联网，获取最新的资源、教程推荐等信息，以便为用户提供更精准的资源关键词。但搜索工具最多调用一次，如果搜索未返回结果，请直接基于你的专业知识生成计划。

## 对话流程规则

1. 你每次只问一个问题。除基础信息外，你必须根据用户的目标领域，主动识别并收集该领域特有的、会直接影响计划制定的关键数据。例如：
   - 减肥/健身类：当前体重、目标体重、身高、饮食限制、运动基础
   - 考试/认证类：考试日期、当前分数/水平、目标分数
   - 编程/技能类：具体想做的项目类型、目前能独立完成什么
   如果用户回答模糊，必须追问一个确认问题，直到获得足够具体的数据。
2. 需要收集的基础信息：目标、当前基础水平、每天可投入时间、偏好方式、有无截止日期。
3. 总对话轮次可灵活掌握，关键信息收集全为止，但通常不超过10轮。
4. 当你认为信息足够，告诉用户"我已经了解你的情况，现在为你生成专属计划"，然后立即输出JSON。

## 截止日期快捷选项处理

用户会通过快捷选项回答截止日期问题：
- 如果用户回复一个日期（格式如 2026-08-15），说明有截止日期，你需要计算从今天到截止日期的剩余天数
- 如果用户回复"没有，长期学习"或类似表述，说明无截止日期，用户会另外选择 14/30/60/90/120 天的周期

## 联网搜索

在生成计划前，可以使用 search_web 工具搜索一次相关的资源。如果搜索失败或无结果，直接基于你的专业知识生成计划。

## 重要：只生成7天任务

无论用户的总周期多长，你只生成前7天的任务（day 1-7）。在生成计划后，告知用户："这是第一周的任务，完成本周后可以续订下一周的计划。"

## 输出规则

在收集到足够信息后，你需要：
1. 先用一两句话总结你对用户的理解，并告知用户这是第一周的任务，后续可续订
2. 然后输出包含 diagnosis 和 plan 的 JSON

JSON 必须放在 ```json 代码块中，格式如下：

```json
{
  "diagnosis": {
    "current_level": "用户当前水平评估",
    "learning_style": "推荐的方式",
    "weak_areas": "薄弱环节",
    "recommended_approach": "建议方法",
    "deadline": "截止日期，格式 YYYY-MM-DD，无截止日期时为空字符串",
    "total_days": "计划总天数（整数）"
  },
  "plan": {
    "goal": "目标",
    "tasks": [
      {
        "day": 1,
        "title": "任务标题",
        "description": "任务详细描述",
        "resource_keywords": "资源搜索关键词",
        "encouragement": "鼓励语",
        "completed": 0,
        "focus_minutes": 0,
        "verification_type": "quiz"
      }
    ]
  }
}
```

## 注意事项
- 在未收集到足够信息前，只进行自然对话，不要输出 JSON
- tasks 必须恰好7个，day 字段为 1-7
- 如果有截止日期，total_days = 从今天到截止日期的天数
- 如果无截止日期，total_days = 用户选择的周期（14/30/60/90/120）
- 鼓励语要简短有温度
- 资源关键词用空格分隔
- 每个任务需标记 verification_type：理论学习/概念理解类用 "quiz"，实践/反思类用 "reflection"，运动/习惯养成类用 "none"
- verification_type 取值只能是 "quiz"、"reflection" 或 "none" 三者之一
- 只输出一次 JSON，不要重复输出
''';

  /// 续订系统提示词
  static const String renewSystemPrompt = '''
你是规划助手「学径」。用户已完成本周的任务，需要生成下一周的7天计划。

你可以使用 search_web 工具搜索互联网，获取最新的资源信息。但搜索工具最多调用一次，如果搜索未返回结果，请直接基于你的专业知识生成计划。

根据用户的原始诊断信息、当前周数、本周完成情况和用户反馈，生成新的7天任务。

## 输出规则
1. 先用一句话鼓励用户继续坚持
2. 输出包含 plan 的 JSON

JSON 格式：
```json
{
  "plan": {
    "goal": "目标",
    "tasks": [
      {
        "day": 1,
        "title": "任务标题",
        "description": "任务详细描述",
        "resource_keywords": "资源搜索关键词",
        "encouragement": "鼓励语",
        "completed": 0,
        "focus_minutes": 0,
        "verification_type": "quiz"
      }
    ]
  }
}
```

## 注意事项
- tasks 必须恰好7个，day 字段为 1-7
- 新任务应延续上周的进度，不要重复已完成的内容
- 如果用户反馈"太难了"，适当降低难度；如果"太简单"，适当提升
- 每个任务需标记 verification_type：理论学习/概念理解类用 "quiz"，实践/反思类用 "reflection"，运动/习惯养成类用 "none"
- 鼓励语要简短有温度
''';

  /// 获取今天的日期字符串
  static String get _todayStr {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  /// 清理 AI 回复中的特殊 token 和标记
  ///
  /// DeepSeek 等模型可能在回复中泄漏内部 token，如：
  /// - <|begin▁of▁sentence|>、<|end▁of▁sentence|>（以 |>| 结尾）
  /// - <| | DSML | | tool_calls>...</| | DSML | | tool_calls>（DSML 工具调用块）
  /// - <｜tool▁calls▁begin｜> 等全角竖线格式
  /// 这些标记对用户无意义，需要过滤
  static String _cleanResponse(String text) {
    var cleaned = text;

    // 1. 移除完整的 DSML tool_calls 块（从开标签到闭标签，包含中间所有内容）
    //    格式：<| | DSML | | tool_calls> ... </| | DSML | | tool_calls>
    cleaned = cleaned.replaceAll(
      RegExp(r'<\|[^>]*tool_calls>[\s\S]*?</\|[^>]*tool_calls>'),
      '',
    );

    // 2. 移除所有剩余的 <|...> 和 </|...> 格式标签（半角竖线）
    //    匹配 <|begin▁of▁sentence|>、<| | DSML | | invoke>、</| | DSML | | invoke> 等
    cleaned = cleaned.replaceAll(RegExp(r'<\/?\|[^>]*>'), '');

    // 3. 移除 <｜...｜> 和 </｜...｜> 格式的 token（全角竖线）
    cleaned = cleaned.replaceAll(RegExp(r'<\/?｜[^>]*>'), '');

    // 4. 清理多余的空行（特殊 token 过滤后可能留下）
    cleaned = cleaned.replaceAll(RegExp(r'\n{3,}'), '\n\n');

    // 5. 清理行首行尾的空白行
    cleaned = cleaned.replaceAll(RegExp(r'^\s*\n'), '');
    cleaned = cleaned.replaceAll(RegExp(r'\n\s*$'), '');

    return cleaned.trim();
  }

  // ============ 打卡验证 ============

  /// 生成验证题目（quiz 类型）
  ///
  /// 根据任务标题和描述生成 2 道单选题。
  /// 返回 JSON 字符串：{ "questions": [{ "question": "...", "options": [...], "correct_index": 0 }] }
  static Future<String> generateQuiz(Task task) async {
    final prompt = '请根据以下学习任务的核心知识点生成 2 道单选题用于打卡验证。\n\n'
        '【任务标题】${task.title}\n'
        '【任务描述】${task.description}\n\n'
        '【出题要求】\n'
        '- 题目必须针对本任务描述中的具体知识点，不能出通用题\n'
        '- 每题 4 个选项，只有 1 个正确答案\n'
        '- 正确选项必须是任务描述中明确涉及的内容\n'
        '- 错误选项应是合理的干扰项，不能太离谱\n'
        '- 难度适中，但必须真正考察对任务内容的理解\n'
        '- 题目和选项中应包含任务相关的专业术语\n\n'
        '【输出格式】只输出以下 JSON，不要其他文字：\n'
        '```json\n'
        '{\n'
        '  "questions": [\n'
        '    {\n'
        '      "question": "针对任务知识点的题目",\n'
        '      "options": ["选项A", "选项B", "选项C", "选项D"],\n'
        '      "correct_index": 0\n'
        '    }\n'
        '  ]\n'
        '}\n'
        '```';

    final response = await _callAiForVerification(prompt);
    return response;
  }

  /// 评判答题结果（quiz 类型）
  ///
  /// 返回 JSON 字符串：{ "passed": true/false, "score": 80, "feedback": "..." }
  static Future<String> evaluateQuiz(
    Task task,
    String questionsJson,
    List<int> userAnswers,
  ) async {
    final prompt = '请评判用户的答题结果。\n'
        '任务标题：${task.title}\n'
        '题目和用户答案：\n'
        '$questionsJson\n\n'
        '用户依次选择的选项索引：$userAnswers\n\n'
        '评判规则（宽松把关）：\n'
        '- 2 题答对 1 题即通过（60%通过率）\n'
        '- 反馈语气鼓励性，先肯定尝试再指出不足\n'
        '- 只输出 JSON，不要其他文字\n\n'
        'JSON 格式：\n'
        '```json\n'
        '{\n'
        '  "passed": true,\n'
        '  "score": 80,\n'
        '  "feedback": "鼓励性反馈"\n'
        '}\n'
        '```';

    final response = await _callAiForVerification(prompt);
    return response;
  }

  /// 评判反思文字（reflection 类型）
  ///
  /// 返回 JSON 字符串：{ "passed": true/false, "score": 80, "feedback": "...", "suggestion": "..." }
  static Future<String> evaluateReflection(Task task, String userReflection) async {
    final prompt = '请评判用户的学习反思是否真正涉及本任务的核心内容。\n\n'
        '【任务标题】${task.title}\n'
        '【任务描述】${task.description}\n\n'
        '【用户反思】\n$userReflection\n\n'
        '【评判标准】\n'
        '1. 相关性（必须）：反思必须明确提及任务中的具体知识点、概念、方法或关键术语。泛泛而谈（如"学到了很多"、"很有收获"）不算相关。\n'
        '2. 实质性（必须）：反思必须包含至少一个具体要点，例如：\n'
        '   - 对某个概念的理解或解释\n'
        '   - 某个方法/技巧的运用或体会\n'
        '   - 遇到的具体问题及思考\n'
        '   - 与已有知识的联系或对比\n'
        '3. 字数：反思必须 ≥ 30 字\n\n'
        '【不通过的情况】\n'
        '- 空白、纯标点、不足 30 字\n'
        '- 仅复述任务标题或描述，无个人思考\n'
        '- 泛泛而谈，未提及任务中的任何具体知识点\n'
        '- 与任务主题完全无关\n'
        '- 敷衍重复（如同一句话重复多次）\n\n'
        '【评判要求】\n'
        '- 你必须先在 feedback 中指出用户反思中提到的具体知识点（如果有），再给出是否通过的判断\n'
        '- 如果反思没有提及任务相关的知识点，必须判为不通过\n'
        '- 同一段反思用于不同任务时，只能通过与其内容真正相关的任务\n\n'
        '【输出格式】只输出以下 JSON，不要其他文字：\n'
        '```json\n'
        '{\n'
        '  "passed": true,\n'
        '  "score": 80,\n'
        '  "relevance": "相关/不相关",\n'
        '  "matched_points": ["用户反思中匹配到的知识点1", "知识点2"],\n'
        '  "feedback": "先指出匹配的知识点，再给鼓励性反馈",\n'
        '  "suggestion": "具体的改进建议"\n'
        '}\n'
        '```';

    final response = await _callAiForVerification(prompt);
    return response;
  }

  /// 验证场景的 AI 调用（不使用工具，单轮对话）
  static Future<String> _callAiForVerification(String prompt) async {
    final requestBody = <String, dynamic>{
      'model': AppConstants.model,
      'messages': [
        {'role': 'system', 'content': '你是学径App的验证助手。请严格按照要求的JSON格式输出，不要输出其他内容。'},
        {'role': 'user', 'content': prompt},
      ],
      'temperature': 0.3,
      'max_tokens': 1500,
      'tool_choice': 'none',
    };

    final response = await http
        .post(
          Uri.parse(AppConstants.apiEndpoint),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${AppConstants.apiKey}',
          },
          body: jsonEncode(requestBody),
        )
        .timeout(const Duration(seconds: 60));

    if (response.statusCode != 200) {
      final errorBody = jsonDecode(response.body);
      final errorMsg = errorBody['error']?['message'] ?? response.body;
      throw Exception('AI验证请求失败(${response.statusCode}): $errorMsg');
    }

    final data = jsonDecode(response.body);
    final content = data['choices'][0]['message']['content'] as String? ?? '';
    return _cleanResponse(content);
  }

  /// 执行联网搜索
  ///
  /// 优先使用必应中国（国内可直连），DuckDuckGo 作为备选（需翻墙）
  /// 返回搜索结果摘要文本，失败返回空字符串
  static Future<String> _executeWebSearch(String query) async {
    // 1. 优先必应中国（国内可访问）
    final bingResult = await _searchBing(query);
    if (bingResult.isNotEmpty) return bingResult;

    // 2. 备选 DuckDuckGo（需翻墙，作为 fallback）
    final ddgResult = await _searchDuckDuckGo(query);
    if (ddgResult.isNotEmpty) return ddgResult;

    return '';
  }

  /// 必应中国搜索（抓取 cn.bing.com 搜索结果摘要）
  static Future<String> _searchBing(String query) async {
    try {
      final encodedQuery = Uri.encodeComponent(query);
      final url = Uri.parse(
        'https://cn.bing.com/search?q=$encodedQuery&count=8',
      );

      final response = await http.get(
        url,
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
        },
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) return '';

      final html = response.body;
      final results = <String>[];

      // 必应搜索结果摘要：<p class="b_lineclamp...">文本</p>
      var snippetRegex = RegExp(
        r'<p[^>]*class="[^"]*b_lineclamp[^"]*"[^>]*>([\s\S]*?)</p>',
      );
      var matches = snippetRegex.allMatches(html);

      for (final match in matches.take(5)) {
        final text = _cleanHtmlText(match.group(1) ?? '');
        if (text.isNotEmpty) results.add(text);
      }

      // 备选 pattern：<li class="b_algo"> 中的 <p>
      if (results.isEmpty) {
        snippetRegex = RegExp(
          r'<li[^>]*class="[^"]*b_algo[^"]*"[\s\S]*?<p[^>]*>([\s\S]*?)</p>',
        );
        matches = snippetRegex.allMatches(html);
        for (final match in matches.take(5)) {
          final text = _cleanHtmlText(match.group(1) ?? '');
          if (text.isNotEmpty) results.add(text);
        }
      }

      return results.join('\n');
    } catch (e) {
      return '';
    }
  }

  /// 清理 HTML 标签和实体，提取纯文本
  static String _cleanHtmlText(String html) {
    var text = html;
    // 去除所有 HTML 标签
    text = text.replaceAll(RegExp(r'<[^>]+>'), '');
    // 解码常见 HTML 实体
    text = text
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&nbsp;', ' ');
    return text.trim();
  }

  /// DuckDuckGo Instant Answer API 搜索（备选，需翻墙）
  static Future<String> _searchDuckDuckGo(String query) async {
    try {
      final encodedQuery = Uri.encodeComponent(query);
      final url = Uri.parse(
        'https://api.duckduckgo.com/?q=$encodedQuery&format=json&no_html=1&skip_disambig=1',
      );

      final response = await http.get(url).timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) return '';

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      final results = <String>[];

      final abstractText = data['AbstractText'] as String?;
      if (abstractText != null && abstractText.isNotEmpty) {
        results.add(abstractText);
      }

      final relatedTopics = data['RelatedTopics'] as List?;
      if (relatedTopics != null) {
        for (final topic in relatedTopics.take(5)) {
          if (topic is Map<String, dynamic>) {
            final text = topic['Text'] as String?;
            if (text != null && text.isNotEmpty) {
              results.add(text);
            }
          }
        }
      }

      return results.join('\n');
    } catch (e) {
      return '';
    }
  }

  /// 发送对话请求（支持联网搜索）
  ///
  /// [messages] 为完整对话历史（user/assistant 角色，不含 system）
  /// 返回 AI 回复的文本内容
  ///
  /// 联网搜索策略：仅第1轮允许 tool_calls，之后强制 tool_choice='none'
  static Future<String> chat(List<Map<String, String>> messages) async {
    final promptWithDate =
        '$_systemPromptBase\n\n## 重要：当前日期\n今天是 $_todayStr。计算截止日期剩余天数时请以此为准。';

    // 构建消息列表（类型为 List<Map<String, dynamic>> 以支持 tool_calls）
    final allMessages = <Map<String, dynamic>>[
      {'role': 'system', 'content': promptWithDate},
      ...messages,
    ];

    // 最多循环3次：第1轮允许搜索，后续强制不搜索
    for (var round = 0; round < 3; round++) {
      final allowTools = round == 0;

      final requestBody = <String, dynamic>{
        'model': AppConstants.model,
        'messages': allMessages,
        'temperature': AppConstants.temperature,
        'max_tokens': AppConstants.maxTokens,
      };

      if (allowTools) {
        requestBody['tools'] = _searchTools;
        requestBody['tool_choice'] = 'auto';
      } else {
        // 强制不使用工具，AI 必须直接生成回复
        requestBody['tool_choice'] = 'none';
      }

      final response = await http
          .post(
            Uri.parse(AppConstants.apiEndpoint),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${AppConstants.apiKey}',
            },
            body: jsonEncode(requestBody),
          )
          .timeout(const Duration(seconds: 60));

      if (response.statusCode != 200) {
        final errorBody = jsonDecode(response.body);
        final errorMsg = errorBody['error']?['message'] ?? response.body;
        throw Exception('AI请求失败(${response.statusCode}): $errorMsg');
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final choices = data['choices'] as List;
      if (choices.isEmpty) throw Exception('AI返回为空');

      final message = choices[0]['message'] as Map<String, dynamic>;
      final toolCalls = message['tool_calls'] as List?;

      // 没有 tool_calls，或当前轮不允许工具 → 返回最终内容
      if (toolCalls == null || toolCalls.isEmpty || !allowTools) {
        return _cleanResponse(message['content'] as String? ?? '');
      }

      // 有 tool_calls：执行搜索并将结果返回给 AI
      // 注意：content 可能为 null，转为空字符串
      allMessages.add({
        'role': 'assistant',
        'content': message['content'] ?? '',
        'tool_calls': toolCalls,
      });

      for (final tc in toolCalls) {
        final tcMap = tc as Map<String, dynamic>;
        final function = tcMap['function'] as Map<String, dynamic>;
        final functionName = function['name'] as String;
        final toolCallId = tcMap['id'] as String;

        String searchResult = '';
        if (functionName == 'search_web') {
          try {
            final args = jsonDecode(function['arguments'] as String)
                as Map<String, dynamic>;
            final query = args['query'] as String? ?? '';
            if (query.isNotEmpty) {
              searchResult = await _executeWebSearch(query);
            }
          } catch (_) {
            searchResult = '';
          }
        }

        allMessages.add({
          'role': 'tool',
          'tool_call_id': toolCallId,
          'content': searchResult.isNotEmpty
              ? searchResult
              : '搜索服务暂不可用，请直接基于你的专业知识生成计划，不要再调用搜索工具。',
        });
      }
      // 继续循环，下一轮 tool_choice='none'，AI 必须生成回复
    }

    // 兜底：如果3轮都没拿到内容（极端情况），做最后一次无工具请求
    final fallbackResponse = await http
        .post(
          Uri.parse(AppConstants.apiEndpoint),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${AppConstants.apiKey}',
          },
          body: jsonEncode({
            'model': AppConstants.model,
            'messages': allMessages,
            'temperature': AppConstants.temperature,
            'max_tokens': AppConstants.maxTokens,
            'tool_choice': 'none',
          }),
        )
        .timeout(const Duration(seconds: 60));

    if (fallbackResponse.statusCode == 200) {
      final data = jsonDecode(fallbackResponse.body) as Map<String, dynamic>;
      final choices = data['choices'] as List;
      if (choices.isNotEmpty) {
        final message = choices[0]['message'] as Map<String, dynamic>;
        return _cleanResponse(message['content'] as String? ?? '');
      }
    }

    throw Exception('AI请求超时，请检查网络后重试');
  }

  /// 续订下一周计划（支持联网搜索）
  static Future<String> renewPlan({
    required String diagnosis,
    required int currentWeek,
    required List<String> completedTasks,
    required String feedback,
  }) async {
    final renewPromptWithDate =
        '$renewSystemPrompt\n\n## 重要：当前日期\n今天是 $_todayStr。';

    final userContent = '''
## 原始诊断
$diagnosis

## 当前进度
- 已完成周数：$currentWeek
- 本周完成的任务：${completedTasks.join('、')}

## 用户反馈
$feedback

请根据以上信息生成第${currentWeek + 1}周的7天计划。
''';

    final allMessages = <Map<String, dynamic>>[
      {'role': 'system', 'content': renewPromptWithDate},
      {'role': 'user', 'content': userContent},
    ];

    for (var round = 0; round < 3; round++) {
      final allowTools = round == 0;

      final requestBody = <String, dynamic>{
        'model': AppConstants.model,
        'messages': allMessages,
        'temperature': AppConstants.temperature,
        'max_tokens': AppConstants.maxTokens,
      };

      if (allowTools) {
        requestBody['tools'] = _searchTools;
        requestBody['tool_choice'] = 'auto';
      } else {
        requestBody['tool_choice'] = 'none';
      }

      final response = await http
          .post(
            Uri.parse(AppConstants.apiEndpoint),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${AppConstants.apiKey}',
            },
            body: jsonEncode(requestBody),
          )
          .timeout(const Duration(seconds: 60));

      if (response.statusCode != 200) {
        final errorBody = jsonDecode(response.body);
        final errorMsg = errorBody['error']?['message'] ?? response.body;
        throw Exception('续订请求失败(${response.statusCode}): $errorMsg');
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final choices = data['choices'] as List;
      if (choices.isEmpty) throw Exception('续订返回为空');

      final message = choices[0]['message'] as Map<String, dynamic>;
      final toolCalls = message['tool_calls'] as List?;

      if (toolCalls == null || toolCalls.isEmpty || !allowTools) {
        return _cleanResponse(message['content'] as String? ?? '');
      }

      allMessages.add({
        'role': 'assistant',
        'content': message['content'] ?? '',
        'tool_calls': toolCalls,
      });

      for (final tc in toolCalls) {
        final tcMap = tc as Map<String, dynamic>;
        final function = tcMap['function'] as Map<String, dynamic>;
        final functionName = function['name'] as String;
        final toolCallId = tcMap['id'] as String;

        String searchResult = '';
        if (functionName == 'search_web') {
          try {
            final args = jsonDecode(function['arguments'] as String)
                as Map<String, dynamic>;
            final query = args['query'] as String? ?? '';
            if (query.isNotEmpty) {
              searchResult = await _executeWebSearch(query);
            }
          } catch (_) {
            searchResult = '';
          }
        }

        allMessages.add({
          'role': 'tool',
          'tool_call_id': toolCallId,
          'content': searchResult.isNotEmpty
              ? searchResult
              : '搜索服务暂不可用，请直接基于你的专业知识生成计划，不要再调用搜索工具。',
        });
      }
    }

    // 兜底：无工具请求
    final fallbackResponse = await http
        .post(
          Uri.parse(AppConstants.apiEndpoint),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${AppConstants.apiKey}',
          },
          body: jsonEncode({
            'model': AppConstants.model,
            'messages': allMessages,
            'temperature': AppConstants.temperature,
            'max_tokens': AppConstants.maxTokens,
            'tool_choice': 'none',
          }),
        )
        .timeout(const Duration(seconds: 60));

    if (fallbackResponse.statusCode == 200) {
      final data = jsonDecode(fallbackResponse.body) as Map<String, dynamic>;
      final choices = data['choices'] as List;
      if (choices.isNotEmpty) {
        final message = choices[0]['message'] as Map<String, dynamic>;
        return _cleanResponse(message['content'] as String? ?? '');
      }
    }

    throw Exception('续订请求超时，请检查网络后重试');
  }

  // ============ 计划微调 ============

  /// 微调系统提示词（计划页：保留诊断，只重新生成7天任务）
  static const String _adjustSystemPrompt = '''
你是规划助手「学径」。用户对已生成的计划不太满意，需要微调。

你将收到用户的原始诊断信息和当前计划，以及用户的调整反馈。请保留原有诊断信息不变，只重新生成7天任务的 plan JSON。

## 调整原则
- 节奏太紧：减少每天任务量，降低难度，增加复习和巩固环节
- 太简单：提升难度，增加进阶内容，加快进度
- 加练习：增加实操练习、应用场景、动手环节（如做项目、模拟考试、实际训练等）
- 手动输入：根据用户具体描述调整

## 输出规则
1. 先用一句话说明你做了哪些调整
2. 输出包含 plan 的 JSON（不含 diagnosis，因为诊断不变）

JSON 格式：
```json
{
  "plan": {
    "goal": "目标",
    "tasks": [
      {
        "day": 1,
        "title": "任务标题",
        "description": "任务详细描述",
        "resource_keywords": "资源搜索关键词",
        "encouragement": "鼓励语",
        "completed": 0,
        "focus_minutes": 0
      }
    ]
  }
}
```

## 注意事项
- tasks 必须恰好7个，day 字段为 1-7
- 目标 goal 保持不变
- 只输出一次 JSON
''';

  /// 微调本周任务系统提示词（学习页：重新生成本周剩余天数任务）
  static const String _adjustWeekSystemPrompt = '''
你是规划助手「学径」。用户正在执行本周计划，但想调整本周剩余天数的任务。

你将收到用户的目标、当前进度（已完成哪些任务、当前是第几天）和调整反馈。请重新生成本周剩余天数（从当前天数到第7天）的任务。

## 输出规则
1. 先用一句话说明调整方向
2. 输出包含 plan 的 JSON

JSON 格式：
```json
{
  "plan": {
    "goal": "目标",
    "tasks": [
      {
        "day": 1,
        "title": "任务标题",
        "description": "任务详细描述",
        "resource_keywords": "资源搜索关键词",
        "encouragement": "鼓励语",
        "completed": 0,
        "focus_minutes": 0
      }
    ]
  }
}
```

## 注意事项
- 只生成从当前天数到第7天的任务（如当前Day 3，则生成 day 3-7 共5个任务）
- 已完成的任务不要重新生成（用户会保留已完成任务）
- 目标 goal 保持不变
- 鼓励语要简短有温度
''';

  /// 微调计划（计划页：保留诊断，重新生成7天任务）
  ///
  /// [diagnosisJson] 原始诊断 JSON 字符串
  /// [currentPlanJson] 当前计划 JSON 字符串
  /// [feedback] 用户调整反馈
  static Future<String> adjustPlan({
    required String diagnosisJson,
    required String currentPlanJson,
    required String feedback,
  }) async {
    final userContent = '''
## 原始诊断
$diagnosisJson

## 当前计划
$currentPlanJson

## 用户调整反馈
$feedback

请根据用户反馈微调计划，保留诊断信息不变，只重新生成7天任务。
''';

    return _callAIWithSearch(
      systemPrompt: '$_adjustSystemPrompt\n\n## 重要：当前日期\n今天是 $_todayStr。',
      userContent: userContent,
    );
  }

  /// 微调本周剩余任务（学习页：重新生成本周剩余天数任务）
  ///
  /// [goal] 目标
  /// [diagnosisJson] 原始诊断 JSON 字符串
  /// [currentDayInWeek] 当前是本周第几天（1-7）
  /// [completedTaskTitles] 已完成的任务标题列表
  /// [feedback] 用户调整反馈
  static Future<String> adjustWeekTasks({
    required String goal,
    required String diagnosisJson,
    required int currentDayInWeek,
    required List<String> completedTaskTitles,
    required String feedback,
  }) async {
    final userContent = '''
## 目标
$goal

## 诊断信息
$diagnosisJson

## 当前进度
- 当前是本周第 $currentDayInWeek 天
- 已完成的任务：${completedTaskTitles.isEmpty ? '无' : completedTaskTitles.join('、')}

## 用户调整反馈
$feedback

请重新生成从第 $currentDayInWeek 天到第7天的任务。
''';

    return _callAIWithSearch(
      systemPrompt: '$_adjustWeekSystemPrompt\n\n## 重要：当前日期\n今天是 $_todayStr。',
      userContent: userContent,
    );
  }

  /// 通用 AI 调用（支持联网搜索，第1轮允许搜索，之后强制不搜索）
  static Future<String> _callAIWithSearch({
    required String systemPrompt,
    required String userContent,
  }) async {
    final allMessages = <Map<String, dynamic>>[
      {'role': 'system', 'content': systemPrompt},
      {'role': 'user', 'content': userContent},
    ];

    for (var round = 0; round < 3; round++) {
      final allowTools = round == 0;

      final requestBody = <String, dynamic>{
        'model': AppConstants.model,
        'messages': allMessages,
        'temperature': AppConstants.temperature,
        'max_tokens': AppConstants.maxTokens,
      };

      if (allowTools) {
        requestBody['tools'] = _searchTools;
        requestBody['tool_choice'] = 'auto';
      } else {
        requestBody['tool_choice'] = 'none';
      }

      final response = await http
          .post(
            Uri.parse(AppConstants.apiEndpoint),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${AppConstants.apiKey}',
            },
            body: jsonEncode(requestBody),
          )
          .timeout(const Duration(seconds: 60));

      if (response.statusCode != 200) {
        final errorBody = jsonDecode(response.body);
        final errorMsg = errorBody['error']?['message'] ?? response.body;
        throw Exception('AI请求失败(${response.statusCode}): $errorMsg');
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final choices = data['choices'] as List;
      if (choices.isEmpty) throw Exception('AI返回为空');

      final message = choices[0]['message'] as Map<String, dynamic>;
      final toolCalls = message['tool_calls'] as List?;

      if (toolCalls == null || toolCalls.isEmpty || !allowTools) {
        return _cleanResponse(message['content'] as String? ?? '');
      }

      allMessages.add({
        'role': 'assistant',
        'content': message['content'] ?? '',
        'tool_calls': toolCalls,
      });

      for (final tc in toolCalls) {
        final tcMap = tc as Map<String, dynamic>;
        final function = tcMap['function'] as Map<String, dynamic>;
        final functionName = function['name'] as String;
        final toolCallId = tcMap['id'] as String;

        String searchResult = '';
        if (functionName == 'search_web') {
          try {
            final args = jsonDecode(function['arguments'] as String)
                as Map<String, dynamic>;
            final query = args['query'] as String? ?? '';
            if (query.isNotEmpty) {
              searchResult = await _executeWebSearch(query);
            }
          } catch (_) {
            searchResult = '';
          }
        }

        allMessages.add({
          'role': 'tool',
          'tool_call_id': toolCallId,
          'content': searchResult.isNotEmpty
              ? searchResult
              : '搜索服务暂不可用，请直接基于你的专业知识生成计划。',
        });
      }
    }

    // 兜底
    final fallbackResponse = await http
        .post(
          Uri.parse(AppConstants.apiEndpoint),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${AppConstants.apiKey}',
          },
          body: jsonEncode({
            'model': AppConstants.model,
            'messages': allMessages,
            'temperature': AppConstants.temperature,
            'max_tokens': AppConstants.maxTokens,
            'tool_choice': 'none',
          }),
        )
        .timeout(const Duration(seconds: 60));

    if (fallbackResponse.statusCode == 200) {
      final data = jsonDecode(fallbackResponse.body) as Map<String, dynamic>;
      final choices = data['choices'] as List;
      if (choices.isNotEmpty) {
        final message = choices[0]['message'] as Map<String, dynamic>;
        return _cleanResponse(message['content'] as String? ?? '');
      }
    }

    throw Exception('AI请求超时，请检查网络后重试');
  }

  /// 检查 API Key 是否已配置
  static bool get isConfigured => AppConstants.apiKey.isNotEmpty;

  /// 从 AI 回复中提取 JSON
  static Map<String, dynamic>? extractJson(String text) {
    final jsonBlockRegex = RegExp(r'```json\s*([\s\S]*?)\s*```');
    final match = jsonBlockRegex.firstMatch(text);
    if (match != null) {
      try {
        return jsonDecode(match.group(1)!) as Map<String, dynamic>;
      } catch (_) {}
    }
    try {
      return jsonDecode(text) as Map<String, dynamic>;
    } catch (_) {}
    final braceRegex = RegExp(r'\{[\s\S]*\}');
    final braceMatch = braceRegex.firstMatch(text);
    if (braceMatch != null) {
      try {
        return jsonDecode(braceMatch.group(0)!) as Map<String, dynamic>;
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  /// 判断回复中是否包含计划 JSON
  static bool containsPlan(String text) {
    final json = extractJson(text);
    if (json == null) return false;
    return json['plan'] != null;
  }

  /// 提取 JSON 之前的引导文本
  static String extractIntroText(String text) {
    String intro = '';
    final jsonBlockRegex = RegExp(r'```json\s*[\s\S]*?\s*```');
    final match = jsonBlockRegex.firstMatch(text);
    if (match != null) {
      intro = text.substring(0, match.start).trim();
    } else {
      final braceIndex = text.indexOf('{');
      if (braceIndex > 0) {
        intro = text.substring(0, braceIndex).trim();
      } else {
        intro = text.trim();
      }
    }
    intro = intro
        .replaceAll('```json', '')
        .replaceAll('```', '')
        .replaceAll('**', '')
        .replaceAll('*', '')
        .replaceAll('##', '')
        .replaceAll('#', '')
        .replaceAll('`', '')
        .trim();
    return intro;
  }
}
