import 'dart:ui';

import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuthException;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';

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
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasFirebaseMessage = widget.firebaseMessage != null;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      body: Stack(
        children: [
          const _PageBackdrop(),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, viewport) {
                final shouldScroll = viewport.maxWidth < 980;

                final content = ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1250),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth >= 980;

                      return Container(
                        padding: EdgeInsets.all(isWide ? 22 : 14),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(34),
                          color: Colors.white.withOpacity(0.36),
                          border: Border.all(color: Colors.white.withOpacity(0.8)),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x1E1D4ED8),
                              blurRadius: 42,
                              offset: Offset(0, 22),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(28),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0xFFF8FAFC),
                                    Color(0xFFF0F7FF),
                                    Color(0xFFEAF1FF),
                                  ],
                                ),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.85),
                                ),
                              ),
                              child: Stack(
                                children: [
                                  const Positioned.fill(child: _SceneArtwork()),
                                  Padding(
                                    padding: EdgeInsets.fromLTRB(
                                      isWide ? 30 : 18,
                                      isWide ? 22 : 16,
                                      isWide ? 30 : 18,
                                      isWide ? 26 : 18,
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.max,
                                      children: [
                                        _TopBar(isWide: isWide),
                                        SizedBox(height: isWide ? 30 : 22),
                                        if (isWide)
                                          Expanded(
                                            child: Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.stretch,
                                              children: [
                                                Expanded(
                                                  flex: 11,
                                                  child: _buildHeroContent(),
                                                ),
                                                const SizedBox(width: 22),
                                                Expanded(
                                                  flex: 7,
                                                  child: _buildAuthCard(
                                                    context,
                                                    hasFirebaseMessage:
                                                        hasFirebaseMessage,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          )
                                        else
                                          Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              _buildHeroContent(),
                                              const SizedBox(height: 22),
                                              _buildAuthCard(
                                                context,
                                                hasFirebaseMessage:
                                                    hasFirebaseMessage,
                                              ),
                                            ],
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                );

                if (shouldScroll) {
                  return Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                      child: content,
                    ),
                  );
                }

                return Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                    child: SizedBox(
                      height: viewport.maxHeight - 48,
                      child: content,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroContent() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 8, 6, 0),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520),
        padding: const EdgeInsets.fromLTRB(18, 18, 20, 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withOpacity(0.42),
              Colors.white.withOpacity(0.18),
            ],
          ),
          border: Border.all(color: Colors.white.withOpacity(0.72)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14446EBA),
              blurRadius: 20,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.65),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white.withOpacity(0.92)),
              ),
              child: const Text(
                'NEXT GENERATION WORKFLOW',
                style: TextStyle(
                  color: Color(0xFF597BB3),
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                  letterSpacing: 1,
                ),
              ),
            ),
            const SizedBox(height: 28),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 470),
              child: const Text(
                'A calmer workspace for industrial control, predictive insight, and team access.',
                style: TextStyle(
                  fontSize: 42,
                  height: 1.08,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -1.4,
                  color: Color(0xFF264B84),
                ),
              ),
            ),
            const SizedBox(height: 18),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 410),
              child: const Text(
                'Sign in to monitor devices, lifecycle signals, and team activity from one polished control center.',
                style: TextStyle(
                  color: Color(0xFF5E7CAA),
                  fontSize: 15,
                  height: 1.7,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 26),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: const [
                _MiniPill(label: 'Live dashboards'),
                _MiniPill(label: 'Secure access'),
                _MiniPill(label: 'Predictive models'),
              ],
            ),
            const SizedBox(height: 26),
          ],
        ),
      ),
    );
  }

  Widget _buildAuthCard(
    BuildContext context, {
    required bool hasFirebaseMessage,
  }) {
    final theme = Theme.of(context);

    return Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withOpacity(0.98)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x186B8FD6),
                blurRadius: 32,
                offset: Offset(0, 18),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isSignUp ? 'Create Account' : 'Welcome Back',
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: const Color(0xFF1E3A8A),
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.6,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _isSignUp
                    ? 'Create your ReVolve access and join your team workspace.'
                    : 'Use your credentials to continue into the control suite.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF64748B),
                  height: 1.6,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (hasFirebaseMessage) ...[
                const SizedBox(height: 18),
                _buildFirebaseBanner(theme),
              ],
              const SizedBox(height: 20),
              if (_isSignUp) ...[
                _AuthField(
                  controller: _displayNameController,
                  label: 'Display Name',
                  hint: 'Your team-facing name',
                  icon: Icons.person_outline_rounded,
                ),
                const SizedBox(height: 14),
              ],
              _AuthField(
                controller: _emailController,
                label: 'Email',
                hint: 'name@company.com',
                icon: Icons.alternate_email_rounded,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 14),
              _AuthField(
                controller: _passwordController,
                label: 'Password',
                hint: 'Enter your password',
                icon: Icons.lock_outline_rounded,
                obscureText: _obscurePassword,
                suffix: IconButton(
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: const Color(0xFF64748B),
                  ),
                ),
                onSubmitted: (_) => _handleAuth(),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF1D4ED8),
                        Color(0xFF2563EB),
                      ],
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x332563EB),
                        blurRadius: 18,
                        offset: Offset(0, 10),
                      ),
                    ],
                  ),
                  child: FilledButton(
                    onPressed: _isLoading ? null : _handleAuth,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      minimumSize: const Size.fromHeight(54),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.1,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : Text(
                            _isSignUp ? 'Create Account' : 'Sign In',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.2,
                            ),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _isLoading || hasFirebaseMessage
                      ? null
                      : _handleGoogleSignIn,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF334155),
                    minimumSize: const Size.fromHeight(50),
                    side: const BorderSide(color: Color(0xFFDBE4F0)),
                    backgroundColor: Colors.white.withOpacity(0.7),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      _GoogleBadge(),
                      SizedBox(width: 10),
                      Text(
                        'Continue with Google',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Consumer<AuthProvider>(
                builder: (context, auth, _) {
                  return SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: auth.isLoading || hasFirebaseMessage
                          ? null
                          : _handleBiometricAuth,
                      icon: const Icon(Icons.fingerprint_rounded, size: 18),
                      label: const Text('Biometric Login'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF475569),
                        minimumSize: const Size.fromHeight(50),
                        side: const BorderSide(color: Color(0xFFDBE4F0)),
                        backgroundColor: Colors.white.withOpacity(0.55),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              Align(
                child: TextButton(
                  onPressed: () {
                    setState(() {
                      _isSignUp = !_isSignUp;
                    });
                  },
                  child: Text(
                    _isSignUp
                        ? 'Already have an account? Sign in'
                        : 'Need an account? Create one',
                    style: const TextStyle(
                      color: Color(0xFF475569),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFirebaseBanner(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7DB).withOpacity(0.92),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF6D37B)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFFFEAAB),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.info_outline_rounded,
              size: 18,
              color: Color(0xFFA16207),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Setup required',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: const Color(0xFF8A580C),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.firebaseMessage!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF9A670F),
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
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_authErrorMessage(e))),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  bool _isValidEmail(String email) {
    final regex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    return regex.hasMatch(email);
  }

  String _authErrorMessage(Object error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'popup-closed-by-user':
        case 'sign-in-cancelled':
          return 'Google sign-in was cancelled.';
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

  Future<void> _handleGoogleSignIn() async {
    if (widget.firebaseMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Configure Firebase first before using authentication.'),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await context.read<AuthProvider>().signInWithGoogle();
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_authErrorMessage(e))),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
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
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Biometric authentication successful'
                : 'Biometric authentication failed',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Biometric authentication error: ${e.toString()}')),
      );
    }
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.isWide});

  final bool isWide;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Row(
          children: const [
            Icon(
              Icons.blur_on_rounded,
              size: 22,
              color: Color(0xFF1D4ED8),
            ),
            SizedBox(width: 8),
            Text(
              'ReVolve',
              style: TextStyle(
                color: Color(0xFF0F172A),
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
          ],
        ),
        const Spacer(),
        if (isWide) ...const [
          _NavLink(label: 'Product'),
          SizedBox(width: 20),
          _NavLink(label: 'Pricing'),
          SizedBox(width: 20),
          _NavLink(label: 'Company'),
          SizedBox(width: 20),
          _NavLink(label: 'Docs'),
          SizedBox(width: 20),
          _NavLink(label: 'Blog'),
          SizedBox(width: 24),
        ],
        Container(
          decoration: const BoxDecoration(
            borderRadius: BorderRadius.all(Radius.circular(999)),
            gradient: LinearGradient(
              colors: [
                Color(0xFF1D4ED8),
                Color(0xFF2563EB),
              ],
            ),
          ),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Text(
              'Contact Us',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _GoogleBadge extends StatelessWidget {
  const _GoogleBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFD4DEEE)),
      ),
      alignment: Alignment.center,
      child: const Text(
        'G',
        style: TextStyle(
          fontWeight: FontWeight.w800,
          color: Color(0xFFDB4437),
          fontSize: 12,
        ),
      ),
    );
  }
}

