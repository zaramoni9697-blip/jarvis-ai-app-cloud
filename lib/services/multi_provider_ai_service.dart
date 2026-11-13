import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/ai_provider_config.dart';

class MultiProviderAIService {
  final AIProviderConfig config;
  final http.Client _client;

  MultiProviderAIService({
    required this.config,
    http.Client? client,
  }) : _client = client ?? http.Client();

  Future<String> chat({
    required List<Map<String, String>> messages,
    String? systemPrompt,
  }) async {
    if (config.apiKey.trim().isEmpty) {
      throw Exception('API Key is missing');
    }

    if (config.model.trim().isEmpty) {
      throw Exception('Model ID is required');
    }

    switch (config.provider) {
      case AIProvider.gemini:
        return _gemini(messages, systemPrompt);

      case AIProvider.claude:
        return _claude(messages, systemPrompt);

      case AIProvider.openai:
      case AIProvider.deepseek:
      case AIProvider.groq:
      case AIProvider.openrouter:
      case AIProvider.mistral:
      case AIProvider.custom:
        return _openAICompatible(messages, systemPrompt);
    }
  }

  Uri _url(String path) {
    final base = config.endpointBase.replaceFirst(
      RegExp(r'/+$'),
      '',
    );

    return Uri.parse('$base/$path');
  }

  Exception _apiError(http.Response response) {
    String message = response.body;

    try {
      final data = jsonDecode(response.body);
      message = data['error']?['message'] ??
          data['message'] ??
          response.body;
    } catch (_) {}

    return Exception(
      'HTTP ${response.statusCode}: $message',
    );
  }

  Future<String> _openAICompatible(
    List<Map<String, String>> messages,
    String? systemPrompt,
  ) async {
    final base = config.endpointBase.replaceFirst(
      RegExp(r'/+$'),
      '',
    );

    final endpoint = base.endsWith('/chat/completions')
        ? Uri.parse(base)
        : Uri.parse('$base/chat/completions');

    final allMessages = <Map<String, String>>[];

    if (systemPrompt != null && systemPrompt.isNotEmpty) {
      allMessages.add({
        'role': 'system',
        'content': systemPrompt,
      });
    }

    allMessages.addAll(messages);

    final response = await _client.post(
      endpoint,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${config.apiKey}',
      },
      body: jsonEncode({
        'model': config.model,
        'messages': allMessages,
        'temperature': 0.7,
        'max_tokens': 2048,
      }),
    ).timeout(const Duration(seconds: 60));

    if (response.statusCode != 200) {
      throw _apiError(response);
    }

    final data = jsonDecode(response.body);
    final content = data['choices']?[0]?['message']?['content'];

    if (content is String && content.isNotEmpty) {
      return content;
    }

    throw Exception('Provider returned an empty response');
  }

  Future<String> _gemini(
    List<Map<String, String>> messages,
    String? systemPrompt,
  ) async {
    final endpoint = Uri.parse(
      '${config.endpointBase}/models/${config.model}:generateContent',
    ).replace(queryParameters: {
      'key': config.apiKey,
    });

    final contents = messages.map((msg) {
      final role = msg['role'] == 'assistant'
          ? 'model'
          : 'user';

      return {
        'role': role,
        'parts': [
          {'text': msg['content'] ?? ''}
        ],
      };
    }).toList();

    final body = <String, dynamic>{
      'contents': contents,
      'generationConfig': {
        'temperature': 0.7,
        'maxOutputTokens': 2048,
      },
    };

    if (systemPrompt != null && systemPrompt.isNotEmpty) {
      body['systemInstruction'] = {
        'parts': [
          {'text': systemPrompt}
        ],
      };
    }

    final response = await _client.post(
      endpoint,
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    ).timeout(const Duration(seconds: 60));

    if (response.statusCode != 200) {
      throw _apiError(response);
    }

    final data = jsonDecode(response.body);
    final parts = data['candidates']?[0]?['content']?['parts'];

    if (parts is List) {
      final result = parts
          .whereType<Map>()
          .map((part) => part['text'] ?? '')
          .join();

      if (result.isNotEmpty) return result;
    }

    throw Exception('Gemini returned an empty response');
  }

  Future<String> _claude(
    List<Map<String, String>> messages,
    String? systemPrompt,
  ) async {
    final endpoint = _url('messages');

    final claudeMessages = messages
        .where((m) => m['role'] != 'system')
        .map((m) => {
          'role': m['role'] == 'assistant'
              ? 'assistant'
              : 'user',
          'content': m['content'] ?? '',
        })
        .toList();

    final body = <String, dynamic>{
      'model': config.model,
      'max_tokens': 2048,
      'messages': claudeMessages,
    };

    if (systemPrompt != null && systemPrompt.isNotEmpty) {
      body['system'] = systemPrompt;
    }

    final response = await _client.post(
      endpoint,
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': config.apiKey,
        'anthropic-version': '2023-06-01',
      },
      body: jsonEncode(body),
    ).timeout(const Duration(seconds: 60));

    if (response.statusCode != 200) {
      throw _apiError(response);
    }

    final data = jsonDecode(response.body);
    final content = data['content'];

    if (content is List) {
      final result = content
          .whereType<Map>()
          .where((item) => item['type'] == 'text')
          .map((item) => item['text'] ?? '')
          .join();

      if (result.isNotEmpty) return result;
    }

    throw Exception('Claude returned an empty response');
  }

  void dispose() {
    _client.close();
  }
}
