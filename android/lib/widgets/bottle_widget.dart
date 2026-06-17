import 'dart:math';

import 'package:flutter/material.dart';

import '../game/bottle.dart';

/// Renders a single bottle as a flask: rounded body, narrow neck, glass shine,
/// a cork cap when fully sorted, and a one-shot sparkle burst the moment it
/// becomes sorted.
class BottleWidget extends StatefulWidget {
  const BottleWidget({
    super.key,
    required this.bottle,
    required this.selected,
    required this.pouring,
    required this.onTap,
  });

  final Bottle bottle;
  final bool selected;
  final bool pouring;
  final VoidCallback onTap;

  // Flask geometry. Picked so the proportions match typical Water Sort art.
  static const double _width = 64;
  static const double _neckWidth = 30;
  static const double _neckHeight = 14;
  static const double _shoulderHeight = 14;
  static const double _segmentHeight = 34;

  // Space above the flask reserved so the cap can pop out without clipping.
  static const double _capPadding = 10;

  // Extra padding around the flask so sparkles can extend past its edges.
  static const double _sparkleMargin = 18;

  static const double _capWidth = 38;

  /// Outer box size BottleWidget will occupy for a bottle with [capacity]
  /// slots. Used by callers to compute fit-to-screen scaling.
  static Size naturalSize(int capacity) {
    final body = _segmentHeight * capacity;
    final flask = _neckHeight + _shoulderHeight + body;
    final w = _width + _sparkleMargin * 2;
    final h = flask + _capPadding + _sparkleMargin * 2;
    return Size(w, h);
  }

  @override
  State<BottleWidget> createState() => _BottleWidgetState();
}

