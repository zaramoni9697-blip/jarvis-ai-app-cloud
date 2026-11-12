import 'dart:convert';
import 'package:http/http.dart' as http;

class AIService {
  final String apiKey;
  final String provider;
  final String model;

  AIService({
    required this.apiKey,
    required this.provider,
    this.model = 'gemini-3.8-flash',
  });

  Future<String> chat({
    required List<Map<String, String>> messages,
    String? systemPrompt,
  }) async {
    switch (provider.toLowerCase()) {
      case 'gemini':
        return _geminiChat(messages: messages, systemPrompt: systemPrompt);
      case 'openai':
        return _openAIChat(messages: messages, systemPrompt: systemPrompt);
      case 'groq':
        return _groqChat(messages: messages, systemPrompt: systemPrompt);
      default:
        return _autonomousResponse(messages.last['content'] ?? '');
    }
  }

  Future<String> _geminiChat({
    required List<Map<String, String>> messages,
    String? systemPrompt,
  }) async {
    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey',
    );

    final contents = messages.map((msg) {
      return {
        'role': msg['role'] == 'assistant' ? 'model' : 'user',
        'parts': [
          {'text': msg['content']}
        ],
      };
    }).toList();

    final Map<String, dynamic> body = {
      'contents': contents,
      'generationConfig': {
        'temperature': 0.9,
        'topK': 40,
        'topP': 0.95,
        'maxOutputTokens': 2048,
      },
    };

    if (systemPrompt != null) {
      body['systemInstruction'] = {
        'parts': [
          {'text': systemPrompt}
        ]
      };
    }

    final response = await http
        .post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['candidates'][0]['content']['parts'][0]['text'] as String;
    }

    final errData = jsonDecode(response.body);
    final errMsg = errData['error']?['message'] ?? 'Unknown error';
    throw Exception('Gemini error ${response.statusCode}: $errMsg');
  }

  Future<String> _openAIChat({
    required List<Map<String, String>> messages,
    String? systemPrompt,
    String baseUrl = 'https://api.openai.com/v1',
  }) async {
    final url = Uri.parse('$baseUrl/chat/completions');
    final allMessages = <Map<String, String>>[];
    if (systemPrompt != null) {
      allMessages.add({'role': 'system', 'content': systemPrompt});
    }
    allMessages.addAll(messages);

    final response = await http
        .post(
          url,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $apiKey',
          },
          body: jsonEncode({
            'model': model,
            'messages': allMessages,
            'max_tokens': 2048,
            'temperature': 0.9,
          }),
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['choices'][0]['message']['content'] as String;
    }
    throw Exception('OpenAI error: ${response.statusCode}');
  }

  Future<String> _groqChat({
    required List<Map<String, String>> messages,
    String? systemPrompt,
  }) async {
    return _openAIChat(
      messages: messages,
      systemPrompt: systemPrompt,
      baseUrl: 'https://api.groq.com/openai/v1',
    );
  }

  String _autonomousResponse(String input) {
    final lower = input.toLowerCase();
    if (lower.contains('সময়') || lower.contains('time')) {
      return 'এখন ${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}।';
    }
    if (lower.contains('তারিখ') || lower.contains('date')) {
      return 'আজ ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}।';
    }
    return 'Autonomous Engine সক্রিয়। AI Provider সেটআপ করো Settings থেকে।';
  }

  // ── Verify Gemini key ──
  static Future<bool> verifyGeminiKey(String key) async {
    try {
      final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$key',
      );

      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'contents': [
                {
                  'role': 'user',
                  'parts': [
                    {'text': 'Hi'}
                  ]
                }
              ],
              'generationConfig': {
                'maxOutputTokens': 10,
              },
            }),
          )
          .timeout(const Duration(seconds: 15));

      // 200 = valid key
      // 400 = bad request but key is valid
      // 401 / 403 = invalid key
      if (response.statusCode == 200 || response.statusCode == 400) {
        final data = jsonDecode(response.body);
        // 400 হলেও যদি error code API_KEY_INVALID না হয়, তাহলে key valid
        if (response.statusCode == 400) {
          final errCode = data['error']?['status'] ?? '';
          if (errCode == 'INVALID_ARGUMENT') return true;
          return false;
        }
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }
}
