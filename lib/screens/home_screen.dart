import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../utils/theme.dart';
import 'chat_screen.dart';
import 'api_setup_screen.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  Map<String, dynamic>? _session;
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _loadSession();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  Future<void> _loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('active_session');
    if (data != null) {
      setState(() => _session = jsonDecode(data));
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('active_session');
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: JarvisTheme.background,
      appBar: AppBar(
        backgroundColor: JarvisTheme.background,
        elevation: 0,
        title: Row(
          children: [
            const Icon(Icons.circle, color: JarvisTheme.success, size: 10),
            const SizedBox(width: 6),
            Text(
              'JARVIS CORE // ONLINE',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: JarvisTheme.success,
                    letterSpacing: 1.5,
                    fontSize: 11,
                  ),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.account_circle_outlined,
                color: JarvisTheme.primary),
            color: JarvisTheme.surface,
            onSelected: (v) {
              if (v == 'logout') _logout();
              if (v == 'api') {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ApiSetupScreen()),
                );
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'api',
                child: Row(
                  children: [
                    const Icon(Icons.key_outlined,
                        color: JarvisTheme.primary, size: 18),
                    const SizedBox(width: 10),
                    Text('AI Provider Setup',
                        style: Theme.of(context).textTheme.bodyLarge),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    const Icon(Icons.logout,
                        color: JarvisTheme.error, size: 18),
                    const SizedBox(width: 10),
                    Text('Logout',
                        style: Theme.of(context)
                            .textTheme
                            .bodyLarge
                            ?.copyWith(color: JarvisTheme.error)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: _buildNavBar(),
    );
  }

  Widget _buildBody() {
    switch (_currentIndex) {
      case 0:
        return _buildHome();
      case 1:
        return const Center(
          child: Text('Vision', style: TextStyle(color: JarvisTheme.textPrimary)),
        );
      case 2:
        return const Center(
          child: Text('Skills', style: TextStyle(color: JarvisTheme.textPrimary)),
        );
      case 3:
        return const ChatScreen();
      default:
        return _buildHome();
    }
  }

  Widget _buildHome() {
    return Column(
      children: [
        // Weather & Date bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: JarvisTheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: JarvisTheme.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.wb_sunny_outlined,
                          color: JarvisTheme.warning, size: 20),
                      const SizedBox(width: 8),
                      Text('--°C',
                          style: Theme.of(context).textTheme.titleLarge),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: JarvisTheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: JarvisTheme.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_month_outlined,
                          color: JarvisTheme.primary, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        '${DateTime.now().day} Nov',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // Voice orb
        Expanded(
          child: Center(
            child: GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ChatScreen()),
                );
              },
              child: AnimatedBuilder(
                animation: _pulseAnim,
                builder: (_, child) => Transform.scale(
                  scale: _pulseAnim.value,
                  child: child,
                ),
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        JarvisTheme.secondary.withOpacity(0.6),
                        JarvisTheme.primary.withOpacity(0.3),
                        Colors.transparent,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: JarvisTheme.primary.withOpacity(0.3),
                        blurRadius: 40,
                        spreadRadius: 10,
                      ),
                      BoxShadow(
                        color: JarvisTheme.secondary.withOpacity(0.2),
                        blurRadius: 60,
                        spreadRadius: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),

        const Text(
          'Tap the voice button to start',
          style: TextStyle(color: JarvisTheme.textSecondary),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildNavBar() {
    return NavigationBar(
      backgroundColor: JarvisTheme.surface,
      indicatorColor: JarvisTheme.primary.withOpacity(0.2),
      selectedIndex: _currentIndex,
      onDestinationSelected: (i) => setState(() => _currentIndex = i),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home, color: JarvisTheme.primary),
          label: 'Home',
        ),
        NavigationDestination(
          icon: Icon(Icons.camera_alt_outlined),
          selectedIcon: Icon(Icons.camera_alt, color: JarvisTheme.primary),
          label: 'Vision',
        ),
        NavigationDestination(
          icon: Icon(Icons.flash_on_outlined),
          selectedIcon: Icon(Icons.flash_on, color: JarvisTheme.primary),
          label: 'Skills',
        ),
        NavigationDestination(
          icon: Icon(Icons.chat_bubble_outline),
          selectedIcon: Icon(Icons.chat_bubble, color: JarvisTheme.primary),
          label: 'Chat',
        ),
      ],
    );
  }
}
