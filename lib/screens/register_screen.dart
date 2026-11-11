import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../utils/theme.dart';
import '../services/database_service.dart';
import 'home_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _showPass = false;
  bool _showConfirm = false;
  bool _rememberSession = true;
  bool _loading = false;
  String? _errorMsg;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _createProfile() async {
    if (!_formKey.currentState!.validate()) return;
    if (_passCtrl.text != _confirmCtrl.text) {
      setState(() => _errorMsg = 'পাসওয়ার্ড মিলছে না।');
      return;
    }
    setState(() {
      _loading = true;
      _errorMsg = null;
    });
    try {
      final exists = await DatabaseService.emailExists(_emailCtrl.text);
      if (exists) {
        setState(() {
          _errorMsg = 'এই ইমেইল দিয়ে আগেই প্রোফাইল আছে।';
          _loading = false;
        });
        return;
      }
      final id = await DatabaseService.createProfile(
        fullName: _nameCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text,
        rememberSession: _rememberSession,
      );
      if (_rememberSession) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('active_session', jsonEncode({
          'profile_id': id,
          'name': _nameCtrl.text.trim(),
          'email': _emailCtrl.text.trim(),
        }));
      }
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
      );
    } catch (e) {
      setState(() {
        _errorMsg = 'ত্রুটি: ${e.toString()}';
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
              const SizedBox(height: 20),
              _buildLogoHeader(),
              const SizedBox(height: 32),
              _buildInfoBox(),
              const SizedBox(height: 24),
              _buildForm(),
              const SizedBox(height: 24),
              if (_errorMsg != null) _buildError(),
              const SizedBox(height: 16),
              _buildCreateButton(),
              const SizedBox(height: 20),
              _buildLoginLink(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogoHeader() {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: JarvisTheme.primary.withValues(alpha: 0.5),
              width: 2,
            ),
            gradient: RadialGradient(
              colors: [
                JarvisTheme.primary.withValues(alpha: 0.15),
                Colors.transparent,
              ],
            ),
          ),
          child: const Icon(
            Icons.person_add_outlined,
            color: JarvisTheme.primary,
            size: 36,
          ),
        ),
        const SizedBox(height: 16),
        Text('NEW LOCAL PROFILE',
            style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 4),
        Text(
          'INITIALIZE ISOLATED ON-DEVICE USER',
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(letterSpacing: 1.5),
        ),
      ],
    );
  }

  Widget _buildInfoBox() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: JarvisTheme.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: JarvisTheme.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline,
              color: JarvisTheme.primary, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'LOCAL-ONLY REGISTRATION: This account is created and stored '
              'exclusively on your device. It does not sync to cloud servers. '
              'Password is protected with salted SHA-256 hashing.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: 11,
                    height: 1.5,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          TextFormField(
            controller: _nameCtrl,
            style: const TextStyle(color: JarvisTheme.textPrimary),
            decoration: const InputDecoration(
              hintText: 'Full Name',
              prefixIcon: Icon(Icons.badge_outlined),
            ),
            validator: (v) =>
                (v?.trim().isEmpty ?? true) ? 'নাম দিন' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            style: const TextStyle(color: JarvisTheme.textPrimary),
            decoration: const InputDecoration(
              hintText: 'Local Email Identifier',
              prefixIcon: Icon(Icons.email_outlined),
            ),
            validator: (v) {
              if (v?.trim().isEmpty ?? true) return 'ইমেইল দিন';
              if (!v!.contains('@')) return 'সঠিক ইমেইল দিন';
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _passCtrl,
            obscureText: !_showPass,
            style: const TextStyle(color: JarvisTheme.textPrimary),
            decoration: InputDecoration(
              hintText: 'Master Password (min 6 chars)',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(_showPass
                    ? Icons.visibility_off
                    : Icons.visibility_off_outlined),
                onPressed: () =>
                    setState(() => _showPass = !_showPass),
              ),
            ),
            validator: (v) =>
                (v?.length ?? 0) < 6 ? 'কমপক্ষে ৬ অক্ষর দিন' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _confirmCtrl,
            obscureText: !_showConfirm,
            style: const TextStyle(color: JarvisTheme.textPrimary),
            decoration: InputDecoration(
              hintText: 'Confirm Master Password',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: const Icon(Icons.visibility_off_outlined),
                onPressed: () =>
                    setState(() => _showConfirm = !_showConfirm),
              ),
            ),
            validator: (v) =>
                v != _passCtrl.text ? 'পাসওয়ার্ড মিলছে না' : null,
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Remember this device session',
                  style: Theme.of(context).textTheme.bodyLarge),
              Switch(
                value: _rememberSession,
                onChanged: (v) =>
                    setState(() => _rememberSession = v),
                activeColor: JarvisTheme.primary,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: JarvisTheme.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: JarvisTheme.error.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline,
              color: JarvisTheme.error, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _errorMsg!,
              style: const TextStyle(
                  color: JarvisTheme.error, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreateButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _loading ? null : _createProfile,
        child: _loading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.black),
              )
            : const Text('CREATE LOCAL PROFILE'),
      ),
    );
  }

  Widget _buildLoginLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('Already have a profile on this device? ',
            style: Theme.of(context).textTheme.bodyMedium),
        GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: const Text(
            'Log In',
            style: TextStyle(
                color: JarvisTheme.primary, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}
