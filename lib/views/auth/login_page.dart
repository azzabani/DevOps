// lib/views/auth/login_page.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_booking/services/auth_service.dart';
import 'package:flutter_booking/theme/app_theme.dart';
import 'package:flutter_booking/widgets/falling_resources_bg.dart';
import 'package:flutter_booking/widgets/app_logo.dart';
import 'signup_page.dart';
import '../home/main_shell.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with TickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _obscurePassword = true;
  final AuthService _authService = AuthService();

  // ── Controllers ──────────────────────────────────────────────────────────
  late AnimationController _entryController;   // fade + slide entrée
  late AnimationController _bgController;      // fond animé
  late AnimationController _pulseController;   // logo pulse
  late AnimationController _glitchController;  // glitch
  late AnimationController _shakeController;   // shake sur erreur
  late AnimationController _floatController;   // bulles flottantes

  // ── Animations ────────────────────────────────────────────────────────────
  late Animation<double>  _fadeAnim;
  late Animation<Offset>  _slideAnim;
  late Animation<double>  _bgAnim;
  late Animation<double>  _pulseAnim;
  late Animation<double>  _shakeAnim;
  late Animation<double>  _floatAnim;

  bool _glitchActive = false;
  // stagger pour les champs
  late Animation<double> _field1Anim;
  late Animation<double> _field2Anim;
  late Animation<double> _btnAnim;

  @override
  void initState() {
    super.initState();

    _entryController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1000));
    _bgController = AnimationController(
        vsync: this, duration: const Duration(seconds: 6))
      ..repeat(reverse: true);
    _pulseController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1800))
      ..repeat(reverse: true);
    _glitchController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 120));
    _shakeController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _floatController = AnimationController(
        vsync: this, duration: const Duration(seconds: 4))
      ..repeat(reverse: true);

    _fadeAnim = CurvedAnimation(parent: _entryController, curve: const Interval(0, 0.6, curve: Curves.easeOut));
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.25), end: Offset.zero)
        .animate(CurvedAnimation(parent: _entryController, curve: const Interval(0, 0.7, curve: Curves.easeOutCubic)));
    _bgAnim   = CurvedAnimation(parent: _bgController, curve: Curves.easeInOut);
    _pulseAnim = Tween<double>(begin: 0.93, end: 1.07)
        .animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));
    _shakeAnim = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _shakeController, curve: Curves.elasticOut));
    _floatAnim = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _floatController, curve: Curves.easeInOut));

    // stagger champs
    _field1Anim = CurvedAnimation(parent: _entryController, curve: const Interval(0.3, 0.75, curve: Curves.easeOutBack));
    _field2Anim = CurvedAnimation(parent: _entryController, curve: const Interval(0.45, 0.85, curve: Curves.easeOutBack));
    _btnAnim    = CurvedAnimation(parent: _entryController, curve: const Interval(0.6, 1.0, curve: Curves.easeOutBack));

    Future.delayed(const Duration(milliseconds: 80), () => _entryController.forward());
    Future.delayed(const Duration(seconds: 2), _triggerGlitch);
  }

  // ── Glitch ────────────────────────────────────────────────────────────────
  void _triggerGlitch() async {
    if (!mounted) return;
    for (int i = 0; i < 3; i++) {
      if (!mounted) return;
      setState(() => _glitchActive = true);
      await _glitchController.forward(from: 0);
      await Future.delayed(const Duration(milliseconds: 40));
      _glitchController.reverse();
      setState(() => _glitchActive = false);
      await Future.delayed(const Duration(milliseconds: 60));
    }
    final delay = 3500 + math.Random().nextInt(3000);
    Future.delayed(Duration(milliseconds: delay), () {
      if (mounted) _triggerGlitch();
    });
  }

  void _triggerShake() {
    _shakeController.forward(from: 0);
  }

  @override
  void dispose() {
    _entryController.dispose();
    _bgController.dispose();
    _pulseController.dispose();
    _glitchController.dispose();
    _shakeController.dispose();
    _floatController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ── Auth ──────────────────────────────────────────────────────────────────
  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) {
      _triggerShake();
      return;
    }
    setState(() => _isLoading = true);
    try {
      await _authService.signIn(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );
      if (mounted) {
        Navigator.pushReplacement(context, PageRouteBuilder(
          pageBuilder: (_, a, __) => const MainShell(),
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
          transitionDuration: const Duration(milliseconds: 500),
        ));
      }
    } on FirebaseAuthException catch (e) {
      _triggerShake();
      final msg = switch (e.code) {
        'user-not-found'  => 'Aucun compte trouvé avec cet email',
        'wrong-password'  => 'Mot de passe incorrect',
        'invalid-email'   => 'Email invalide',
        _                 => 'Erreur de connexion',
      };
      if (mounted) _showSnack(msg, isError: true);
    } catch (e) {
      _triggerShake();
      if (mounted) _showSnack('Erreur: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(isError ? Icons.error_outline_rounded : Icons.check_circle_rounded,
            color: Colors.white, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(msg)),
      ]),
      backgroundColor: isError ? AppColors.error : AppColors.success,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: _bgAnim,
        builder: (_, child) => Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.lerp(const Color(0xFF0D1B2A), const Color(0xFF1239A6), _bgAnim.value * 0.5)!,
                Color.lerp(const Color(0xFF1239A6), const Color(0xFF1A56DB), _bgAnim.value)!,
                Color.lerp(const Color(0xFF6C3AED), const Color(0xFF1239A6), _bgAnim.value)!,
              ],
            ),
          ),
          child: child,
        ),
        child: Stack(
          children: [
            _buildFloatingBubbles(),
            _buildGridPattern(),
            const FallingResourcesBg(count: 20, globalOpacity: 0.85),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                  child: FadeTransition(
                    opacity: _fadeAnim,
                    child: SlideTransition(
                      position: _slideAnim,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const AppLogo(
                            size: AppLogoSize.large,
                            showTitle: true,
                            showSubtitle: true,
                            darkBackground: true,
                          ),
                          const SizedBox(height: 36),
                          _buildCard(),
                          const SizedBox(height: 22),
                          _buildSignupLink(),
                        ],
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

  // ── Fond : bulles flottantes ──────────────────────────────────────────────
  Widget _buildFloatingBubbles() {
    return AnimatedBuilder(
      animation: _floatAnim,
      builder: (_, __) {
        final t = _floatAnim.value;
        return Stack(children: [
          _bubble(left: 30,  top: 80  + t * 20, size: 80,  color: AppColors.primaryLight, opacity: 0.18),
          _bubble(right: 20, top: 160 - t * 15, size: 110, color: AppColors.secondary,    opacity: 0.15),
          _bubble(left: 60,  bottom: 200 + t * 25, size: 60, color: AppColors.accent,     opacity: 0.20),
          _bubble(right: 40, bottom: 120 - t * 20, size: 90, color: AppColors.success,    opacity: 0.12),
          _bubble(left: -20, top: 350 + t * 10, size: 130, color: AppColors.primary,      opacity: 0.12),
          _bubble(right: -10,top: 500 - t * 18, size: 100, color: AppColors.secondary,    opacity: 0.14),
        ]);
      },
    );
  }

  Widget _bubble({double? left, double? right, double? top, double? bottom,
      required double size, required Color color, required double opacity}) {
    return Positioned(
      left: left, right: right, top: top, bottom: bottom,
      child: Container(
        width: size, height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [
            color.withOpacity(opacity),
            color.withOpacity(0),
          ]),
        ),
      ),
    );
  }

  // ── Fond : grille légère ──────────────────────────────────────────────────
  Widget _buildGridPattern() {
    return Positioned.fill(
      child: CustomPaint(painter: _GridPainter()),
    );
  }

  // ── Logo avec glitch + pulse ──────────────────────────────────────────────
  Widget _buildLogo() {
    return AnimatedBuilder(
      animation: Listenable.merge([_pulseAnim, _glitchController]),
      builder: (_, __) {
        return Transform.scale(
          scale: _pulseAnim.value,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Halo extérieur
              Container(
                width: 96, height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.2),
                      blurRadius: 30, spreadRadius: 8,
                    ),
                  ],
                ),
              ),
              // Anneau décoratif
              Container(
                width: 88, height: 88,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.primary.withOpacity(0.15), width: 2),
                ),
              ),
              // Glitch layers
              if (_glitchActive) ...[
                Positioned(left: 4,
                  child: _logoCircle(AppColors.error.withOpacity(0.5))),
                Positioned(right: 4,
                  child: _logoCircle(AppColors.accent.withOpacity(0.5))),
              ],
              _logoCircle(null),
            ],
          ),
        );
      },
    );
  }

  Widget _logoCircle(Color? tint) {
    return Container(
      width: 76, height: 76,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: tint != null
              ? [tint, tint.withOpacity(0.5)]
              : [AppColors.primary, AppColors.secondary],
        ),
        boxShadow: tint == null ? [
          BoxShadow(color: AppColors.primary.withOpacity(0.35),
              blurRadius: 20, offset: const Offset(0, 6)),
        ] : null,
      ),
      child: const Icon(Icons.event_seat_rounded, color: Colors.white, size: 34),
    );
  }

  // ── Titre avec glitch ─────────────────────────────────────────────────────
  Widget _buildTitle() {
    return AnimatedBuilder(
      animation: _glitchController,
      builder: (_, __) {
        return Stack(
          alignment: Alignment.center,
          children: [
            if (_glitchActive) ...[
              Positioned(left: 4,
                child: _titleText(AppColors.error.withOpacity(0.55))),
              Positioned(right: 4,
                child: _titleText(AppColors.accent.withOpacity(0.55))),
            ],
            ShaderMask(
              shaderCallback: (b) => const LinearGradient(
                colors: [AppColors.primary, AppColors.secondary, AppColors.accent],
              ).createShader(b),
              child: _titleText(Colors.white),
            ),
          ],
        );
      },
    );
  }

  Widget _titleText(Color color) => Text('Booky',
      style: TextStyle(fontSize: 44, fontWeight: FontWeight.bold,
          color: color, letterSpacing: 1.5,
          fontFamily: 'Poppins'));

  Widget _buildSubtitle(String text) => Text(text,
      style: const TextStyle(
          color: AppColors.textSecondary, fontSize: 13, letterSpacing: 1.5));

  // ── Card principale ───────────────────────────────────────────────────────
  Widget _buildCard() {
    return AnimatedBuilder(
      animation: _shakeAnim,
      builder: (_, child) {
        final shake = math.sin(_shakeAnim.value * math.pi * 6) * 8 * (1 - _shakeAnim.value);
        return Transform.translate(offset: Offset(shake, 0), child: child);
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(color: AppColors.primary.withOpacity(0.08),
                blurRadius: 40, offset: const Offset(0, 12)),
            BoxShadow(color: AppColors.secondary.withOpacity(0.05),
                blurRadius: 20, offset: const Offset(0, 4)),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header card
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primarySurface,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.login_rounded,
                        color: AppColors.primary, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Connexion',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary)),
                    const Text('Bienvenue de retour',
                        style: TextStyle(fontSize: 12, color: AppColors.textTertiary)),
                  ]),
                ]),
                const SizedBox(height: 24),

                // Champ email — stagger
                _StaggerField(animation: _field1Anim,
                  child: _buildField(
                    controller: _emailController,
                    label: 'Email',
                    icon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Email requis';
                      if (!v.contains('@')) return 'Email invalide';
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 14),

                // Champ mot de passe — stagger
                _StaggerField(animation: _field2Anim,
                  child: _buildField(
                    controller: _passwordController,
                    label: 'Mot de passe',
                    icon: Icons.lock_outline_rounded,
                    obscure: _obscurePassword,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off_rounded
                            : Icons.visibility_rounded,
                        color: AppColors.textTertiary, size: 20),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Mot de passe requis';
                      if (v.length < 6) return 'Minimum 6 caractères';
                      return null;
                    },
                  ),
                ),

                // Mot de passe oublié
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _showForgotPassword,
                    style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4)),
                    child: const Text('Mot de passe oublié ?',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(height: 6),

                // Bouton — stagger
                _StaggerField(animation: _btnAnim, child: _buildButton()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscure = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscure,
      style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.primary, size: 20),
        suffixIcon: suffixIcon,
      ),
      validator: validator,
    );
  }

  Widget _buildButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: _isLoading
          ? Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.secondary]),
              ),
              child: const Center(
                child: SizedBox(width: 22, height: 22,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.5)),
              ),
            )
          : _GlowButton(
              label: 'Se connecter',
              onTap: _login,
              gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.secondary]),
              glowColor: AppColors.primary,
            ),
    );
  }

  Widget _buildSignupLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('Pas encore de compte ? ',
            style: TextStyle(
                color: Colors.white70, fontSize: 13, fontFamily: 'Poppins')),
        GestureDetector(
          onTap: () => Navigator.push(context, PageRouteBuilder(
            pageBuilder: (_, a, __) => const SignupPage(),
            transitionsBuilder: (_, anim, __, child) => SlideTransition(
              position: Tween<Offset>(
                      begin: const Offset(1, 0), end: Offset.zero)
                  .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
              child: child,
            ),
            transitionDuration: const Duration(milliseconds: 400),
          )),
          child: ShaderMask(
            shaderCallback: (b) => const LinearGradient(
              colors: [AppColors.primary, AppColors.secondary],
            ).createShader(b),
            child: const Text("S'inscrire",
                style: TextStyle(color: Colors.white,
                    fontWeight: FontWeight.bold, fontSize: 13)),
          ),
        ),
      ],
    );
  }

  Future<void> _showForgotPassword() async {
    final emailCtrl = TextEditingController(text: _emailController.text.trim());
    final send = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Réinitialiser le mot de passe',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Entrez votre email pour recevoir un lien de réinitialisation.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 14),
          TextField(
            controller: emailCtrl,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email',
              prefixIcon: Icon(Icons.email_outlined),
            ),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Envoyer')),
        ],
      ),
    );
    if (send == true && emailCtrl.text.trim().isNotEmpty && mounted) {
      try {
        await _authService.sendPasswordResetEmail(emailCtrl.text.trim());
        if (mounted) _showSnack('Email envoyé !');
      } catch (e) {
        if (mounted) _showSnack('Erreur : $e', isError: true);
      }
    }
  }
}

