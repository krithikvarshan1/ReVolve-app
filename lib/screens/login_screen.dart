import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuthException;
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_text_field.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.firebaseMessage});

  final String? firebaseMessage;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _displayNameController = TextEditingController();
  bool _isSignUp = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasFirebaseMessage = widget.firebaseMessage != null;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0F172A),
              Color(0xFF1E3A8A),
              Color(0xFF0F766E),
            ],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -120,
              left: -80,
              child: _buildGlowCircle(
                size: 260,
                color: const Color(0x3322C55E),
              ),
            ),
            Positioned(
              right: -90,
              bottom: -130,
              child: _buildGlowCircle(
                size: 320,
                color: const Color(0x3340C4FF),
              ),
            ),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1100),
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xE6161C2D),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: Colors.white.withOpacity(0.08)),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x66030712),
                            blurRadius: 40,
                            offset: Offset(0, 24),
                          ),
                        ],
                      ),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final isWide = constraints.maxWidth >= 850;

                          return Padding(
                            padding: EdgeInsets.all(isWide ? 36 : 24),
                            child: Flex(
                              direction: isWide ? Axis.horizontal : Axis.vertical,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Padding(
                                    padding: EdgeInsets.only(
                                      right: isWide ? 32 : 0,
                                      bottom: isWide ? 0 : 32,
                                    ),
                                    child: _buildHeroSection(theme),
                                  ),
                                ),
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.all(28),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(24),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          _isSignUp ? 'Create your account' : 'Welcome back',
                                          style: theme.textTheme.headlineSmall?.copyWith(
                                            fontWeight: FontWeight.w700,
                                            color: const Color(0xFF111827),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          _isSignUp
                                              ? 'Start managing product operations with a secure workspace.'
                                              : 'Sign in to continue monitoring your product lifecycle.',
                                          style: theme.textTheme.bodyMedium?.copyWith(
                                            color: const Color(0xFF6B7280),
                                            height: 1.5,
                                          ),
                                        ),
                                        if (hasFirebaseMessage) ...[
                                          const SizedBox(height: 20),
                                          _buildFirebaseBanner(theme),
                                        ],
                                        const SizedBox(height: 24),
                                        if (_isSignUp) ...[
                                          CustomTextField(
                                            controller: _displayNameController,
                                            label: 'Display Name',
                                            icon: Icons.person_outline,
                                          ),
                                          const SizedBox(height: 16),
                                        ],
                                        CustomTextField(
                                          controller: _emailController,
                                          label: 'Email',
                                          icon: Icons.alternate_email_rounded,
                                          keyboardType: TextInputType.emailAddress,
                                        ),
                                        const SizedBox(height: 16),
                                        CustomTextField(
                                          controller: _passwordController,
                                          label: 'Password',
                                          icon: Icons.lock_outline_rounded,
                                          obscureText: true,
                                        ),
                                        const SizedBox(height: 24),
                                        CustomButton(
                                          text: _isSignUp ? 'Create Account' : 'Sign In',
                                          onPressed: _isLoading ? null : _handleAuth,
                                          isLoading: _isLoading,
                                          backgroundColor: const Color(0xFF1D4ED8),
                                          textColor: const Color(0xFFF8FAFC),
                                        ),
                                        const SizedBox(height: 18),
                                        Center(
                                          child: TextButton(
                                            onPressed: () => setState(() => _isSignUp = !_isSignUp),
                                            child: Text(
                                              _isSignUp
                                                  ? 'Already have an account? Sign In'
                                                  : 'Don\'t have an account? Sign Up',
                                              style: const TextStyle(
                                                color: Color(0xFF2563EB),
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Consumer<AuthProvider>(
                                          builder: (context, auth, _) {
                                            return SizedBox(
                                              width: double.infinity,
                                              child: OutlinedButton.icon(
                                                onPressed: auth.isLoading || hasFirebaseMessage
                                                    ? null
                                                    : _handleBiometricAuth,
                                                icon: const Icon(Icons.fingerprint_rounded),
                                                label: const Text('Biometric Login'),
                                                style: OutlinedButton.styleFrom(
                                                  foregroundColor: const Color(0xFF0F172A),
                                                  disabledForegroundColor: const Color(0xFF9CA3AF),
                                                  side: BorderSide(
                                                    color: hasFirebaseMessage
                                                        ? const Color(0xFFE5E7EB)
                                                        : const Color(0xFFCBD5E1),
                                                  ),
                                                  minimumSize: const Size.fromHeight(52),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(14),
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.12)),
          ),
          child: const Icon(
            Icons.engineering_rounded,
            size: 42,
            color: Color(0xFF7DD3FC),
          ),
        ),
        const SizedBox(height: 28),
        Text(
          'ReVolve',
          style: theme.textTheme.displaySmall?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.8,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'AI-powered product lifecycle management for teams that need clarity, control, and faster decisions.',
          style: theme.textTheme.titleMedium?.copyWith(
            color: Colors.white.withOpacity(0.88),
            height: 1.5,
          ),
        ),
        const SizedBox(height: 28),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: const [
            _FeatureChip(
              icon: Icons.insights_rounded,
              label: 'Predictive insights',
            ),
            _FeatureChip(
              icon: Icons.security_rounded,
              label: 'Secure authentication',
            ),
            _FeatureChip(
              icon: Icons.hub_rounded,
              label: 'Connected operations',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFirebaseBanner(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7D6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFBBF24)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 2),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFFFE08A),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.info_outline_rounded,
              color: Color(0xFF92400E),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Setup required',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: const Color(0xFF7C2D12),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.firebaseMessage!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF78350F),
                    height: 1.45,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlowCircle({
    required double size,
    required Color color,
  }) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
        ),
      ),
    );
  }

  Future<void> _handleAuth() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    if (_isSignUp && _displayNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a display name')),
      );
      return;
    }

    final email = _emailController.text.trim();
    if (!_isValidEmail(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid email address')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final auth = context.read<AuthProvider>();
      if (_isSignUp) {
        await auth.signUp(
          email,
          _passwordController.text,
          _displayNameController.text.trim(),
        );
      } else {
        await auth.signIn(
          email,
          _passwordController.text,
        );
      }

      // Navigation will be handled by the auth state listener in main.dart
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_authErrorMessage(e))),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  bool _isValidEmail(String email) {
    final regex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    return regex.hasMatch(email);
  }

  String _authErrorMessage(Object error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'user-not-found':
          return 'Only existing registered email addresses can sign in.';
        case 'wrong-password':
          return 'The password is incorrect.';
        case 'email-already-in-use':
          return 'This email address is already registered.';
        case 'invalid-email':
          return 'The email address format is invalid.';
      }
    }
    return 'Authentication failed. Please check your details and try again.';
  }

  Future<void> _handleBiometricAuth() async {
    if (widget.firebaseMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Configure Firebase first before using authentication.'),
        ),
      );
      return;
    }

    try {
      final auth = context.read<AuthProvider>();
      final success = await auth.authenticateWithBiometrics();
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Biometric authentication successful')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Biometric authentication failed')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Biometric authentication error: ${e.toString()}')),
      );
    }
  }
}

class _FeatureChip extends StatelessWidget {
  const _FeatureChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: const Color(0xFFBFDBFE)),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white.withOpacity(0.92),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
