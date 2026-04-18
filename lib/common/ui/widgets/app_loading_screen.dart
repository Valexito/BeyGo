// lib/common/utils/components/ui/app_loading_screen.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:mapbox_api/common/ui/components/app_styles.dart';

/// Reusable animated loading screen.
///
/// Usage:
/// ```dart
/// AppLoadingScreen(message: 'Buscando rutas...')
/// AppLoadingScreen(message: 'Cargando perfil...', variant: LoadingVariant.profile)
/// AppLoadingScreen(message: 'Cargando mapa...', variant: LoadingVariant.map)
/// AppLoadingScreen.profileData()   // shortcut for profile data loading
/// ```
enum LoadingVariant { route, map, profile, general }

class AppLoadingScreen extends StatefulWidget {
  final String message;
  final String? submessage;
  final LoadingVariant variant;

  const AppLoadingScreen({
    super.key,
    this.message = 'Cargando...',
    this.submessage,
    this.variant = LoadingVariant.general,
  });

  /// Shortcut for loading profile data
  const AppLoadingScreen.profileData({super.key})
    : message = 'Cargando tu perfil',
      submessage = 'Obteniendo tus datos, por favor espera...',
      variant = LoadingVariant.profile;

  /// Shortcut for saving profile
  const AppLoadingScreen.savingProfile({super.key})
    : message = 'Guardando cambios',
      submessage = 'Actualizando tu información...',
      variant = LoadingVariant.profile;

  /// Shortcut for route loading
  const AppLoadingScreen.findingRoute({super.key})
    : message = 'Calculando ruta',
      submessage = 'Buscando el mejor camino...',
      variant = LoadingVariant.route;

  @override
  State<AppLoadingScreen> createState() => _AppLoadingScreenState();
}

