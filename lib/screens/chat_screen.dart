import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/theme.dart';
import '../models/ai_provider_config.dart';
import '../services/provider_key_storage.dart';
import '../services/multi_provider_ai_service.dart';
import '../services/database_service.dart';
import 'api_setup_screen.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  final List<Map<String, String>> _messages = [];

  bool _loading = false;
  bool _initializing = true;

  String? _sessionId;
  String? _setupError;

  int? _profileId;

  MultiProviderAIService? _ai;

  String _providerName = 'Not configured';

  @override
  void initState() {
    super.initState();

    _sessionId =
        'session_${DateTime.now().millisecondsSinceEpoch}';

    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final sessionData = prefs.getString('active_session');

      if (sessionData == null) {
        throw Exception('Login session পাওয়া যায়নি।');
      }

      final session = jsonDecode(sessionData);

      _profileId = session['profile_id'] as int;

      final prefix = 'jarvis_${_profileId}_';

      final providerId =
          prefs.getString('${prefix}provider');

      if (providerId == null) {
        throw Exception('AI Provider সেটআপ করা হয়নি।');
      }

      final provider = AIProvider.values.firstWhere(
        (p) => p.name == providerId,
        orElse: () => throw Exception('Unknown AI Provider'),
      );

      final apiKey = await ProviderKeyStorage.read(
        profileId: _profileId!,
        provider: provider.name,
      );

      if (apiKey == null || apiKey.trim().isEmpty) {
        throw Exception('এই Provider-এর API Key পাওয়া যায়নি।');
      }

      final model = prefs.getString(
        '${prefix}model_${provider.name}',
      );

      if (model == null || model.trim().isEmpty) {
        throw Exception('Model ID সেটআপ করা হয়নি।');
      }

      final baseUrl = prefs.getString(
        '${prefix}url_${provider.name}',
      );

      final config = AIProviderConfig(
        provider: provider,
        apiKey: apiKey,
        model: model,
        baseUrl: baseUrl,
      );

      _ai?.dispose();

      _ai = MultiProviderAIService(
        config: config,
      );

      _providerName = provider.name.toUpperCase();
      _setupError = null;
    } catch (e) {
      _setupError = e.toString();
      _ai?.dispose();
      _ai = null;
    }

    if (mounted) {
      setState(() => _initializing = false);
    }
  }

  Future<void> _sendMessage() async {
    final text = _msgCtrl.text.trim();

    if (text.isEmpty || _loading) return;

    if (_ai == null) {
      setState(() {
        _messages.add({
          'role': 'assistant',
          'content':
              'AI Provider প্রস্তুত নয়। Settings থেকে API Key ও Model ID সেটআপ করো।',
        });
      });

      _scrollDown();
      return;
    }

    _msgCtrl.clear();

    setState(() {
      _messages.add({
        'role': 'user',
        'content': text,
      });

      _loading = true;
    });

    _scrollDown();

    try {
      final response = await _ai!.chat(
        messages: _messages,
        systemPrompt:
            'You are JARVIS, an intelligent personal AI assistant. '
            'Be helpful, accurate, polite and concise. '
            'Automatically detect whether the user is speaking Bengali '
            'or English. Reply in the same language as the user. '
            'Do not ask the user to select a language.',
      );

      if (_profileId != null && _sessionId != null) {
        await DatabaseService.saveChatMessage(
          profileId: _profileId!,
          sessionId: _sessionId!,
          role: 'user',
          content: text,
        );

        await DatabaseService.saveChatMessage(
          profileId: _profileId!,
          sessionId: _sessionId!,
          role: 'assistant',
          content: response,
        );
      }

      if (!mounted) return;

      setState(() {
        _messages.add({
          'role': 'assistant',
          'content': response,
        });

        _loading = false;
      });

      _scrollDown();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _messages.add({
          'role': 'assistant',
          'content': 'AI Error: $e',
        });

        _loading = false;
      });

      _scrollDown();
    }
  }

  void _newChat() {
    if (_loading) return;

    setState(() {
      _messages.clear();

      _sessionId =
          'session_${DateTime.now().millisecondsSinceEpoch}';
    });
  }

  void _scrollDown() {
    Future.delayed(const Duration(milliseconds: 150), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _openProviderSetup() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const ApiSetupScreen(),
      ),
    );

    if (!mounted) return;

    setState(() => _initializing = true);

    await _loadProfile();
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    _ai?.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: JarvisTheme.background,
      appBar: AppBar(
        backgroundColor: JarvisTheme.surface,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'JARVIS CHAT',
              style: TextStyle(
                color: JarvisTheme.primary,
                letterSpacing: 2,
                fontSize: 16,
              ),
            ),
            Text(
              _providerName,
              style: const TextStyle(
                color: JarvisTheme.textSecondary,
                fontSize: 10,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.settings_outlined,
              color: JarvisTheme.primary,
            ),
            onPressed: _openProviderSetup,
          ),
          IconButton(
            icon: const Icon(
              Icons.add_circle_outline,
              color: JarvisTheme.primary,
            ),
            onPressed: _newChat,
          ),
        ],
      ),
      body: _initializing
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : Column(
              children: [
                if (_ai == null) _buildSetupWarning(),
                Expanded(
                  child: _messages.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          controller: _scrollCtrl,
                          padding: const EdgeInsets.all(16),
                          itemCount:
                              _messages.length + (_loading ? 1 : 0),
                          itemBuilder: (_, i) {
                            if (i == _messages.length) {
                              return _buildTyping();
                            }

                            return _buildMessage(_messages[i]);
                          },
                        ),
                ),
                _buildInput(),
              ],
            ),
    );
  }

  Widget _buildSetupWarning() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: JarvisTheme.error.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: JarvisTheme.error.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'AI PROVIDER NOT READY',
            style: TextStyle(
              color: JarvisTheme.error,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _setupError ?? 'Provider setup required.',
            style: const TextStyle(
              color: JarvisTheme.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _openProviderSetup,
            icon: const Icon(Icons.settings),
            label: const Text('SETUP AI PROVIDER'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 64,
            color: JarvisTheme.primary.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'Ask Jarvis anything...',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(
                  color: JarvisTheme.textSecondary,
                ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Bangla অথবা English-এ কথা বলো',
            style: TextStyle(
              color: JarvisTheme.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessage(Map<String, String> msg) {
    final isUser = msg['role'] == 'user';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: JarvisTheme.primary.withValues(alpha: 0.2),
                border: Border.all(
                  color: JarvisTheme.primary.withValues(alpha: 0.5),
                ),
              ),
              child: const Icon(
                Icons.auto_awesome,
                color: JarvisTheme.primary,
                size: 16,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isUser
                    ? JarvisTheme.primary.withValues(alpha: 0.15)
                    : JarvisTheme.surfaceVariant,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
                border: Border.all(
                  color: isUser
                      ? JarvisTheme.primary.withValues(alpha: 0.3)
                      : JarvisTheme.border,
                ),
              ),
              child: Text(
                msg['content'] ?? '',
                style: TextStyle(
                  color: isUser
                      ? JarvisTheme.primary
                      : JarvisTheme.textPrimary,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTyping() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          CircularProgressIndicator(
            strokeWidth: 2,
            color: JarvisTheme.primary,
          ),
          SizedBox(width: 12),
          Text(
            'JARVIS is thinking...',
            style: TextStyle(
              color: JarvisTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: JarvisTheme.surface,
        border: Border(
          top: BorderSide(color: JarvisTheme.border),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _msgCtrl,
              enabled: !_loading,
              style: const TextStyle(
                color: JarvisTheme.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: 'Ask Jarvis anything...',
                hintStyle: const TextStyle(
                  color: JarvisTheme.textSecondary,
                ),
                filled: true,
                fillColor: JarvisTheme.surfaceVariant,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(
                    color: JarvisTheme.border,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(
                    color: JarvisTheme.border,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(
                    color: JarvisTheme.primary,
                    width: 1.5,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
              onSubmitted: (_) => _sendMessage(),
              maxLines: null,
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _loading ? null : _sendMessage,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _loading
                    ? JarvisTheme.textSecondary
                    : JarvisTheme.primary,
              ),
              child: const Icon(
                Icons.send,
                color: Colors.black,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
