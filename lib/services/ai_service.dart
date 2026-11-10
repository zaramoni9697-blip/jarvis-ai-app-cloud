import 'dart:convert';
import 'package:http/http.dart' as http;

class AIService {
  final String apiKey;
  final String provider;
  final String model;

  AIService({
    required this.apiKey,
    required this.provider,
    this.model = 'gemini-1.5-flash',
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

  // ── Google Gemini ──
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
        'parts': [{'text': msg['content']}],
      };
    }).toList();

    final body = {
      'contents': contents,
      'systemInstruction': systemPrompt != null
          ? {'parts': [{'text': systemPrompt}]}
          : null,
      'generationConfig': {
        'temperature': 0.9,
        'topK': 40,
        'topP': 0.95,
        'maxOutputTokens': 2048,
      },
    };

    if (systemPrompt == null) body.remove('systemInstruction');

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['candidates'][0]['content']['parts'][0]['text'] as String;
    }
    
    throw Exception('Gemini error: ${response.statusCode} ${response.body}');
  }

  // ── OpenAI / OpenAI-compatible ──
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

    final response = await http.post(
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
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['choices'][0]['message']['content'] as String;
    }
    
    throw Exception('OpenAI error: ${response.statusCode}');
  }

  // ── Groq (OpenAI-compatible) ──
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

  // ── Autonomous fallback ──
  String _autonomousResponse(String input) {
    final lower = input.toLowerCase();
    if (lower.contains('সময়') || lower.contains('time')) {
      return 'এখন ${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}।';
    }
    if (lower.contains('তারিখ') || lower.contains('date')) {
      return 'আজ ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}।';
    }
    return 'Autonomous Engine সক্রিয়। AI প্রোভাইডার সেটআপ করলে আরও ভালো উত্তর পাবে।';
  }

  // ── Verify API key ──
  static Future<bool> verifyGeminiKey(String key) async {
    try {
      final service = AIService(apiKey: key, provider: 'gemini');
      await service.chat(messages: [
        {'role': 'user', 'content': 'Hi'}
      ]);
      return true;
    } catch (_) {
      return false;
    }
  }
}