class _NavLink extends StatelessWidget {
  const _NavLink({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: Color(0xCC627DAA),
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _MiniPill extends StatelessWidget {
  const _MiniPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Colors.white.withOpacity(0.72),
        border: Border.all(color: Colors.white.withOpacity(0.95)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF5F7FB3),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _PageBackdrop extends StatelessWidget {
  const _PageBackdrop();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFF7FAFC),
            Color(0xFFEAF2FF),
          ],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: const [
          Positioned(
            top: -70,
            left: -50,
            child: _BlurOrb(
              size: 260,
              color: Color(0x5581AFFF),
            ),
          ),
          Positioned(
            right: -90,
            bottom: 20,
            child: _BlurOrb(
              size: 280,
              color: Color(0x55B7D7FF),
            ),
          ),
          Positioned(
            left: 30,
            bottom: 40,
            child: _BlurOrb(
              size: 120,
              color: Color(0x66FFFFFF),
            ),
          ),
        ],
      ),
    );
  }
}

class _BlurOrb extends StatelessWidget {
  const _BlurOrb({
    required this.size,
    required this.color,
  });

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color,
              color.withOpacity(0),
            ],
          ),
        ),
      ),
    );
  }
}

class _SceneArtwork extends StatelessWidget {
  const _SceneArtwork();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _ScenePainter(),
      child: Container(),
    );
  }
}