// ─── Widgets partagés ─────────────────────────────────────────────────────────

/// Champ qui apparaît avec un scale + fade staggeré
class _StaggerField extends StatelessWidget {
  final Animation<double> animation;
  final Widget child;
  const _StaggerField({required this.animation, required this.child});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (_, c) => Transform.scale(
        scale: 0.85 + 0.15 * animation.value,
        alignment: Alignment.centerLeft,
        child: Opacity(opacity: animation.value.clamp(0.0, 1.0), child: c),
      ),
      child: child,
    );
  }
}

/// Bouton avec glow animé au hover/press
class _GlowButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final LinearGradient gradient;
  final Color glowColor;
  const _GlowButton({
    required this.label,
    required this.onTap,
    required this.gradient,
    required this.glowColor,
  });

  @override
  State<_GlowButton> createState() => _GlowButtonState();
}

class _GlowButtonState extends State<_GlowButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scaleAnim;
  late Animation<double> _glowAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 150));
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.96)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeIn));
    _glowAnim = Tween<double>(begin: 0.35, end: 0.6)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeIn));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) { _ctrl.reverse(); widget.onTap(); },
      onTapCancel: () => _ctrl.reverse(),
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) => Transform.scale(
          scale: _scaleAnim.value,
          child: Container(
            height: 52,
            decoration: BoxDecoration(
              gradient: widget.gradient,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: widget.glowColor.withOpacity(_glowAnim.value),
                  blurRadius: 20, offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Center(
              child: Text(widget.label,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 15,
                      fontWeight: FontWeight.bold, letterSpacing: 0.5,
                      fontFamily: 'Poppins')),
            ),
          ),
        ),
      ),
    );
  }
}

/// Grille de points décorative en fond
class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Points blancs sur fond sombre
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.07)
      ..style = PaintingStyle.fill;
    const step = 36.0;
    for (double x = 0; x < size.width; x += step) {
      for (double y = 0; y < size.height; y += step) {
        canvas.drawCircle(Offset(x, y), 1.2, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_) => false;
}
