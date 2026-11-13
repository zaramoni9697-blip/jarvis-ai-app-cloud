enum AIProvider {
  gemini,
  openai,
  claude,
  deepseek,
  groq,
  openrouter,
  mistral,
  custom,
}

class AIProviderConfig {
  final AIProvider provider;
  final String apiKey;
  final String model;
  final String? baseUrl;

  const AIProviderConfig({
    required this.provider,
    required this.apiKey,
    required this.model,
    this.baseUrl,
  });

  String get providerId => provider.name;

  static const Map<AIProvider, String> defaultUrls = {
    AIProvider.gemini:
        'https://generativelanguage.googleapis.com/v1beta',
    AIProvider.openai:
        'https://api.openai.com/v1',
    AIProvider.claude:
        'https://api.anthropic.com/v1',
    AIProvider.deepseek:
        'https://api.deepseek.com/v1',
    AIProvider.groq:
        'https://api.groq.com/openai/v1',
    AIProvider.openrouter:
        'https://openrouter.ai/api/v1',
    AIProvider.mistral:
        'https://api.mistral.ai/v1',
  };

  static const Map<AIProvider, String> defaultModels = {
    AIProvider.gemini: '',
    AIProvider.openai: '',
    AIProvider.claude: '',
    AIProvider.deepseek: '',
    AIProvider.groq: '',
    AIProvider.openrouter: '',
    AIProvider.mistral: '',
    AIProvider.custom: '',
  };

  String get endpointBase {
    return (baseUrl ?? defaultUrls[provider] ?? '').trim();
  }
}
