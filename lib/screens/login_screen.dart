
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:work_sphere_ai/theme/glassmorphism.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _backendHealthy = false;
  bool _isCheckingBackend = true;

  @override
  void initState() {
    super.initState();
    _checkBackendHealth();
  }

  Future<void> _checkBackendHealth() async {
    if (!mounted) return;

    setState(() => _isCheckingBackend = true);

    bool isHealthy = false;

    try {
      final apiClient = ref.read(apiClientProvider);
      isHealthy = await apiClient.healthCheck();
    } catch (_) {
      isHealthy = false;
    }

    if (!mounted) return;

    setState(() {
      _backendHealthy = isHealthy;
      _isCheckingBackend = false;
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (_emailController.text.trim().isEmpty ||
        _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all fields'),
        ),
      );
      return;
    }

    if (!_backendHealthy) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Backend server is unavailable. Please try again later.',
          ),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    bool success = false;

    try {
      success = await ref.read(authProvider.notifier).login(
            _emailController.text.trim(),
            _passwordController.text,
          );
    } catch (_) {
      success = false;
    }

    if (!mounted) return;

    setState(() => _isLoading = false);

    if (success) {
      context.go('/dashboard');
    } else {
      final error = ref.read(authProvider).error;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error ?? 'Login failed. Please try again.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background image from the second design.
          Image.asset(
            'assets/AnalyticsInsights_HeaderImage_1000x750-768x576.jpg',
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                color: const Color(0xFF102A35),
              );
            },
          ),

          // Dark overlay for readable text.
          Container(
            color: Colors.black.withOpacity(0.20),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(
                        Icons.work_outline_rounded,
                        color: Colors.white,
                        size: 53,
                      ),

                      const SizedBox(height: 12),

                      const Text(
                        'WorkSphere AI',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 30,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 20),

                      const Text(
                        'Your workspace, all in one place.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),

                      const SizedBox(height: 25),

                      // Glassmorphism card.
                      GlassContainer(
                        width: double.infinity,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'Welcome back',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),

                            const SizedBox(height: 20),

                            const Text(
                              'Sign in to continue to your workspace.',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),

                            const SizedBox(height: 22),

                            // Backend connection status.
                            if (!_backendHealthy)
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.20),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.white24,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    if (_isCheckingBackend)
                                      const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    else
                                      const Icon(
                                        Icons.cloud_off_outlined,
                                        color: Colors.orangeAccent,
                                      ),

                                    const SizedBox(width: 10),

                                    Expanded(
                                      child: Text(
                                        _isCheckingBackend
                                            ? 'Checking server connection...'
                                            : 'Backend unavailable. Please retry.',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),

                                    if (!_isCheckingBackend)
                                      TextButton(
                                        onPressed: _checkBackendHealth,
                                        child: const Text(
                                          'Retry',
                                          style: TextStyle(
                                            color: Color(0xFF5EEAD4),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),

                            if (!_backendHealthy)
                              const SizedBox(height: 20),

                            // Email field.
                            TextField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              enabled: !_isLoading && _backendHealthy,
                              style: const TextStyle(
                                color: Colors.white,
                              ),
                              decoration: _inputDecoration(
                                hint: 'Email address',
                                icon: Icons.email_outlined,
                              ),
                            ),

                            const SizedBox(height: 18),

                            // Password field.
                            TextField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              textInputAction: TextInputAction.done,
                              enabled: !_isLoading && _backendHealthy,
                              onSubmitted: (_) {
                                if (!_isLoading && _backendHealthy) {
                                  _handleLogin();
                                }
                              },
                              style: const TextStyle(
                                color: Colors.white,
                              ),
                              decoration: _inputDecoration(
                                hint: 'Password',
                                icon: Icons.lock_outline_rounded,
                              ).copyWith(
                                suffixIcon: IconButton(
                                  tooltip: _obscurePassword
                                      ? 'Show password'
                                      : 'Hide password',
                                  onPressed: () {
                                    setState(() {
                                      _obscurePassword =
                                          !_obscurePassword;
                                    });
                                  },
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    color: Colors.white70,
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 8),

                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: null,
                                child: Text(
                                  'Forgot password?',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.85),
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 8),

                            // Actual backend login action.
                            SizedBox(
                              height: 53,
                              child: ElevatedButton(
                                onPressed: (!_isLoading && _backendHealthy)
                                    ? _handleLogin
                                    : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      const Color(0xFF14B8A6),
                                  foregroundColor: Colors.white,
                                  disabledBackgroundColor:
                                      Colors.white24,
                                  disabledForegroundColor: Colors.white60,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(13),
                                  ),
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text(
                                        'Sign In',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                              ),
                            ),

                            const SizedBox(height: 18),

                            // Registration navigation.
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Flexible(
                                  child: Text(
                                    "Don't have an account?",
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () {
                                    context.push('/register');
                                  },
                                  child: const Text(
                                    'Create account',
                                    style: TextStyle(
                                      color: Color(0xFF5EEAD4),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 23),

                      const Text(
                        'Secure access for your team',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Shared styling for the email and password fields.
  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        color: Colors.white70,
      ),
      prefixIcon: Icon(
        icon,
        color: Colors.white70,
      ),
      filled: true,
      fillColor: Colors.white.withOpacity(0.12),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 17,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: BorderSide(
          color: Colors.white.withOpacity(0.30),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: BorderSide(
          color: Colors.white.withOpacity(0.30),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(
          color: Color(0xFF5EEAD4),
          width: 1.5,
        ),
      ),
    );
  }
}