class _BottleWidgetState extends State<BottleWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _sparkle;
  bool _wasSolved = false;

  @override
  void initState() {
    super.initState();
    _sparkle = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _wasSolved = widget.bottle.isSolved && !widget.bottle.isEmpty;
  }

  @override
  void didUpdateWidget(covariant BottleWidget old) {
    super.didUpdateWidget(old);
    final solved = widget.bottle.isSolved && !widget.bottle.isEmpty;
    if (solved && !_wasSolved) {
      _sparkle.forward(from: 0);
    }
    _wasSolved = solved;
  }

  @override
  void dispose() {
    _sparkle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final solved = widget.bottle.isSolved && !widget.bottle.isEmpty;
    final topColor = widget.bottle.topColor;
    const margin = BottleWidget._sparkleMargin;
    final capacity = widget.bottle.capacity;
    final bodyHeight = BottleWidget._segmentHeight * capacity;
    final flaskHeight = BottleWidget._neckHeight +
        BottleWidget._shoulderHeight +
        bodyHeight;

    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        offset: widget.selected ? const Offset(0, -0.06) : Offset.zero,
        child: AnimatedRotation(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeInOut,
          turns: widget.pouring ? 0.06 : 0,
          child: SizedBox(
            width: BottleWidget._width + margin * 2,
            height: flaskHeight +
                BottleWidget._capPadding +
                margin * 2,
            child: Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                // Liquid + glass tint clipped to the flask silhouette.
                Positioned(
                  top: BottleWidget._capPadding + margin,
                  left: margin,
                  width: BottleWidget._width,
                  height: flaskHeight,
                  child: ClipPath(
                    clipper: const _FlaskClipper(),
                    child: Stack(
                      children: <Widget>[
                        Positioned.fill(
                          child: Container(color: const Color(0x14FFFFFF)),
                        ),
                        Positioned(
                          top: BottleWidget._neckHeight +
                              BottleWidget._shoulderHeight,
                          left: 0,
                          right: 0,
                          height: bodyHeight,
                          child: Column(children: _slots()),
                        ),
                        // Glass shine on the left edge.
                        Positioned(
                          top: BottleWidget._neckHeight +
                              BottleWidget._shoulderHeight +
                              4,
                          bottom: 6,
                          left: 5,
                          width: 3,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.30),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        // Subtle right-edge shadow.
                        Positioned(
                          top: BottleWidget._neckHeight +
                              BottleWidget._shoulderHeight +
                              4,
                          bottom: 6,
                          right: 4,
                          width: 2,
                          child: Container(
                            color: Colors.black.withValues(alpha: 0.18),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Glass outline on top of the liquid.
                Positioned(
                  top: BottleWidget._capPadding + margin,
                  left: margin,
                  width: BottleWidget._width,
                  height: flaskHeight,
                  child: CustomPaint(
                    painter: _OutlinePainter(selected: widget.selected),
                  ),
                ),
                // Cork cap appears when the bottle is fully sorted.
                Positioned(
                  top: margin,
                  left: margin + (BottleWidget._width - BottleWidget._capWidth) / 2,
                  child: AnimatedScale(
                    duration: const Duration(milliseconds: 240),
                    curve: Curves.elasticOut,
                    scale: solved ? 1.0 : 0.0,
                    child: _CorkCap(color: topColor ?? Colors.brown),
                  ),
                ),
                // Sparkle burst overlay, drawn on top of everything.
                Positioned.fill(
                  child: IgnorePointer(
                    child: AnimatedBuilder(
                      animation: _sparkle,
                      builder: (context, _) {
                        if (_sparkle.value == 0) {
                          return const SizedBox.shrink();
                        }
                        return CustomPaint(
                          painter: _SparklePainter(
                            progress: _sparkle.value,
                            color: topColor ?? Colors.white,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _slots() {
    final slots = <Widget>[];
    final capacity = widget.bottle.capacity;
    // Render top-down within the body. Each slot maps to an absolute
    // position so units don't visually shift sideways during a pour;
    // their colors just fade in / out.
    for (int row = 0; row < capacity; row++) {
      final pos = capacity - 1 - row;
      final color = pos < widget.bottle.units.length
          ? widget.bottle.units[pos]
          : Colors.transparent;
      slots.add(AnimatedContainer(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOut,
        width: BottleWidget._width,
        height: BottleWidget._segmentHeight,
        color: color,
      ));
    }
    return slots;
  }
}

/// The flask silhouette: short neck, sloped shoulders, deeply rounded base.
class _FlaskClipper extends CustomClipper<Path> {
  const _FlaskClipper();

  @override
  Path getClip(Size size) => _buildFlaskPath(size);

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

Path _buildFlaskPath(Size size) {
  final w = size.width;
  final h = size.height;
  const neckW = BottleWidget._neckWidth;
  const neckH = BottleWidget._neckHeight;
  const shoulderH = BottleWidget._shoulderHeight;
  final neckLeft = (w - neckW) / 2;
  final neckRight = neckLeft + neckW;
  final shoulderY = neckH + shoulderH;
  final bottomR = w * 0.42;

  return Path()
    ..moveTo(neckLeft, 0)
    ..lineTo(neckLeft, neckH)
    ..quadraticBezierTo(neckLeft - 4, neckH + 2, 0, shoulderY)
    ..lineTo(0, h - bottomR)
    ..quadraticBezierTo(0, h, bottomR, h)
    ..lineTo(w - bottomR, h)
    ..quadraticBezierTo(w, h, w, h - bottomR)
    ..lineTo(w, shoulderY)
    ..quadraticBezierTo(neckRight + 4, neckH + 2, neckRight, neckH)
    ..lineTo(neckRight, 0)
    ..close();
}

class _OutlinePainter extends CustomPainter {
  const _OutlinePainter({required this.selected});

  final bool selected;

  @override
  void paint(Canvas canvas, Size size) {
    final path = _buildFlaskPath(size);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = selected ? 3 : 2.2
      ..strokeJoin = StrokeJoin.round
      ..color = selected ? Colors.amber : Colors.white.withValues(alpha: 0.85);
    canvas.drawPath(path, stroke);
  }

  @override
  bool shouldRepaint(covariant _OutlinePainter old) =>
      old.selected != selected;
}

/// A small rounded cork that sits on the neck when the bottle is solved.
/// Tinted with the bottle's color so it reads as "sealed".
class _CorkCap extends StatelessWidget {
  const _CorkCap({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 14,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Color.lerp(color, Colors.white, 0.35)!,
            color,
            Color.lerp(color, Colors.black, 0.25)!,
          ],
        ),
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(6),
          bottom: Radius.circular(3),
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.7),
          width: 1.2,
        ),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Colors.black54,
            blurRadius: 3,
            offset: Offset(0, 1),
          ),
        ],
      ),
    );
  }
}

/// Draws a one-shot sparkle burst around the flask. [progress] runs 0→1.
/// Sparkles are placed at deterministic positions around the bottle so the
/// burst feels stable but varied.
class _SparklePainter extends CustomPainter {
  _SparklePainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  static const int _count = 10;
  // Deterministic per-sparkle offsets (angle in turns, radius factor,
  // size factor, start delay 0-0.4, peak time 0.5-0.8).
  static final List<_SparkleSpec> _specs = _buildSpecs();

  static List<_SparkleSpec> _buildSpecs() {
    final rng = Random(7);
    return List<_SparkleSpec>.generate(_count, (_) {
      return _SparkleSpec(
        angle: rng.nextDouble() * 2 * pi,
        radius: 0.45 + rng.nextDouble() * 0.45,
        size: 6 + rng.nextDouble() * 6,
        delay: rng.nextDouble() * 0.35,
        rotation: rng.nextDouble() * pi,
      );
    });
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    // Cap radius to the smaller half-dimension so sparkles stay near the bottle.
    final maxR = min(size.width, size.height) / 2;
    for (final s in _specs) {
      final local = ((progress - s.delay) / (1 - s.delay)).clamp(0.0, 1.0);
      if (local <= 0) continue;
      // Opacity peaks mid-animation, fades out by the end.
      final opacity = sin(local * pi);
      if (opacity <= 0) continue;
      // Sparkle starts close to center and drifts outward.
      final r = maxR * s.radius * (0.4 + 0.6 * local);
      final pos = center + Offset(cos(s.angle), sin(s.angle)) * r;
      final scale = (0.4 + 0.8 * sin(local * pi)).clamp(0.0, 1.6);
      _drawStar(
        canvas: canvas,
        center: pos,
        radius: s.size * scale,
        rotation: s.rotation + local * pi,
        opacity: opacity,
      );
    }
  }

  void _drawStar({
    required Canvas canvas,
    required Offset center,
    required double radius,
    required double rotation,
    required double opacity,
  }) {
    final path = Path();
    const points = 4;
    final inner = radius * 0.35;
    for (int i = 0; i < points * 2; i++) {
      final isOuter = i.isEven;
      final r = isOuter ? radius : inner;
      final a = rotation + i * pi / points;
      final p = center + Offset(cos(a), sin(a)) * r;
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    canvas.drawPath(
      path,
      Paint()..color = Colors.white.withValues(alpha: opacity * 0.95),
    );
    // Coloured halo behind each star.
    canvas.drawCircle(
      center,
      radius * 0.7,
      Paint()..color = color.withValues(alpha: opacity * 0.35),
    );
  }

  @override
  bool shouldRepaint(covariant _SparklePainter old) =>
      old.progress != progress || old.color != color;
}

class _SparkleSpec {
  const _SparkleSpec({
    required this.angle,
    required this.radius,
    required this.size,
    required this.delay,
    required this.rotation,
  });

  final double angle;
  final double radius;
  final double size;
  final double delay;
  final double rotation;
}