class _AppLoadingScreenState extends State<AppLoadingScreen>
    with TickerProviderStateMixin {
  late final AnimationController _pathController;
  late final AnimationController _pulseController;
  late final AnimationController _dotController;
  late final AnimationController _fadeController;

  late final Animation<double> _pathProgress;
  late final Animation<double> _pulse;
  late final Animation<double> _fade;

  int _dotIndex = 0;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fade = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _fadeController.forward();

    _pathController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();

    _pathProgress = CurvedAnimation(
      parent: _pathController,
      curve: Curves.easeInOut,
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulse = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _dotController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (mounted) {
          setState(() => _dotIndex = (_dotIndex + 1) % 3);
          _dotController.forward(from: 0);
        }
      }
    });
    _dotController.forward();
  }

  @override
  void dispose() {
    _pathController.dispose();
    _pulseController.dispose();
    _dotController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      body: FadeTransition(
        opacity: _fade,
        child: Stack(
          children: [
            // Background gradient blobs
            Positioned(
              top: -80,
              right: -60,
              child: _GradientBlob(
                size: 260,
                color: AppColors.headerTop.withOpacity(0.12),
              ),
            ),
            Positioned(
              bottom: -60,
              left: -40,
              child: _GradientBlob(
                size: 200,
                color: AppColors.headerBottom.withOpacity(0.10),
              ),
            ),

            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // ── Animated illustration ──
                  SizedBox(
                    width: 180,
                    height: 180,
                    child: AnimatedBuilder(
                      animation: Listenable.merge([
                        _pathController,
                        _pulseController,
                      ]),
                      builder: (_, __) {
                        return CustomPaint(
                          painter: _LoadingPainter(
                            progress: _pathProgress.value,
                            pulse: _pulse.value,
                            variant: widget.variant,
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 32),

                  // ── Main message ──
                  Text(
                    widget.message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1E293B),
                      letterSpacing: -0.4,
                    ),
                  ),

                  const SizedBox(height: 10),

                  // ── Cycling step message ──
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    transitionBuilder:
                        (child, anim) => FadeTransition(
                          opacity: anim,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0, 0.25),
                              end: Offset.zero,
                            ).animate(anim),
                            child: child,
                          ),
                        ),
                    child: Text(
                      widget.submessage ?? _currentStep,
                      key: ValueKey(widget.submessage ?? _currentStep),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF8A94A6),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── Animated progress dots ──
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(3, (i) {
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: i == _dotIndex ? 24 : 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color:
                              i == _dotIndex
                                  ? AppColors.headerBottom
                                  : AppColors.headerBottom.withOpacity(0.20),
                          borderRadius: BorderRadius.circular(99),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String get _currentStep {
    final steps = _stepsForVariant(widget.variant);
    return steps[_dotIndex % steps.length];
  }

  List<String> _stepsForVariant(LoadingVariant v) {
    switch (v) {
      case LoadingVariant.profile:
        return [
          'Obteniendo tus datos...',
          'Cargando tu información...',
          'Casi listo...',
        ];
      case LoadingVariant.route:
        return [
          'Calculando la mejor ruta...',
          'Verificando condiciones...',
          'Preparando navegación...',
        ];
      case LoadingVariant.map:
        return [
          'Cargando el mapa...',
          'Buscando parqueos cercanos...',
          'Obteniendo disponibilidad...',
        ];
      case LoadingVariant.general:
      default:
        return ['Cargando...', 'Por favor espera...', 'Casi listo...'];
    }
  }
}

// ─── Gradient blob decoration ──────────────────────────────────────────────────
class _GradientBlob extends StatelessWidget {
  final double size;
  final Color color;

  const _GradientBlob({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}

// ─── Custom painter ────────────────────────────────────────────────────────────
class _LoadingPainter extends CustomPainter {
  final double progress;
  final double pulse;
  final LoadingVariant variant;

  _LoadingPainter({
    required this.progress,
    required this.pulse,
    required this.variant,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    switch (variant) {
      case LoadingVariant.route:
        _drawRoute(canvas, size, cx, cy);
        break;
      case LoadingVariant.map:
        _drawMap(canvas, size, cx, cy);
        break;
      case LoadingVariant.profile:
        _drawProfile(canvas, size, cx, cy);
        break;
      case LoadingVariant.general:
        _drawGeneral(canvas, size, cx, cy);
        break;
    }
  }

  void _drawRoute(Canvas canvas, Size size, double cx, double cy) {
    // Road path
    final roadPaint =
        Paint()
          ..color = const Color(0xFFCBD5E1)
          ..strokeWidth = 6
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;

    final path =
        Path()
          ..moveTo(cx - 55, cy + 50)
          ..cubicTo(cx - 55, cy + 10, cx - 10, cy - 10, cx, cy - 10)
          ..cubicTo(cx + 10, cy - 10, cx + 40, cy - 40, cx + 55, cy - 50);

    canvas.drawPath(path, roadPaint);

    // Animated progress on road
    final progressPaint =
        Paint()
          ..color = AppColors.headerBottom
          ..strokeWidth = 6
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;

    final metrics = path.computeMetrics().first;
    final extractPath = metrics.extractPath(0, metrics.length * progress);
    canvas.drawPath(extractPath, progressPaint);

    // Moving car dot
    if (progress > 0.02) {
      final pos = metrics.getTangentForOffset(metrics.length * progress);
      if (pos != null) {
        final carPaint =
            Paint()
              ..color = AppColors.headerBottom
              ..style = PaintingStyle.fill;

        canvas.drawCircle(pos.position, 7 * pulse, carPaint);
        canvas.drawCircle(
          pos.position,
          10 * pulse,
          Paint()
            ..color = AppColors.headerBottom.withOpacity(0.25)
            ..style = PaintingStyle.fill,
        );
      }
    }

    // Origin dot
    final originPaint =
        Paint()
          ..color = const Color(0xFF16A34A)
          ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx - 55, cy + 50), 8, originPaint);
    canvas.drawCircle(
      Offset(cx - 55, cy + 50),
      12,
      Paint()
        ..color = const Color(0xFF16A34A).withOpacity(0.2)
        ..style = PaintingStyle.fill,
    );

    // Destination pin
    _drawPin(canvas, Offset(cx + 55, cy - 50), pulse);
  }

  void _drawMap(Canvas canvas, Size size, double cx, double cy) {
    // Grid lines (map background)
    final gridPaint =
        Paint()
          ..color = const Color(0xFFCBD5E1)
          ..strokeWidth = 1.2
          ..style = PaintingStyle.stroke;

    for (var i = -3; i <= 3; i++) {
      canvas.drawLine(
        Offset(cx + i * 18, cy - 60),
        Offset(cx + i * 18, cy + 60),
        gridPaint,
      );
      canvas.drawLine(
        Offset(cx - 60, cy + i * 18),
        Offset(cx + 60, cy + i * 18),
        gridPaint,
      );
    }

    // Animated scan circle
    final scanRadius = 20.0 + 40.0 * progress;
    canvas.drawCircle(
      Offset(cx, cy),
      scanRadius,
      Paint()
        ..color = AppColors.headerBottom.withOpacity(0.08 * (1 - progress))
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      Offset(cx, cy),
      scanRadius,
      Paint()
        ..color = AppColors.headerBottom.withOpacity(0.3 * (1 - progress))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // Center pin
    _drawPin(canvas, Offset(cx, cy - 4), pulse);
  }

  void _drawProfile(Canvas canvas, Size size, double cx, double cy) {
    // User silhouette circle
    final bgPaint =
        Paint()
          ..color = AppColors.headerBottom.withOpacity(0.08)
          ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx, cy - 10), 42, bgPaint);

    final borderPaint =
        Paint()
          ..color = AppColors.headerBottom.withOpacity(0.25 + 0.15 * pulse)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5;
    canvas.drawCircle(Offset(cx, cy - 10), 42 * pulse, borderPaint);

    // Head
    canvas.drawCircle(
      Offset(cx, cy - 22),
      16,
      Paint()
        ..color = AppColors.headerBottom.withOpacity(0.55)
        ..style = PaintingStyle.fill,
    );

    // Body arc
    final bodyPath =
        Path()..addArc(
          Rect.fromCenter(center: Offset(cx, cy + 22), width: 54, height: 46),
          math.pi,
          math.pi,
        );
    canvas.drawPath(
      bodyPath,
      Paint()
        ..color = AppColors.headerBottom.withOpacity(0.40)
        ..style = PaintingStyle.fill,
    );

    // Progress arc around circle
    final arcPaint =
        Paint()
          ..color = AppColors.headerBottom
          ..strokeWidth = 4
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCenter(center: Offset(cx, cy - 10), width: 100, height: 100),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      arcPaint,
    );
  }

  void _drawGeneral(Canvas canvas, Size size, double cx, double cy) {
    // Parking P icon background
    final bgPaint =
        Paint()
          ..color = AppColors.headerBottom.withOpacity(0.08)
          ..style = PaintingStyle.fill;

    final rRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, cy), width: 80, height: 80),
      const Radius.circular(22),
    );
    canvas.drawRRect(rRect, bgPaint);

    // Pulsing border
    final borderPaint =
        Paint()
          ..color = AppColors.headerBottom.withOpacity(
            0.20 + 0.15 * (pulse - 0.85) / 0.3,
          )
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(cx, cy),
          width: 80 * pulse,
          height: 80 * pulse,
        ),
        const Radius.circular(22),
      ),
      borderPaint,
    );

    // Draw "P"
    final textPainter = TextPainter(
      text: TextSpan(
        text: 'P',
        style: TextStyle(
          fontSize: 48,
          fontWeight: FontWeight.w900,
          color: AppColors.headerBottom,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(cx - textPainter.width / 2, cy - textPainter.height / 2),
    );

    // Progress arc
    final arcPaint =
        Paint()
          ..color = AppColors.headerBottom
          ..strokeWidth = 4
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCenter(center: Offset(cx, cy), width: 120, height: 120),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      arcPaint,
    );
  }

  void _drawPin(Canvas canvas, Offset center, double pulse) {
    final pinBody =
        Paint()
          ..color = const Color(0xFFDC2626)
          ..style = PaintingStyle.fill;

    final pinPath =
        Path()
          ..moveTo(center.dx, center.dy + 14)
          ..cubicTo(
            center.dx - 16,
            center.dy,
            center.dx - 16,
            center.dy - 20,
            center.dx,
            center.dy - 20,
          )
          ..cubicTo(
            center.dx + 16,
            center.dy - 20,
            center.dx + 16,
            center.dy,
            center.dx,
            center.dy + 14,
          );
    canvas.drawPath(pinPath, pinBody);

    canvas.drawCircle(
      Offset(center.dx, center.dy - 10),
      5,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill,
    );

    // Pulse ring
    canvas.drawCircle(
      Offset(center.dx, center.dy + 14),
      6 * pulse,
      Paint()
        ..color = const Color(0xFFDC2626).withOpacity(0.25)
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(_LoadingPainter old) =>
      old.progress != progress || old.pulse != pulse;
}
