import 'dart:math' as math;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_text_field.dart';
import 'criar_conta_screen.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _authService = AuthService();
  final _emailController = TextEditingController();
  final _senhaController = TextEditingController();
  bool _isLoading = false;

  Future<void> _login() async {
    if (_emailController.text.isEmpty || _senhaController.text.isEmpty) {
      _showMessage('Preencha o e-mail e a senha.');
      return;
    }
    setState(() => _isLoading = true);
    try {
      await _authService.signIn(_emailController.text, _senhaController.text);
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (_) => false,
      );
    } on FirebaseAuthException catch (e) {
      final message = switch (e.code) {
        'user-not-found' ||
        'wrong-password' ||
        'invalid-credential' => 'E-mail ou senha incorretos.',
        _ => 'Nao foi possivel entrar. Tente novamente.',
      };
      _showMessage(message);
    } on FirebaseException catch (e) {
      _showMessage(
        'Login autenticado, mas nao foi possivel carregar seu perfil: ${e.message ?? e.code}',
      );
    } catch (e) {
      _showMessage('Nao foi possivel entrar. $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resetPassword() async {
    if (_emailController.text.isEmpty) {
      _showMessage('Informe seu e-mail para recuperar a senha.');
      return;
    }
    await _authService.sendPasswordReset(_emailController.text);
    _showMessage('Enviamos um link de recuperacao para seu e-mail.');
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _emailController.dispose();
    _senhaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const _AnimatedLoginBackground(),
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(26, 18, 26, 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _LoginBrandMark(),
                        const Spacer(),
                        const Text(
                          'Bem-vindo\nde volta',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 34,
                            height: 0.98,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Entre para acompanhar talentos, oportunidades e conversas.',
                          style: TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.w700,
                            height: 1.25,
                          ),
                        ),
                        const SizedBox(height: 18),
                        const _LiveScoutingBadge(),
                        const Spacer(),
                      ],
                    ),
                  ),
                ),
                _LoginFormPanel(
                  emailController: _emailController,
                  senhaController: _senhaController,
                  isLoading: _isLoading,
                  onLogin: _login,
                  onResetPassword: _resetPassword,
                  onCreateAccount: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const CriarContaScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LoginBrandMark extends StatelessWidget {
  const _LoginBrandMark();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
          ),
          child: const Icon(Icons.sports_soccer, color: Colors.white, size: 24),
        ),
        const SizedBox(width: 10),
        const Text(
          'FutConecta',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 18,
          ),
        ),
      ],
    );
  }
}

class _LiveScoutingBadge extends StatelessWidget {
  const _LiveScoutingBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.trending_up, color: AppColors.gold, size: 18),
          SizedBox(width: 7),
          Text(
            'scouting em tempo real',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _LoginFormPanel extends StatelessWidget {
  const _LoginFormPanel({
    required this.emailController,
    required this.senhaController,
    required this.isLoading,
    required this.onLogin,
    required this.onResetPassword,
    required this.onCreateAccount,
  });

  final TextEditingController emailController;
  final TextEditingController senhaController;
  final bool isLoading;
  final VoidCallback onLogin;
  final VoidCallback onResetPassword;
  final VoidCallback onCreateAccount;

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: _LoginPanelClipper(),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(24, 54, 24, 24),
        color: AppColors.background,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Entrar',
              style: TextStyle(
                fontSize: 27,
                fontWeight: FontWeight.w900,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Use seu acesso para continuar.',
              style: TextStyle(
                color: AppColors.muted,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 18),
            AppTextField(
              controller: emailController,
              label: 'E-mail',
              icon: Icons.mail_outline,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: senhaController,
              label: 'Senha',
              icon: Icons.lock_outline,
              obscureText: true,
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: isLoading ? null : onResetPassword,
                child: const Text('Esqueceu a senha?'),
              ),
            ),
            ElevatedButton(
              onPressed: isLoading ? null : onLogin,
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Entrar'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: onCreateAccount,
              child: const Text('Criar cadastro'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoginPanelClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    return Path()
      ..moveTo(0, 42)
      ..cubicTo(size.width * 0.22, 0, size.width * 0.72, 78, size.width, 34)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _AnimatedLoginBackground extends StatefulWidget {
  const _AnimatedLoginBackground();

  @override
  State<_AnimatedLoginBackground> createState() =>
      _AnimatedLoginBackgroundState();
}

class _AnimatedLoginBackgroundState extends State<_AnimatedLoginBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 9),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return CustomPaint(
          painter: _LoginBackgroundPainter(progress: _controller.value),
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.primaryDark,
                  AppColors.primary,
                  AppColors.scout,
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _LoginBackgroundPainter extends CustomPainter {
  const _LoginBackgroundPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress * math.pi * 2;

    final wavePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..style = PaintingStyle.fill;
    final wavePath = Path()
      ..moveTo(0, size.height * 0.18)
      ..cubicTo(
        size.width * 0.24,
        size.height * (0.08 + 0.02 * math.sin(t)),
        size.width * 0.46,
        size.height * 0.31,
        size.width,
        size.height * (0.18 + 0.02 * math.cos(t)),
      )
      ..lineTo(size.width, size.height * 0.54)
      ..cubicTo(
        size.width * 0.72,
        size.height * (0.43 + 0.02 * math.sin(t)),
        size.width * 0.42,
        size.height * 0.62,
        0,
        size.height * (0.49 + 0.02 * math.cos(t)),
      )
      ..close();
    canvas.drawPath(wavePath, wavePaint);

    _drawBlob(
      canvas,
      Offset(
        size.width * (0.2 + 0.02 * math.sin(t)),
        size.height * (0.23 + 0.02 * math.cos(t)),
      ),
      size.width * 0.28,
      AppColors.accent.withValues(alpha: 0.14),
    );
    _drawBlob(
      canvas,
      Offset(
        size.width * (0.78 + 0.02 * math.cos(t)),
        size.height * (0.12 + 0.02 * math.sin(t)),
      ),
      size.width * 0.2,
      AppColors.scout.withValues(alpha: 0.16),
    );

    final dotPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.11)
      ..style = PaintingStyle.fill;
    for (var i = 0; i < 7; i++) {
      final x = size.width * (0.16 + (i * 0.12) % 0.72);
      final y = size.height * (0.1 + (i * 0.075) % 0.34) + 8 * math.sin(t + i);
      canvas.drawCircle(Offset(x, y), 5 + (i % 3) * 4, dotPaint);
    }

    final fieldPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.09)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final top = size.height * 0.11;
    final bottom = size.height * 0.58;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(size.width * 0.07, top, size.width * 0.93, bottom),
        const Radius.circular(18),
      ),
      fieldPaint,
    );
    canvas.drawCircle(
      Offset(size.width / 2, (top + bottom) / 2),
      size.width * 0.13,
      fieldPaint,
    );
  }

  void _drawBlob(Canvas canvas, Offset center, double radius, Color color) {
    final paint = Paint()..color = color;
    canvas.drawCircle(center, radius, paint);
    canvas.drawCircle(
      center.translate(radius * 0.38, -radius * 0.22),
      radius * 0.52,
      paint,
    );
    canvas.drawCircle(
      center.translate(-radius * 0.34, radius * 0.2),
      radius * 0.42,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _LoginBackgroundPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
