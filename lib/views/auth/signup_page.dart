// lib/views/auth/signup_page.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_booking/services/auth_service.dart';
import 'package:flutter_booking/theme/app_theme.dart';
import 'package:flutter_booking/widgets/falling_resources_bg.dart';
import 'package:flutter_booking/widgets/app_logo.dart';
import 'login_page.dart';
import '../home/main_shell.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> with TickerProviderStateMixin {
  final _nameController     = TextEditingController();
  final _emailController    = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController  = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading       = false;
  bool _obscurePassword = true;
  bool _obscureConfirm  = true;
  bool _acceptedTerms   = false;
  String? _selectedRole = 'user';
  final AuthService _authService = AuthService();
  final List<String> _roles = ['user', 'manager', 'admin'];

  // ── Controllers ──────────────────────────────────────────────────────────
  late AnimationController _entryController;
  late AnimationController _bgController;
  late AnimationController _glitchController;
  late AnimationController _shakeController;
  late AnimationController _floatController;
  late AnimationController _pulseController;

  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;
  late Animation<double> _bgAnim;
  late Animation<double> _floatAnim;
  late Animation<double> _pulseAnim;
  late Animation<double> _shakeAnim;

  bool _glitchActive = false;

  // stagger champs
  late Animation<double> _f1, _f2, _f3, _f4, _f5, _btnAnim;

  @override
  void initState() {
    super.initState();

    _entryController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1100));
    _bgController = AnimationController(
        vsync: this, duration: const Duration(seconds: 7))
      ..repeat(reverse: true);
    _glitchController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 110));
    _shakeController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _floatController = AnimationController(
        vsync: this, duration: const Duration(seconds: 5))
      ..repeat(reverse: true);
    _pulseController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2000))
      ..repeat(reverse: true);

    _fadeAnim  = CurvedAnimation(parent: _entryController,
        curve: const Interval(0, 0.55, curve: Curves.easeOut));
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero)
        .animate(CurvedAnimation(parent: _entryController,
            curve: const Interval(0, 0.65, curve: Curves.easeOutCubic)));
    _bgAnim    = CurvedAnimation(parent: _bgController, curve: Curves.easeInOut);
    _floatAnim = CurvedAnimation(parent: _floatController, curve: Curves.easeInOut);
    _pulseAnim = Tween<double>(begin: 0.92, end: 1.08)
        .animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));
    _shakeAnim = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _shakeController, curve: Curves.elasticOut));

    // stagger champs
    _f1   = CurvedAnimation(parent: _entryController, curve: const Interval(0.20, 0.60, curve: Curves.easeOutBack));
    _f2   = CurvedAnimation(parent: _entryController, curve: const Interval(0.30, 0.68, curve: Curves.easeOutBack));
    _f3   = CurvedAnimation(parent: _entryController, curve: const Interval(0.38, 0.75, curve: Curves.easeOutBack));
    _f4   = CurvedAnimation(parent: _entryController, curve: const Interval(0.46, 0.82, curve: Curves.easeOutBack));
    _f5   = CurvedAnimation(parent: _entryController, curve: const Interval(0.54, 0.88, curve: Curves.easeOutBack));
    _btnAnim = CurvedAnimation(parent: _entryController, curve: const Interval(0.65, 1.0, curve: Curves.easeOutBack));

    Future.delayed(const Duration(milliseconds: 80), () => _entryController.forward());
    Future.delayed(const Duration(seconds: 2), _triggerGlitch);
  }

  void _triggerGlitch() async {
    if (!mounted) return;
    for (int i = 0; i < 2; i++) {
      if (!mounted) return;
      setState(() => _glitchActive = true);
      await _glitchController.forward(from: 0);
      await Future.delayed(const Duration(milliseconds: 50));
      _glitchController.reverse();
      setState(() => _glitchActive = false);
      await Future.delayed(const Duration(milliseconds: 80));
    }
    final delay = 4000 + math.Random().nextInt(4000);
    Future.delayed(Duration(milliseconds: delay), () {
      if (mounted) _triggerGlitch();
    });
  }

  void _triggerShake() => _shakeController.forward(from: 0);

  @override
  void dispose() {
    _entryController.dispose();
    _bgController.dispose();
    _glitchController.dispose();
    _shakeController.dispose();
    _floatController.dispose();
    _pulseController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _signup() async {
    if (!_formKey.currentState!.validate()) { _triggerShake(); return; }
    if (!_acceptedTerms) {
      _triggerShake();
      _showSnack('Veuillez accepter les conditions', isError: true);
      return;
    }
    setState(() => _isLoading = true);
    try {
      final cred = await _authService.signUp(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );
      await _authService.saveUserData(
        userId: cred.user!.uid,
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        role: _selectedRole!,
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
        'email-already-in-use' => 'Cet email est déjà utilisé',
        'weak-password'        => 'Mot de passe trop faible',
        _                      => 'Erreur: ${e.message}',
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
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [
                Color.lerp(const Color(0xFF0D1B2A), const Color(0xFF6C3AED), _bgAnim.value * 0.4)!,
                Color.lerp(const Color(0xFF1239A6), const Color(0xFF1A56DB), _bgAnim.value)!,
                Color.lerp(const Color(0xFF1A56DB), const Color(0xFF6C3AED), _bgAnim.value)!,
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
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
                  child: FadeTransition(
                    opacity: _fadeAnim,
                    child: SlideTransition(
                      position: _slideAnim,
                      child: Column(
                        children: [
                          const AppLogo(
                            size: AppLogoSize.medium,
                            showTitle: true,
                            showSubtitle: false,
                            darkBackground: true,
                          ),
                          const SizedBox(height: 6),
                          Text('Créez votre compte',
                              style: TextStyle(
                                  color: Colors.white.withOpacity(0.5),
                                  fontSize: 13, letterSpacing: 1.2,
                                  fontFamily: 'Poppins')),
                          const SizedBox(height: 28),
                          _buildCard(),
                          const SizedBox(height: 20),
                          _buildLoginLink(),
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

  // ── Bulles flottantes ─────────────────────────────────────────────────────
  Widget _buildFloatingBubbles() {
    return AnimatedBuilder(
      animation: _floatAnim,
      builder: (_, __) {
        final t = _floatAnim.value;
        return Stack(children: [
          _bubble(right: 20, top: 60  + t * 18, size: 100, color: AppColors.secondary,    opacity: 0.18),
          _bubble(left: 10,  top: 180 - t * 14, size: 80,  color: AppColors.primaryLight, opacity: 0.15),
          _bubble(right: 30, bottom: 180 + t * 22, size: 70, color: AppColors.accent,     opacity: 0.20),
          _bubble(left: 40,  bottom: 100 - t * 16, size: 90, color: AppColors.success,    opacity: 0.12),
          _bubble(left: -15, top: 400 + t * 12, size: 120, color: AppColors.secondary,    opacity: 0.13),
          _bubble(right: -5, top: 550 - t * 20, size: 85,  color: AppColors.primary,      opacity: 0.15),
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
            color.withOpacity(opacity), color.withOpacity(0),
          ]),
        ),
      ),
    );
  }

  Widget _buildGridPattern() => Positioned.fill(
      child: CustomPaint(painter: _GridPainter()));

  // ── Logo ──────────────────────────────────────────────────────────────────
  Widget _buildLogo() {
    return AnimatedBuilder(
      animation: Listenable.merge([_pulseAnim, _glitchController]),
      builder: (_, __) => Transform.scale(
        scale: _pulseAnim.value,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 88, height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(
                  color: AppColors.secondary.withOpacity(0.22),
                  blurRadius: 28, spreadRadius: 6,
                )],
              ),
            ),
            Container(
              width: 82, height: 82,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                    color: AppColors.secondary.withOpacity(0.15), width: 2),
              ),
            ),
            if (_glitchActive) ...[
              Positioned(left: 4,
                  child: _logoCircle(AppColors.error.withOpacity(0.5))),
              Positioned(right: 4,
                  child: _logoCircle(AppColors.accent.withOpacity(0.5))),
            ],
            _logoCircle(null),
          ],
        ),
      ),
    );
  }

  Widget _logoCircle(Color? tint) => Container(
    width: 70, height: 70,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: tint != null
            ? [tint, tint.withOpacity(0.5)]
            : [AppColors.secondary, AppColors.primary],
      ),
      boxShadow: tint == null ? [BoxShadow(
        color: AppColors.secondary.withOpacity(0.3),
        blurRadius: 18, offset: const Offset(0, 5),
      )] : null,
    ),
    child: const Icon(Icons.person_add_rounded, color: Colors.white, size: 30),
  );

  // ── Titre glitch ──────────────────────────────────────────────────────────
  Widget _buildTitle() {
    return AnimatedBuilder(
      animation: _glitchController,
      builder: (_, __) => Stack(
        alignment: Alignment.center,
        children: [
          if (_glitchActive) ...[
            Positioned(left: 3,
                child: _titleText(AppColors.error.withOpacity(0.5))),
            Positioned(right: 3,
                child: _titleText(AppColors.accent.withOpacity(0.5))),
          ],
          ShaderMask(
            shaderCallback: (b) => const LinearGradient(
              colors: [AppColors.secondary, AppColors.primary, AppColors.accent],
            ).createShader(b),
            child: _titleText(Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _titleText(Color color) => Text('Inscription',
      style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold,
          color: color, letterSpacing: 1, fontFamily: 'Poppins'));

  // ── Card ──────────────────────────────────────────────────────────────────
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
            BoxShadow(color: AppColors.secondary.withOpacity(0.08),
                blurRadius: 40, offset: const Offset(0, 12)),
            BoxShadow(color: AppColors.primary.withOpacity(0.05),
                blurRadius: 20, offset: const Offset(0, 4)),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                // Header
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.secondarySurface,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.person_add_rounded,
                        color: AppColors.secondary, size: 18),
                  ),
                  const SizedBox(width: 12),
                  const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Créer un compte',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary)),
                    Text('Rejoignez Booky',
                        style: TextStyle(fontSize: 12, color: AppColors.textTertiary)),
                  ]),
                ]),
                const SizedBox(height: 22),

                _StaggerField(animation: _f1, child: _buildField(
                  controller: _nameController, label: 'Nom complet',
                  icon: Icons.person_outline_rounded,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Nom requis';
                    if (v.length < 2) return 'Trop court';
                    return null;
                  },
                )),
                const SizedBox(height: 12),

                _StaggerField(animation: _f2, child: _buildField(
                  controller: _emailController, label: 'Email',
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Email requis';
                    if (!v.contains('@')) return 'Email invalide';
                    return null;
                  },
                )),
                const SizedBox(height: 12),

                _StaggerField(animation: _f3, child: _buildRoleDropdown()),
                const SizedBox(height: 12),

                _StaggerField(animation: _f4, child: _buildField(
                  controller: _passwordController, label: 'Mot de passe',
                  icon: Icons.lock_outline_rounded,
                  obscure: _obscurePassword,
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword
                        ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                        color: AppColors.textTertiary, size: 20),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Requis';
                    if (v.length < 6) return 'Minimum 6 caractères';
                    return null;
                  },
                )),
                const SizedBox(height: 12),

                _StaggerField(animation: _f5, child: _buildField(
                  controller: _confirmController,
                  label: 'Confirmer le mot de passe',
                  icon: Icons.lock_reset_rounded,
                  obscure: _obscureConfirm,
                  suffixIcon: IconButton(
                    icon: Icon(_obscureConfirm
                        ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                        color: AppColors.textTertiary, size: 20),
                    onPressed: () =>
                        setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Requis';
                    if (v != _passwordController.text) return 'Mots de passe différents';
                    return null;
                  },
                )),
                const SizedBox(height: 16),

                _buildTermsRow(),
                const SizedBox(height: 18),

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
        prefixIcon: Icon(icon, color: AppColors.secondary, size: 20),
        suffixIcon: suffixIcon,
      ),
      validator: validator,
    );
  }

  Widget _buildRoleDropdown() {
    final roleLabels = {
      'user':    '👤  Utilisateur',
      'manager': '📊  Manager',
      'admin':   '🛡️  Administrateur',
    };
    return DropdownButtonFormField<String>(
      value: _selectedRole,
      style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
      decoration: const InputDecoration(
        labelText: 'Rôle',
        prefixIcon: Icon(Icons.work_outline_rounded,
            color: AppColors.secondary, size: 20),
      ),
      items: _roles.map((r) => DropdownMenuItem(
        value: r,
        child: Text(roleLabels[r] ?? r,
            style: const TextStyle(color: AppColors.textPrimary)),
      )).toList(),
      onChanged: (v) => setState(() => _selectedRole = v),
    );
  }

  Widget _buildTermsRow() {
    return Row(
      children: [
        SizedBox(
          width: 24, height: 24,
          child: Checkbox(
            value: _acceptedTerms,
            onChanged: (v) => setState(() => _acceptedTerms = v ?? false),
            activeColor: AppColors.secondary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _acceptedTerms = !_acceptedTerms),
            child: Text.rich(TextSpan(
              text: "J'accepte les ",
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
              children: [
                TextSpan(
                  text: "conditions d'utilisation",
                  style: TextStyle(
                    color: AppColors.secondary,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.underline,
                    decorationColor: AppColors.secondary.withOpacity(0.5),
                  ),
                ),
              ],
            )),
          ),
        ),
      ],
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
                    colors: [AppColors.secondary, AppColors.primary]),
              ),
              child: const Center(
                child: SizedBox(width: 22, height: 22,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.5)),
              ),
            )
          : _GlowButton(
              label: "S'inscrire",
              onTap: _signup,
              gradient: const LinearGradient(
                  colors: [AppColors.secondary, AppColors.primary]),
              glowColor: AppColors.secondary,
            ),
    );
  }

  Widget _buildLoginLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('Déjà un compte ? ',
            style: TextStyle(
                color: Colors.white70, fontSize: 13, fontFamily: 'Poppins')),
        GestureDetector(
          onTap: () => Navigator.pushReplacement(context, PageRouteBuilder(
            pageBuilder: (_, a, __) => const LoginPage(),
            transitionsBuilder: (_, anim, __, child) => SlideTransition(
              position: Tween<Offset>(
                      begin: const Offset(-1, 0), end: Offset.zero)
                  .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
              child: child,
            ),
            transitionDuration: const Duration(milliseconds: 400),
          )),
          child: ShaderMask(
            shaderCallback: (b) => const LinearGradient(
              colors: [AppColors.secondary, AppColors.primary],
            ).createShader(b),
            child: const Text('Se connecter',
                style: TextStyle(color: Colors.white,
                    fontWeight: FontWeight.bold, fontSize: 13)),
          ),
        ),
      ],
    );
  }
}

// ─── Widgets partagés (réutilisés depuis login_page.dart) ─────────────────────

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

class _GlowButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final LinearGradient gradient;
  final Color glowColor;
  const _GlowButton({
    required this.label, required this.onTap,
    required this.gradient, required this.glowColor,
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
  void dispose() { _ctrl.dispose(); super.dispose(); }

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
              boxShadow: [BoxShadow(
                color: widget.glowColor.withOpacity(_glowAnim.value),
                blurRadius: 20, offset: const Offset(0, 6),
              )],
            ),
            child: Center(child: Text(widget.label,
                style: const TextStyle(color: Colors.white, fontSize: 15,
                    fontWeight: FontWeight.bold, letterSpacing: 0.5,
                    fontFamily: 'Poppins'))),
          ),
        ),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
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
