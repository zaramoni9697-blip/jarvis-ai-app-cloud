import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/theme.dart';
import '../models/ai_provider_config.dart';
import '../services/provider_key_storage.dart';
import '../services/multi_provider_ai_service.dart';

class ApiSetupScreen extends StatefulWidget {
  const ApiSetupScreen({super.key});

  @override
  State<ApiSetupScreen> createState() => _ApiSetupScreenState();
}

class _ApiSetupScreenState extends State<ApiSetupScreen> {
  final _keyCtrl = TextEditingController();
  final _modelCtrl = TextEditingController();
  final _urlCtrl = TextEditingController();

  AIProvider _provider = AIProvider.gemini;

  int? _profileId;
  bool _showKey = false;
  bool _loading = true;
  bool _testing = false;
  String? _status;
  bool _success = false;

  final Map<AIProvider, String> _names = {
    AIProvider.gemini: 'Google Gemini',
    AIProvider.openai: 'OpenAI',
    AIProvider.claude: 'Anthropic Claude',
    AIProvider.deepseek: 'DeepSeek',
    AIProvider.groq: 'Groq',
    AIProvider.openrouter: 'OpenRouter',
    AIProvider.mistral: 'Mistral',
    AIProvider.custom: 'Custom API',
  };

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  String get _providerId => _provider.name;

  String get _settingsPrefix => 'jarvis_${_profileId}_';

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString('active_session');

      if (data == null) {
        throw Exception('Login session not found');
      }

      final session = jsonDecode(data);
      _profileId = session['profile_id'] as int;

      final savedProvider =
          prefs.getString('${_settingsPrefix}provider');

      if (savedProvider != null) {
        _provider = AIProvider.values.firstWhere(
          (p) => p.name == savedProvider,
          orElse: () => AIProvider.gemini,
        );
      }

      _modelCtrl.text =
          prefs.getString('${_settingsPrefix}model_${_providerId}') ?? '';

      _urlCtrl.text =
          prefs.getString('${_settingsPrefix}url_${_providerId}') ??
          AIProviderConfig.defaultUrls[_provider] ??
          '';

