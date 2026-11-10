import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:math';
import '../utils/theme.dart';
import '../services/ai_service.dart';
import '../services/database_service.dart';

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
  String? _sessionId;
  int? _profileId;
  AIService? _ai;

  @override
  void initState() {
    super.initState();
    _sessionId = 'session_${DateTime.now().millisecondsSinceEpoch}';
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('active_session');
    if (data != null) {
      final session = jsonDecode(data);
      _profileId = session['profile_id'] as int;
      
      // Load API key
      final apiKey = await DatabaseService.getApiKey(_profileId!, 'gemini');
      if (apiKey != null) {
        _ai = AIService(
          apiKey: apiKey,
          provider: 'gemini',
          model: 'gemini-1.5-flash',
        );
      } else {
        _ai = AIService(apiKey: '', provider: 'autonomous');
      }
    }
  }

  Future<void> _sendMessage() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || _loading) return;

    _msgCtrl.clear();
    setState(() {
      _messages.add({'role': 'user', 'content': text});
      _loading = true;
    });
    _scrollDown();

    try {
      final response = await _ai!.chat(
        messages: _messages,
        systemPrompt: 'You are Jarvis, an intelligent AI assistant. '
            'Be helpful, concise, and smart. '
            'You can respond in Bengali or English based on the user\'s language.',
      );

      if (_profileId != null) {
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

      setState(() {
        _messages.add({'role': 'assistant', 'content': response});
        _loading = false;
      });
      _scrollDown();
    } catch (e) {
      setState(() {
        _messages.add({
          'role': 'assistant',
          'content': 'ত্রুটি: ${e.toString()}\n\nAPI key সেটআপ করো।',
        });
        _loading = false;
      });
      _scrollDown();
    }
  }

  void _scrollDown() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: JarvisTheme.background,
      appBar: AppBar(
        backgroundColor: JarvisTheme.surface,
        title: const Text(
          'JARVIS CHAT',
          style: TextStyle(
            color: JarvisTheme.primary,
            letterSpacing: 2,
            fontSize: 16,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline,
                color: JarvisTheme.primary),
            onPressed: () {
              setState(() {
                _messages.clear();
                _sessionId =
                    'session_${DateTime.now().millisecondsSinceEpoch}';
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length + (_loading ? 1 : 0),
                    itemBuilder: (_, i) {
                      if (i == _messages.length) return _buildTyping();
                      return _buildMessage(_messages[i]);
                    },
                  ),
          ),
          _buildInput(),
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
            color: JarvisTheme.primary.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'Ask Jarvis anything...',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: JarvisTheme.textSecondary,
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
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: JarvisTheme.primary.withOpacity(0.2),
                border: Border.all(color: JarvisTheme.primary.withOpacity(0.5)),
              ),
              child: const Icon(Icons.add,
                  color: JarvisTheme.primary, size: 16),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isUser
                    ? JarvisTheme.primary.withOpacity(0.15)
                    : JarvisTheme.surfaceVariant,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
                border: Border.all(
                  color: isUser
                      ? JarvisTheme.primary.withOpacity(0.3)
                      : JarvisTheme.border,
                ),
              ),
              child: Text(
                msg['content'] ?? '',
                style: TextStyle(
                  color: isUser ? JarvisTheme.primary : JarvisTheme.textPrimary,
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: JarvisTheme.primary.withOpacity(0.2),
            ),
            child: const Icon(Icons.add,
                color: JarvisTheme.primary, size: 16),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: JarvisTheme.surfaceVariant,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) {
                return AnimatedContainer(
                  duration: Duration(milliseconds: 300 + i * 100),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: JarvisTheme.primary,
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: JarvisTheme.surface,
        border: const Border(
          top: BorderSide(color: JarvisTheme.border),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _msgCtrl,
              style: const TextStyle(color: JarvisTheme.textPrimary),
              decoration: InputDecoration(
                hintText: 'Ask Jarvis anything...',
                hintStyle: const TextStyle(color: JarvisTheme.textSecondary),
                filled: true,
                fillColor: JarvisTheme.surfaceVariant,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: JarvisTheme.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: JarvisTheme.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide:
                      const BorderSide(color: JarvisTheme.primary, width: 1.5),
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
            onTap: _sendMessage,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: JarvisTheme.primary,
                boxShadow: [
                  BoxShadow(
                    color: JarvisTheme.primary.withOpacity(0.4),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Icon(Icons.send, color: Colors.black, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}
