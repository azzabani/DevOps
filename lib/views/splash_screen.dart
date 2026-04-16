// lib/views/splash_screen.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_booking/theme/app_theme.dart';
import 'package:flutter_booking/widgets/app_logo.dart';
import 'package:flutter_booking/widgets/falling_resources_bg.dart';

class SplashScreen extends StatefulWidget {
  final Widget nextScreen;
  const SplashScreen({super.key, required this.nextScreen});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _bgController;
  late AnimationController _contentController;
  late AnimationController _exitController;

  late Animation<double> _bgAnim;
  late Animation<double> _fadeIn;
  late Animation<double> _fadeOut;
  late Animation<double> _scaleOut;

  @override
  void initState() {
    super.initState();

    _bgController = AnimationController(
        vsync: this, duration: const Duration(seconds: 8))
      ..repeat(reverse: true);

    _contentController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1000));

    _exitController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));

    _bgAnim   = CurvedAnimation(parent: _bgController, curve: Curves.easeInOut);
    _fadeIn   = CurvedAnimation(parent: _contentController, curve: Curves.easeOut);
    _fadeOut  = Tween<double>(begin: 1, end: 0)
        .animate(CurvedAnimation(parent: _exitController, curve: Curves.easeIn));
    _scaleOut = Tween<double>(begin: 1, end: 1.08)
        .animate(CurvedAnimation(parent: _exitController, curve: Curves.easeIn));

    Future.delayed(const Duration(milliseconds: 300),
        () => _contentController.forward());

    Future.delayed(const Duration(milliseconds: 2800), _exit);
  }

  Future<void> _exit() async {
    await _exitController.forward();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => widget.nextScreen,
          transitionDuration: Duration.zero,
        ),
      );
    }
  }

  @override
  void dispose() {
    _bgController.dispose();
    _contentController.dispose();
    _exitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _exitController,
      builder: (_, child) => Transform.scale(
        scale: _scaleOut.value,
        child: Opacity(opacity: _fadeOut.value, child: child),
      ),
      child: Scaffold(
        body: AnimatedBuilder(
          animation: _bgAnim,
          builder: (_, child) => Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.lerp(const Color(0xFF0D1B2A),
                      const Color(0xFF1239A6), _bgAnim.value * 0.4)!,
                  Color.lerp(const Color(0xFF1239A6),
                      const Color(0xFF1A56DB), _bgAnim.value)!,
                  Color.lerp(const Color(0xFF6C3AED),
                      const Color(0xFF1239A6), _bgAnim.value)!,
                ],
              ),
            ),
            child: child,
          ),
          child: Stack(
            children: [
              const FallingResourcesBg(count: 24, globalOpacity: 0.7),
              _buildGrid(),
              Center(
                child: FadeTransition(
                  opacity: _fadeIn,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const AppLogo(
                        size: AppLogoSize.large,
                        showTitle: true,
                        showSubtitle: true,
                        darkBackground: true,
                      ),
                      const SizedBox(height: 60),
                      _buildLoader(),
                    ],
                  ),
                ),
              ),
              _buildVersion(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGrid() {
    return Positioned.fill(
      child: CustomPaint(painter: _SplashGridPainter()),
    );
  }

  Widget _buildLoader() {
    return Column(
      children: [
        SizedBox(
          width: 120,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              backgroundColor: Colors.white.withOpacity(0.1),
              valueColor: AlwaysStoppedAnimation<Color>(
                  Colors.white.withOpacity(0.7)),
              minHeight: 3,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Chargement…',
          style: TextStyle(
            color: Colors.white.withOpacity(0.4),
            fontSize: 12,
            letterSpacing: 1.5,
            fontFamily: 'Poppins',
          ),
        ),
      ],
    );
  }

  Widget _buildVersion() {
    return Positioned(
      bottom: 32,
      left: 0, right: 0,
      child: FadeTransition(
        opacity: _fadeIn,
        child: Text(
          'v1.0.0',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withOpacity(0.25),
            fontSize: 11,
            letterSpacing: 1,
            fontFamily: 'Poppins',
          ),
        ),
      ),
    );
  }
}

class _SplashGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.03)
      ..strokeWidth = 1;
    const step = 40.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    // Points aux intersections
    final dotPaint = Paint()
      ..color = Colors.white.withOpacity(0.06)
      ..style = PaintingStyle.fill;
    for (double x = 0; x < size.width; x += step) {
      for (double y = 0; y < size.height; y += step) {
        canvas.drawCircle(Offset(x, y), 1.5, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(_) => false;
}
