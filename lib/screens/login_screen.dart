import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../utils/theme.dart';
import '../services/database_service.dart';
import 'register_screen.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _showPass = false;
  bool _rememberSession = true;
  bool _loading = false;
  String? _errorMsg;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_emailCtrl.text.trim().isEmpty || _passCtrl.text.isEmpty) {
      setState(() => _errorMsg = 'ইমেইল এবং পাসওয়ার্ড দিন।');
      return;
    }

    setState(() {
      _loading = true;
      _errorMsg = null;
    });

    try {
      final profile = await DatabaseService.authenticateProfile(
        email: _emailCtrl.text,
        password: _passCtrl.text,
      );

      if (profile == null) {
        setState(() {
          _errorMsg = 'ইমেইল বা পাসওয়ার্ড ভুল।';
          _loading = false;
        });
        return;
      }

      if (_rememberSession) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('active_session', jsonEncode({
          'profile_id': profile['id'],
          'name': profile['full_name'],
          'email': profile['email'],
        }));
      }

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
      );
    } catch (e) {
      setState(() {
        _errorMsg = 'ত্রুটি হয়েছে।';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: JarvisTheme.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 40),
              _buildLogo(),
              const SizedBox(height: 40),
              _buildCard(),
              const SizedBox(height: 20),
              _buildCreateLink(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Column(
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: JarvisTheme.primary.withOpacity(0.4),
              width: 2,
            ),
          ),
          child: Center(
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: JarvisTheme.primary.withOpacity(0.1),
                border: Border.all(color: JarvisTheme.primary, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: JarvisTheme.primary.withOpacity(0.3),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: const Icon(Icons.add, color: JarvisTheme.primary, size: 30),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'JARVIS ACCESS PORTAL',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontSize: 20,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          'LOCAL DEVICE AUTHENTICATION MATRIX',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                letterSpacing: 1.5,
              ),
        ),
      ],
    );
  }

  Widget _buildCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: JarvisTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: JarvisTheme.border),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: JarvisTheme.surfaceVariant,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: JarvisTheme.border),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline,
                    color: JarvisTheme.primary, size: 16),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'LOCAL AUTHENTICATION: Profile records reside strictly in encrypted on-device SQLite storage. Not a cloud account. No server identity or password recovery.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontSize: 11,
                          height: 1.5,
                        ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            style: const TextStyle(color: JarvisTheme.textPrimary),
            decoration: const InputDecoration(
              hintText: 'Local Email Address',
              prefixIcon: Icon(Icons.email_outlined),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _passCtrl,
            obscureText: !_showPass,
            style: const TextStyle(color: JarvisTheme.textPrimary),
            decoration: InputDecoration(
              hintText: 'Local Master Password',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: const Icon(Icons.visibility_off_outlined),
                onPressed: () => setState(() => _showPass = !_showPass),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Remember this device session',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              Switch(
                value: _rememberSession,
                onChanged: (v) => setState(() => _rememberSession = v),
                activeColor: JarvisTheme.primary,
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_errorMsg != null) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: JarvisTheme.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: JarvisTheme.error.withOpacity(0.4)),
              ),
              child: Text(
                _errorMsg!,
                style: const TextStyle(color: JarvisTheme.error, fontSize: 12),
              ),
            ),
            const SizedBox(height: 8),
          ],
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _loading ? null : _login,
              child: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.black,
                      ),
                    )
                  : const Text('AUTHENTICATE // ACCESS JARVIS'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreateLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'No profile on this device? ',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        GestureDetector(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const RegisterScreen()),
          ),
          child: const Text(
            'Create Profile',
            style: TextStyle(
              color: JarvisTheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}
