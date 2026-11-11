import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../utils/theme.dart';
import '../services/database_service.dart';
import '../services/ai_service.dart';

class ApiSetupScreen extends StatefulWidget {
  const ApiSetupScreen({super.key});

  @override
  State<ApiSetupScreen> createState() => _ApiSetupScreenState();
}

class _ApiSetupScreenState extends State<ApiSetupScreen> {
  final _keyCtrl = TextEditingController();
  bool _showKey = false;
  bool _loading = false;
  bool _verified = false;
  String? _status;
  int? _profileId;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('active_session');
    if (data != null) {
      final session = jsonDecode(data);
      _profileId = session['profile_id'] as int;
      final key = await DatabaseService.getApiKey(_profileId!, 'gemini');
      if (key != null) {
        _keyCtrl.text = key;
        setState(() => _verified = true);
      }
    }
  }

  Future<void> _verifyKey() async {
    if (_keyCtrl.text.trim().isEmpty) return;
    setState(() {
      _loading = true;
      _status = 'Verifying...';
      _verified = false;
    });
    final ok = await AIService.verifyGeminiKey(_keyCtrl.text.trim());
    setState(() {
      _loading = false;
      _verified = ok;
      _status = ok ? '✓ Key verified successfully!' : '✗ Invalid key. Check and retry.';
    });
  }

  Future<void> _saveKey() async {
    if (_keyCtrl.text.trim().isEmpty || _profileId == null) return;
    setState(() => _loading = true);
    await DatabaseService.saveApiKey(
      profileId: _profileId!,
      provider: 'gemini',
      apiKey: _keyCtrl.text.trim(),
      model: 'gemini-1.5-flash',
    );
    setState(() {
      _loading = false;
      _status = '✓ Key saved to encrypted local storage!';
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('API key saved!'),
        backgroundColor: JarvisTheme.success,
      ),
    );
  }

  @override
  void dispose() {
    _keyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: JarvisTheme.background,
      appBar: AppBar(
        backgroundColor: JarvisTheme.background,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: JarvisTheme.border),
            ),
            child: const Icon(Icons.arrow_back, color: JarvisTheme.primary, size: 18),
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'AI PROVIDER SETUP',
              style: TextStyle(
                color: JarvisTheme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
            Text(
              'BRING YOUR OWN KEY (BYOK)',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: 10,
                    letterSpacing: 1,
                  ),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: JarvisTheme.secondary),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'LOCAL PROFILE LINK',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: JarvisTheme.secondary,
                                fontSize: 10,
                                letterSpacing: 1.5,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text('Jarvis User',
                            style: Theme.of(context).textTheme.titleLarge),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: JarvisTheme.secondary,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'ISOLATED',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(
                    color: JarvisTheme.primary.withValues(alpha: 0.5)),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.auto_awesome,
                            color: Colors.blue, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Google Gemini AI',
                              style: TextStyle(
                                color: JarvisTheme.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              'Model: Gemini 1.5 Flash (Direct HTTPS)',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: JarvisTheme.success.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'SUP\nPOR\nTED',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: JarvisTheme.success,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            height: 1.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Your API key is used exclusively for requests initiated by this profile. '
                    'It is encrypted in AES-256-GCM and never transmitted to any shared servers.',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(height: 1.5),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'ENTER GOOGLE GEMINI API KEY',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: JarvisTheme.primary,
                    letterSpacing: 1.5,
                    fontSize: 11,
                  ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: JarvisTheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: JarvisTheme.border),
              ),
              child: TextField(
                controller: _keyCtrl,
                obscureText: !_showKey,
                style: const TextStyle(
                    color: JarvisTheme.textPrimary, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Gemini API Key (e.g. AIzaSy...)',
                  prefixIcon: const Icon(Icons.vpn_key_outlined,
                      color: JarvisTheme.primary),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.visibility_off_outlined),
                    onPressed: () => setState(() => _showKey = !_showKey),
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (_status != null)
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _verified
                      ? JarvisTheme.success.withValues(alpha: 0.1)
                      : JarvisTheme.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _verified
                        ? JarvisTheme.success.withValues(alpha: 0.4)
                        : JarvisTheme.error.withValues(alpha: 0.4),
                  ),
                ),
                child: Text(
                  _status!,
                  style: TextStyle(
                    color: _verified ? JarvisTheme.success : JarvisTheme.error,
                    fontSize: 13,
                  ),
                ),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _loading ? null : _verifyKey,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: JarvisTheme.border),
                      foregroundColor: JarvisTheme.textPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _loading
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child:
                                CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Verify Key'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _loading ? null : _saveKey,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: JarvisTheme.border),
                      foregroundColor: JarvisTheme.textPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Save Key'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: JarvisTheme.border),
                ),
                child: Text(
                  'SKIP FOR NOW (USE AUTONOMOUS ENGINE)',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: JarvisTheme.primary,
                        letterSpacing: 1,
                      ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: JarvisTheme.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: JarvisTheme.border),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.security,
                      color: JarvisTheme.primary, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SECURITY GUARANTEE',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: JarvisTheme.primary,
                                    fontSize: 11,
                                    letterSpacing: 1.5,
                                  ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '• Key stored in AES-256-GCM encrypted local storage\n'
                          '• Never sent to external servers\n'
                          '• Direct HTTPS to Google API only\n'
                          '• Deleted with profile permanently',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    height: 1.6,
                                    fontSize: 11,
                                  ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
