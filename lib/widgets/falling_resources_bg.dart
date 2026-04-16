// lib/widgets/falling_resources_bg.dart
//
// Widget de fond animé : icônes de ressources qui tombent en arrière-plan.
// Usage :
//   Stack(children: [
//     const FallingResourcesBg(),
//     // ... contenu
//   ])

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_booking/theme/app_theme.dart';

// ─── Données d'une particule ──────────────────────────────────────────────────
class _Particle {
  final IconData icon;
  final Color color;
  final double x;        // position X (0..1 relatif à la largeur)
  final double size;     // taille de l'icône
  final double speed;    // vitesse de chute (0..1 par cycle)
  final double opacity;
  final double rotation; // rotation initiale en radians
  final double rotSpeed; // vitesse de rotation
  final double startY;   // décalage de départ vertical (0..1)
  final double swayAmp;  // amplitude du balancement horizontal
  final double swayFreq; // fréquence du balancement

  const _Particle({
    required this.icon,
    required this.color,
    required this.x,
    required this.size,
    required this.speed,
    required this.opacity,
    required this.rotation,
    required this.rotSpeed,
    required this.startY,
    required this.swayAmp,
    required this.swayFreq,
  });
}

// ─── Icônes de ressources disponibles ────────────────────────────────────────
const _resourceIcons = [
  // Salles de réunion
  Icons.meeting_room_rounded,
  Icons.door_front_door_rounded,
  Icons.chair_rounded,
  Icons.tv_rounded,
  Icons.videocam_rounded,
  Icons.mic_rounded,
  Icons.present_to_all_rounded,
  // Véhicules
  Icons.directions_car_rounded,
  Icons.local_taxi_rounded,
  Icons.airport_shuttle_rounded,
  Icons.two_wheeler_rounded,
  Icons.electric_car_rounded,
  // Ordinateurs / matériel
  Icons.computer_rounded,
  Icons.laptop_rounded,
  Icons.tablet_rounded,
  Icons.keyboard_rounded,
  Icons.mouse_rounded,
  Icons.headset_rounded,
  Icons.print_rounded,
  Icons.scanner_rounded,
  Icons.camera_alt_rounded,
  Icons.build_rounded,
  Icons.handyman_rounded,
  Icons.cable_rounded,
];

const _resourceColors = [
  AppColors.salle,
  AppColors.vehicule,
  AppColors.ordinateur,
  AppColors.materiel,
  AppColors.primary,
  AppColors.secondary,
  AppColors.accent,
  AppColors.success,
];

// ─── Widget principal ─────────────────────────────────────────────────────────
class FallingResourcesBg extends StatefulWidget {
  /// Nombre de particules
  final int count;

  /// Opacité globale du fond (0..1)
  final double globalOpacity;

  /// Couleur de teinte optionnelle sur les icônes
  final Color? tint;

  const FallingResourcesBg({
    super.key,
    this.count = 22,
    this.globalOpacity = 1.0,
    this.tint,
  });

  @override
  State<FallingResourcesBg> createState() => _FallingResourcesBgState();
}

class _FallingResourcesBgState extends State<FallingResourcesBg>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<_Particle> _particles;
  final _rng = math.Random(42);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat();
    _particles = _generateParticles();
  }

  List<_Particle> _generateParticles() {
    return List.generate(widget.count, (i) {
      final icon  = _resourceIcons[_rng.nextInt(_resourceIcons.length)];
      final color = widget.tint ?? _resourceColors[_rng.nextInt(_resourceColors.length)];
      return _Particle(
        icon:     icon,
        color:    color,
        x:        _rng.nextDouble(),
        size:     18 + _rng.nextDouble() * 22,   // 18..40
        speed:    0.25 + _rng.nextDouble() * 0.55, // vitesse relative
        opacity:  0.06 + _rng.nextDouble() * 0.10, // 0.06..0.16
        rotation: _rng.nextDouble() * math.pi * 2,
        rotSpeed: (_rng.nextDouble() - 0.5) * 0.8,
        startY:   _rng.nextDouble(),               // décalage initial
        swayAmp:  0.015 + _rng.nextDouble() * 0.025,
        swayFreq: 0.5 + _rng.nextDouble() * 1.5,
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            painter: _FallingPainter(
              particles: _particles,
              progress: _controller.value,
              globalOpacity: widget.globalOpacity,
            ),
          );
        },
      ),
    );
  }
}

// ─── CustomPainter ────────────────────────────────────────────────────────────
class _FallingPainter extends CustomPainter {
  final List<_Particle> particles;
  final double progress;
  final double globalOpacity;

  const _FallingPainter({
    required this.particles,
    required this.progress,
    required this.globalOpacity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      // Position Y : chaque particule a sa propre vitesse et décalage
      final rawY = (p.startY + progress * p.speed) % 1.0;
      final y = rawY * (size.height + p.size * 2) - p.size;

      // Balancement horizontal sinusoïdal
      final sway = math.sin(progress * math.pi * 2 * p.swayFreq + p.x * math.pi * 2)
          * p.swayAmp * size.width;
      final x = p.x * size.width + sway;

      // Rotation
      final angle = p.rotation + progress * p.rotSpeed * math.pi * 2;

      // Fade in/out aux bords (haut et bas)
      double edgeFade = 1.0;
      const fadeZone = 0.08;
      if (rawY < fadeZone) edgeFade = rawY / fadeZone;
      if (rawY > 1.0 - fadeZone) edgeFade = (1.0 - rawY) / fadeZone;

      final opacity = (p.opacity * globalOpacity * edgeFade).clamp(0.0, 1.0);
      if (opacity <= 0) continue;

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(angle);

      // Dessiner l'icône via TextPainter (méthode Flutter standard pour les icônes)
      final tp = TextPainter(
        text: TextSpan(
          text: String.fromCharCode(p.icon.codePoint),
          style: TextStyle(
            fontSize: p.size,
            fontFamily: p.icon.fontFamily,
            package: p.icon.fontPackage,
            color: p.color.withOpacity(opacity),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_FallingPainter old) =>
      old.progress != progress || old.globalOpacity != globalOpacity;
}