class _ScenePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final floorPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0x00000000),
          Color(0x404AA6FF),
          Color(0x70A3CCFF),
        ],
      ).createShader(
        Rect.fromLTWH(0, size.height * 0.52, size.width, size.height * 0.48),
      );

    final floorPath = Path()
      ..moveTo(0, size.height * 0.58)
      ..quadraticBezierTo(
        size.width * 0.25,
        size.height * 0.53,
        size.width * 0.46,
        size.height * 0.62,
      )
      ..quadraticBezierTo(
        size.width * 0.7,
        size.height * 0.71,
        size.width,
        size.height * 0.58,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(floorPath, floorPaint);

    final wavePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.8);

    final waveColors = [
      const Color(0x804EA4FF),
      const Color(0x6654B8FF),
      const Color(0x4D8DD4FF),
    ];

    for (var i = 0; i < 4; i++) {
      wavePaint
        ..color = waveColors[i % waveColors.length]
        ..strokeWidth = 2.0 + i * 0.7;

      final y = size.height * (0.34 + i * 0.03);
      final path = Path()
        ..moveTo(-20, y)
        ..cubicTo(
          size.width * 0.16,
          y - 26,
          size.width * 0.3,
          y + 28,
          size.width * 0.47,
          y + 6,
        )
        ..cubicTo(
          size.width * 0.62,
          y - 18,
          size.width * 0.78,
          y + 18,
          size.width + 30,
          y - 8,
        );
      canvas.drawPath(path, wavePaint);
    }

    final gridPaint = Paint()
      ..color = const Color(0x335A90D8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final baseY = size.height * 0.72;
    for (var i = 0; i < 10; i++) {
      final x = size.width * i / 9;
      canvas.drawLine(
        Offset(x, baseY),
        Offset(size.width * 0.48 + (x - size.width * 0.48) * 1.3, size.height),
        gridPaint,
      );
    }
    for (var i = 0; i < 6; i++) {
      final y = baseY + i * ((size.height - baseY) / 5);
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        gridPaint,
      );
    }

    final cubeRect = Rect.fromCenter(
      center: Offset(size.width * 0.64, size.height * 0.58),
      width: size.width * 0.18,
      height: size.height * 0.28,
    );

    final cubeFill = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withOpacity(0.95),
          const Color(0xDDF4F8FF),
          const Color(0x99D3E5FF),
        ],
      ).createShader(cubeRect);

    final cubeStroke = Paint()
      ..color = const Color(0x4D8DB4E8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final cube = RRect.fromRectAndRadius(cubeRect, const Radius.circular(12));
    canvas.drawRRect(cube, cubeFill);
    canvas.drawRRect(cube, cubeStroke);

    final smallCubeRect = Rect.fromCenter(
      center: Offset(size.width * 0.83, size.height * 0.67),
      width: size.width * 0.05,
      height: size.height * 0.08,
    );
    final smallCube = RRect.fromRectAndRadius(
      smallCubeRect,
      const Radius.circular(8),
    );
    canvas.drawRRect(
      smallCube,
      Paint()..color = Colors.white.withOpacity(0.6),
    );
    canvas.drawRRect(smallCube, cubeStroke);

    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0x66A5D3FF),
          const Color(0x00A5D3FF),
        ],
      ).createShader(
        Rect.fromCircle(
          center: Offset(size.width * 0.58, size.height * 0.45),
          radius: size.width * 0.24,
        ),
      );
    canvas.drawCircle(
      Offset(size.width * 0.58, size.height * 0.45),
      size.width * 0.24,
      glowPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _AuthField extends StatelessWidget {
  const _AuthField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.keyboardType,
    this.obscureText = false,
    this.suffix,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? suffix;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      onSubmitted: onSubmitted,
      style: const TextStyle(
        color: Color(0xFF0F172A),
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: const Color(0xFF64748B)),
        suffixIcon: suffix,
        labelStyle: const TextStyle(
          color: Color(0xFF64748B),
          fontWeight: FontWeight.w600,
        ),
        hintStyle: const TextStyle(
          color: Color(0x8094A3B8),
        ),
        filled: true,
        fillColor: Colors.white.withOpacity(0.72),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: Color(0xFFD8E2EF)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: Color(0xFFD8E2EF)),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
          borderSide: BorderSide(
            color: Color(0xFF1D4ED8),
            width: 1.4,
          ),
        ),
      ),
    );
  }
}
