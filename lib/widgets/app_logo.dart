// lib/widgets/app_logo.dart
//
// Logo animé de l'application Booky.
// Affiche le titre avec des icônes de ressources qui orbitent autour.
//
// Usage :
//   AppLogo(size: AppLogoSize.large)   // page auth
//   AppLogo(size: AppLogoSize.small)   // AppBar

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_booking/theme/app_theme.dart';

enum AppLogoSize { small, medium, large }

class AppLogo extends StatefulWidget {
  final AppLogoSize size;
  final bool animate;
  final bool showTitle;
  final bool showSubtitle;
  final bool darkBackground; // true = texte blanc, false = texte sombre

  const AppLogo({
    super.key,
    this.size = AppLogoSize.medium,
    this.animate = true,
    this.showTitle = true,
    this.showSubtitle = false,
    this.darkBackground = true,
  });

  @override
  State<AppLogo> createState() => _AppLogoState();
}

class _AppLogoState extends State<AppLogo> with TickerProviderStateMixin {
  late AnimationController _orbitController;
  late AnimationController _pulseController;
  late AnimationController _entryController;

  late Animation<double> _pulseAnim;
  late Animation<double> _entryAnim;

  @override
  void initState() {
    super.initState();

    _orbitController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    );
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _pulseAnim = Tween<double>(begin: 0.96, end: 1.04).animate(
        CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));
    _entryAnim = CurvedAnimation(parent: _entryController, curve: Curves.easeOutBack);

    if (widget.animate) {
      _orbitController.repeat();
      _pulseController.repeat(reverse: true);
      _entryController.forward();
    }
  }

  @override
  void dispose() {
    _orbitController.dispose();
    _pulseController.dispose();
    _entryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cfg = _config;

    return ScaleTransition(
      scale: _entryAnim,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Icône centrale avec orbite ──────────────────────────────
          AnimatedBuilder(
            animation: Listenable.merge([_orbitController, _pulseAnim]),
            builder: (_, __) => SizedBox(
              width: cfg.orbitSize,
              height: cfg.orbitSize,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Halo extérieur pulsant
                  Transform.scale(
                    scale: _pulseAnim.value,
                    child: Container(
                      width: cfg.orbitSize,
                      height: cfg.orbitSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(colors: [
                          AppColors.primary.withOpacity(0.12),
                          AppColors.primary.withOpacity(0),
                        ]),
                      ),
                    ),
                  ),

                  // Anneau orbital
                  Container(
                    width: cfg.orbitSize * 0.82,
                    height: cfg.orbitSize * 0.82,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withOpacity(0.15),
                        width: 1,
                      ),
                    ),
                  ),

                  // Icônes orbitales
                  ..._buildOrbitIcons(cfg),

                  // Logo central
                  _buildCenterLogo(cfg),
                ],
              ),
            ),
          ),

          if (widget.showTitle) ...[
            SizedBox(height: cfg.titleSpacing),
            _buildTitle(cfg),
          ],

          if (widget.showSubtitle) ...[
            const SizedBox(height: 4),
            _buildSubtitle(cfg),
          ],
        ],
      ),
    );
  }

  // ── Icônes qui orbitent ───────────────────────────────────────────────────
  List<Widget> _buildOrbitIcons(_LogoConfig cfg) {
    const icons = [
      (Icons.meeting_room_rounded,  AppColors.salle),
      (Icons.directions_car_rounded, AppColors.vehicule),
      (Icons.computer_rounded,      AppColors.ordinateur),
      (Icons.build_rounded,         AppColors.materiel),
      (Icons.calendar_month_rounded, AppColors.accent),
      (Icons.bookmark_rounded,      AppColors.secondary),
    ];

    final radius = cfg.orbitSize * 0.38;
    final count  = icons.length;

    return List.generate(count, (i) {
      final baseAngle = (2 * math.pi / count) * i;
      return AnimatedBuilder(
        animation: _orbitController,
        builder: (_, __) {
          final angle = baseAngle + _orbitController.value * 2 * math.pi;
          final x = math.cos(angle) * radius;
          final y = math.sin(angle) * radius;
          // Opacité basée sur la position (effet de profondeur)
          final depth = (math.sin(angle) + 1) / 2;
          final opacity = 0.55 + depth * 0.45;
          final scale   = 0.75 + depth * 0.35;

          return Transform.translate(
            offset: Offset(x, y),
            child: Transform.scale(
              scale: scale,
              child: Container(
                width: cfg.iconSize,
                height: cfg.iconSize,
                decoration: BoxDecoration(
                  color: icons[i].$2.withOpacity(opacity * 0.18),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: icons[i].$2.withOpacity(opacity * 0.4),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: icons[i].$2.withOpacity(opacity * 0.25),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Icon(
                  icons[i].$1,
                  size: cfg.iconSize * 0.52,
                  color: icons[i].$2.withOpacity(opacity),
                ),
              ),
            ),
          );
        },
      );
    });
  }

  // ── Logo central ──────────────────────────────────────────────────────────
  Widget _buildCenterLogo(_LogoConfig cfg) {
    return AnimatedBuilder(
      animation: _pulseAnim,
      builder: (_, __) => Transform.scale(
        scale: _pulseAnim.value,
        child: Container(
          width: cfg.logoSize,
          height: cfg.logoSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1239A6), Color(0xFF1A56DB), Color(0xFF6C3AED)],
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.45),
                blurRadius: cfg.logoSize * 0.4,
                offset: Offset(0, cfg.logoSize * 0.1),
              ),
              BoxShadow(
                color: AppColors.secondary.withOpacity(0.2),
                blurRadius: cfg.logoSize * 0.6,
                spreadRadius: -4,
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Reflet interne
              Positioned(
                top: cfg.logoSize * 0.1,
                left: cfg.logoSize * 0.15,
                child: Container(
                  width: cfg.logoSize * 0.35,
                  height: cfg.logoSize * 0.2,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(100),
                    color: Colors.white.withOpacity(0.15),
                  ),
                ),
              ),
              Icon(
                Icons.event_seat_rounded,
                color: Colors.white,
                size: cfg.logoSize * 0.46,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Titre ─────────────────────────────────────────────────────────────────
  Widget _buildTitle(_LogoConfig cfg) {
    if (widget.darkBackground) {
      // Fond sombre → texte blanc avec reflet bleu clair
      return ShaderMask(
        shaderCallback: (bounds) => const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFFFFF),
            Color(0xFFBFD7FF),
            Color(0xFFFFFFFF),
          ],
          stops: [0.0, 0.5, 1.0],
        ).createShader(bounds),
        child: Text(
          'Booky',
          style: TextStyle(
            fontSize: cfg.titleSize,
            fontWeight: FontWeight.w800,
            color: Colors.white, // requis pour ShaderMask
            letterSpacing: cfg.titleSize * 0.04,
            fontFamily: 'Poppins',
            height: 1.1,
          ),
        ),
      );
    } else {
      // Fond clair → texte sombre avec dégradé bleu/violet
      return ShaderMask(
        shaderCallback: (bounds) => const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primaryDark, AppColors.secondary],
        ).createShader(bounds),
        child: Text(
          'Booky',
          style: TextStyle(
            fontSize: cfg.titleSize,
            fontWeight: FontWeight.w800,
            color: AppColors.primaryDark, // requis pour ShaderMask
            letterSpacing: cfg.titleSize * 0.04,
            fontFamily: 'Poppins',
            height: 1.1,
          ),
        ),
      );
    }
  }

  Widget _buildSubtitle(_LogoConfig cfg) {
    final textColor = widget.darkBackground
        ? Colors.white.withOpacity(0.65)
        : AppColors.textSecondary;
    return Text(
      'Réservation de ressources',
      style: TextStyle(
        fontSize: cfg.titleSize * 0.30,
        color: textColor,
        letterSpacing: 2.0,
        fontFamily: 'Poppins',
        fontWeight: FontWeight.w400,
      ),
    );
  }

  _LogoConfig get _config {
    switch (widget.size) {
      case AppLogoSize.small:
        return const _LogoConfig(
          orbitSize: 56, logoSize: 32, iconSize: 18,
          titleSize: 20, titleSpacing: 6,
        );
      case AppLogoSize.medium:
        return const _LogoConfig(
          orbitSize: 100, logoSize: 56, iconSize: 28,
          titleSize: 32, titleSpacing: 10,
        );
      case AppLogoSize.large:
        return const _LogoConfig(
          orbitSize: 150, logoSize: 82, iconSize: 36,
          titleSize: 46, titleSpacing: 14,
        );
    }
  }
}

class _LogoConfig {
  final double orbitSize;
  final double logoSize;
  final double iconSize;
  final double titleSize;
  final double titleSpacing;

  const _LogoConfig({
    required this.orbitSize,
    required this.logoSize,
    required this.iconSize,
    required this.titleSize,
    required this.titleSpacing,
  });
}

// ─── Version inline pour AppBar (sans animation lourde) ──────────────────────
class AppBarLogo extends StatelessWidget {
  const AppBarLogo({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [Color(0xFF1239A6), Color(0xFF6C3AED)],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.white.withOpacity(0.3),
                blurRadius: 8,
              ),
            ],
          ),
          child: const Icon(Icons.event_seat_rounded,
              color: Colors.white, size: 16),
        ),
        const SizedBox(width: 8),
        ShaderMask(
          shaderCallback: (b) => const LinearGradient(
            colors: [Colors.white, Color(0xFFBFD7FF)],
          ).createShader(b),
          child: const Text(
            'Booky',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: 0.5,
              fontFamily: 'Poppins',
            ),
          ),
        ),
      ],
    );
  }
}