      _keyCtrl.text =
          await ProviderKeyStorage.read(
            profileId: _profileId!,
            provider: _providerId,
          ) ?? '';
    } catch (e) {
      _status = 'Settings load error: $e';
    }

    if (mounted) {
      setState(() => _loading = false);
    }
  }

  Future<void> _changeProvider(AIProvider? value) async {
    if (value == null || _profileId == null) return;

    setState(() {
      _loading = true;
      _status = null;
      _provider = value;
      _keyCtrl.clear();
      _modelCtrl.clear();
    });

    final prefs = await SharedPreferences.getInstance();

    _modelCtrl.text =
        prefs.getString('${_settingsPrefix}model_${_providerId}') ?? '';

    _urlCtrl.text =
        prefs.getString('${_settingsPrefix}url_${_providerId}') ??
        AIProviderConfig.defaultUrls[_provider] ??
        '';

    _keyCtrl.text =
        await ProviderKeyStorage.read(
          profileId: _profileId!,
          provider: _providerId,
        ) ?? '';

    if (mounted) {
      setState(() => _loading = false);
    }
  }

  AIProviderConfig _buildConfig() {
    return AIProviderConfig(
      provider: _provider,
      apiKey: _keyCtrl.text.trim(),
      model: _modelCtrl.text.trim(),
      baseUrl: _urlCtrl.text.trim(),
    );
  }

  Future<void> _saveSettings() async {
    if (_profileId == null) return;

    if (_keyCtrl.text.trim().isEmpty ||
        _modelCtrl.text.trim().isEmpty) {
      _showStatus('API Key এবং Model ID দিতে হবে.', false);
      return;
    }

    if (_provider == AIProvider.custom &&
        Uri.tryParse(_urlCtrl.text.trim())?.hasScheme != true) {
      _showStatus('সঠিক Custom API URL দাও.', false);
      return;
    }

    setState(() {
      _loading = true;
      _status = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();

      await ProviderKeyStorage.save(
        profileId: _profileId!,
        provider: _providerId,
        apiKey: _keyCtrl.text.trim(),
      );

      await prefs.setString(
        '${_settingsPrefix}provider',
        _providerId,
      );

      await prefs.setString(
        '${_settingsPrefix}model_${_providerId}',
        _modelCtrl.text.trim(),
      );

      await prefs.setString(
        '${_settingsPrefix}url_${_providerId}',
        _urlCtrl.text.trim(),
      );

      _showStatus('Provider settings saved successfully!', true);
    } catch (e) {
      _showStatus('Save failed: $e', false);
    }

    if (mounted) {
      setState(() => _loading = false);
    }
  }

  Future<void> _testConnection() async {
    if (_keyCtrl.text.trim().isEmpty ||
        _modelCtrl.text.trim().isEmpty) {
      _showStatus('আগে API Key এবং Model ID দাও.', false);
      return;
    }

    setState(() {
      _testing = true;
      _status = 'Testing connection...';
      _success = false;
    });

    final service = MultiProviderAIService(
      config: _buildConfig(),
    );

    try {
      final result = await service.chat(
        messages: [
          {'role': 'user', 'content': 'Reply with only: JARVIS OK'}
        ],
      );

      if (!mounted) return;

      _showStatus('Connection successful: ${result.trim()}', true);
    } catch (e) {
      if (!mounted) return;
      _showStatus('Connection failed: $e', false);
    } finally {
      service.dispose();

      if (mounted) {
        setState(() => _testing = false);
      }
    }
  }

  void _showStatus(String message, bool success) {
    if (!mounted) return;

    setState(() {
      _status = message;
      _success = success;
    });
  }

  @override
  void dispose() {
    _keyCtrl.dispose();
    _modelCtrl.dispose();
    _urlCtrl.dispose();
    super.dispose();
  }

  InputDecoration _decoration(String label, String hint) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: const TextStyle(color: JarvisTheme.primary),
      hintStyle: const TextStyle(color: JarvisTheme.textSecondary),
      filled: true,
      fillColor: JarvisTheme.surfaceVariant,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: JarvisTheme.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: JarvisTheme.primary,
          width: 1.5,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: JarvisTheme.background,
      appBar: AppBar(
        backgroundColor: JarvisTheme.background,
        title: const Text(
          'AI PROVIDER SETUP',
          style: TextStyle(
            color: JarvisTheme.primary,
            fontSize: 16,
            letterSpacing: 1.5,
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'SELECT AI PROVIDER',
                    style: TextStyle(
                      color: JarvisTheme.primary,
                      letterSpacing: 1.3,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 10),

                  DropdownButtonFormField<AIProvider>(
                    value: _provider,
                    dropdownColor: JarvisTheme.surface,
                    decoration: _decoration(
                      'Provider',
                      'Select provider',
                    ),
                    style: const TextStyle(
                      color: JarvisTheme.textPrimary,
                    ),
                    items: AIProvider.values.map((provider) {
                      return DropdownMenuItem(
                        value: provider,
                        child: Text(_names[provider]!),
                      );
                    }).toList(),
                    onChanged: _changeProvider,
                  ),

                  const SizedBox(height: 22),

                  TextField(
                    controller: _keyCtrl,
                    obscureText: !_showKey,
                    style: const TextStyle(
                      color: JarvisTheme.textPrimary,
                    ),
                    decoration: _decoration(
                      'API Key',
                      'Enter your API key',
                    ).copyWith(
                      suffixIcon: IconButton(
                        icon: Icon(
                          _showKey
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: JarvisTheme.primary,
                        ),
                        onPressed: () {
                          setState(() => _showKey = !_showKey);
                        },
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  TextField(
                    controller: _modelCtrl,
                    style: const TextStyle(
                      color: JarvisTheme.textPrimary,
                    ),
                    decoration: _decoration(
                      'Model ID',
                      'Enter the exact model ID',
                    ),
                  ),

                  const SizedBox(height: 16),

                  TextField(
                    controller: _urlCtrl,
                    style: const TextStyle(
                      color: JarvisTheme.textPrimary,
                    ),
                    decoration: _decoration(
                      'API Base URL',
                      'Enter API URL',
                    ),
                  ),

                  const SizedBox(height: 8),

                  const Text(
                    'Custom API-এর ক্ষেত্রে OpenAI-compatible '
                    'Chat Completions endpoint প্রয়োজন। '
                    'অন্য Provider-এর জন্য default URL পরিবর্তন '
                    'করার প্রয়োজন নেই।',
                    style: TextStyle(
                      color: JarvisTheme.textSecondary,
                      fontSize: 11,
                      height: 1.5,
                    ),
                  ),

                  const SizedBox(height: 20),

                  if (_status != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _success
                            ? JarvisTheme.success.withValues(alpha: 0.12)
                            : JarvisTheme.error.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _success
                              ? JarvisTheme.success
                              : JarvisTheme.error,
                        ),
                      ),
                      child: Text(
                        _status!,
                        style: TextStyle(
                          color: _success
                              ? JarvisTheme.success
                              : JarvisTheme.error,
                          fontSize: 12,
                        ),
                      ),
                    ),

                  const SizedBox(height: 18),

                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _testing ? null : _testConnection,
                      icon: const Icon(Icons.wifi_tethering),
                      label: Text(
                        _testing
                            ? 'TESTING...'
                            : 'TEST CONNECTION',
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _loading ? null : _saveSettings,
                      icon: const Icon(Icons.save),
                      label: const Text('SAVE PROVIDER SETTINGS'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: JarvisTheme.primary,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),

                  const SizedBox(height: 22),

                  const Text(
                    'SECURITY NOTE',
                    style: TextStyle(
                      color: JarvisTheme.primary,
                      letterSpacing: 1,
                    ),
                  ),

                  const SizedBox(height: 8),

                  const Text(
                    'API Key Android Secure Storage-এ রাখা হয়। '
                    'Model ID ও URL app preferences-এ সংরক্ষিত হয়। '
                    'API Key কাউকে শেয়ার করবে না।',
                    style: TextStyle(
                      color: JarvisTheme.textSecondary,
                      height: 1.6,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
