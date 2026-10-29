import 'dart:math' as math;
import 'package:flutter/material.dart';

class BloopPopLogo extends StatefulWidget {
  final double scale;
  const BloopPopLogo({super.key, this.scale = 1.0});

  @override
  State<BloopPopLogo> createState() => _BloopPopLogoState();
}

class _BloopPopLogoState extends State<BloopPopLogo> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        final bob = math.sin(_ctrl.value * math.pi * 2) * 4.0;
        final ballBounce = (math.sin(_ctrl.value * math.pi * 4).abs()) * 8.5;

        return Transform.translate(
          offset: Offset(0, bob),
          child: CustomPaint(
            size: Size(340 * widget.scale, 160 * widget.scale),
            painter: _LogoPainter(ballBounce: ballBounce, animT: _ctrl.value),
          ),
        );
      },
    );
  }
}

class _LogoPainter extends CustomPainter {
  final double ballBounce;
  final double animT;

  _LogoPainter({required this.ballBounce, required this.animT});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 340, size.height / 160);

    // 1. Draw Arched Candy Blocks Row below the title
    _drawBlockArch(canvas);

    // 2. Draw Bubble Kids "BloopPop" Wordmark with 3D depth and glossy shine
    _drawBubbleTitle(canvas);

    // 3. Draw Golden Crown on top of 'B'
    _drawCrown(canvas);

    // 4. Draw glossy ball bouncing on the blocks with impact sparks
    _drawBouncingBall(canvas);

    canvas.restore();
  }

  void _drawBlockArch(Canvas canvas) {
    const colors = [
      Color(0xFFFF2D8D), // pink
      Color(0xFFFF7A0E), // orange
      Color(0xFFFDBD10), // yellow
      Color(0xFF5FBF2B), // green
      Color(0xFF7A2EDB), // purple
      Color(0xFF0B86EA), // blue
    ];
    const shades = [
      Color(0xFFC81467),
      Color(0xFFC85705),
      Color(0xFFC69004),
      Color(0xFF448D1D),
      Color(0xFF571B9F),
      Color(0xFF0761AB),
    ];

    final blockW = 44.0;
    final blockH = 26.0;
    final startX = 35.0;

    for (int i = 0; i < 6; i++) {
      final x = startX + i * (blockW + 4);
      final archY = 104.0 + math.sin((i - 2.5) / 2.5 * 0.8) * 6.0;

      final rect = Rect.fromLTWH(x, archY, blockW, blockH);
      final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(8));
      final shadeRRect = RRect.fromRectAndRadius(rect.shift(const Offset(0, 4)), const Radius.circular(8));

      // Dark border
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect.inflate(3).shift(const Offset(0, 2)), const Radius.circular(10)),
        Paint()..color = const Color(0xFF1E0E57),
      );

      // 3D bottom bevel
      canvas.drawRRect(shadeRRect, Paint()..color = shades[i]);
      // Top face
      canvas.drawRRect(rrect, Paint()..color = colors[i]);

      // Top glossy highlight
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(rect.left + 3, rect.top + 2, rect.width - 6, 7),
          const Radius.circular(4),
        ),
        Paint()..color = Colors.white.withValues(alpha: 0.3),
      );
    }
  }

  void _drawBubbleTitle(Canvas canvas) {
    // Bubble letters configuration for "Bloop" (Cyan) and "Pop" (Yellow)
    // Each letter has playful tilt and custom bouncy baseline
    final bloopLetters = [
      _BubbleLetter('B', 18, 14, -0.07, 74),
      _BubbleLetter('l', 66, 12, 0.05, 72),
      _BubbleLetter('o', 92, 19, -0.06, 66),
      _BubbleLetter('o', 126, 18, 0.07, 66),
      _BubbleLetter('p', 158, 17, -0.05, 70),
    ];

    final popLetters = [
      _BubbleLetter('P', 194, 12, -0.08, 76),
      _BubbleLetter('o', 242, 18, 0.06, 66),
      _BubbleLetter('p', 276, 16, -0.05, 70),
    ];

    // Gradients for bubble fills
    const bloopGrad = [Color(0xFFE0F7FA), Color(0xFF00E5FF), Color(0xFF0091EA), Color(0xFF0D47A1)];
    const popGrad = [Color(0xFFFFFDE7), Color(0xFFFFEA00), Color(0xFFFF9100), Color(0xFFE65100)];

    // 1. Draw Deep 3D Drop Shadows for all letters
    for (final l in bloopLetters) {
      _drawLetterPass(canvas, l, isShadow: true);
    }
    for (final l in popLetters) {
      _drawLetterPass(canvas, l, isShadow: true);
    }

    // 2. Draw Thick Outer Bubble Outline
    for (final l in bloopLetters) {
      _drawLetterPass(canvas, l, isOutline: true);
    }
    for (final l in popLetters) {
      _drawLetterPass(canvas, l, isOutline: true);
    }

    // 3. Draw Inner Vibrant Gradient Core
    for (final l in bloopLetters) {
      _drawLetterPass(canvas, l, gradientColors: bloopGrad);
    }
    for (final l in popLetters) {
      _drawLetterPass(canvas, l, gradientColors: popGrad);
    }

    // 4. Draw Inflatable Bubble Gloss Highlights (Specular Sheen)
    _drawGlossHighlights(canvas);
  }

  void _drawLetterPass(
    Canvas canvas,
    _BubbleLetter letter, {
    bool isShadow = false,
    bool isOutline = false,
    List<Color>? gradientColors,
  }) {
    canvas.save();
    canvas.translate(letter.x + 20, letter.y + 35);
    canvas.rotate(letter.rot);
    canvas.translate(-(letter.x + 20), -(letter.y + 35));

    const fontFamily = 'BiscuitGlitch';
    final baseStyle = const TextStyle(
      fontFamily: fontFamily,
      fontWeight: FontWeight.w900,
    ).copyWith(fontSize: letter.size);

    TextStyle style;
    Offset offset = Offset(letter.x, letter.y);

    if (isShadow) {
      offset += const Offset(0, 7);
      style = baseStyle.copyWith(
        foreground: Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 16
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round
          ..color = const Color(0xFF14073C),
      );
    } else if (isOutline) {
      style = baseStyle.copyWith(
        foreground: Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 11
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round
          ..color = const Color(0xFF261066),
      );
    } else {
      final shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: gradientColors ?? [Colors.white, Colors.cyan],
        stops: const [0.0, 0.35, 0.85, 1.0],
      ).createShader(Rect.fromLTWH(letter.x, letter.y, letter.size, letter.size * 1.2));

      style = baseStyle.copyWith(
        foreground: Paint()..shader = shader,
      );
    }

    final tp = TextPainter(
      text: TextSpan(text: letter.char, style: style),
      textDirection: TextDirection.ltr,
    )..layout();

    tp.paint(canvas, offset);
    canvas.restore();
  }

  void _drawGlossHighlights(Canvas canvas) {
    // Specular bubble shine pills/arcs placed on the top-left curve of letters
    final shinePaint = Paint()..color = Colors.white.withValues(alpha: 0.65);
    final dotPaint = Paint()..color = Colors.white.withValues(alpha: 0.8);

    // B shines
    _shineCapsule(canvas, const Offset(32, 28), 8, 4, -0.3, shinePaint);
    _shineCapsule(canvas, const Offset(34, 46), 7, 3.5, -0.2, shinePaint);

    // l shine
    _shineCapsule(canvas, const Offset(74, 25), 14, 3.5, 0.05, shinePaint);

    // first o shine
    _shineArc(canvas, const Offset(105, 34), 10, shinePaint);
    canvas.drawCircle(const Offset(100, 42), 2, dotPaint);

    // second o shine
    _shineArc(canvas, const Offset(138, 33), 10, shinePaint);
    canvas.drawCircle(const Offset(133, 41), 2, dotPaint);

    // p shine
    _shineArc(canvas, const Offset(172, 33), 10, shinePaint);

    // P shines
    _shineCapsule(canvas, const Offset(208, 25), 12, 4.5, -0.3, shinePaint);
    canvas.drawCircle(const Offset(224, 26), 2.5, dotPaint);

    // pop o shine
    _shineArc(canvas, const Offset(255, 33), 10, shinePaint);
    canvas.drawCircle(const Offset(250, 41), 2, dotPaint);

    // pop p shine
    _shineArc(canvas, const Offset(290, 31), 10, shinePaint);
  }

  void _shineCapsule(Canvas canvas, Offset pos, double length, double radius, double rot, Paint paint) {
    canvas.save();
    canvas.translate(pos.dx, pos.dy);
    canvas.rotate(rot);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: length, height: radius * 2), Radius.circular(radius)),
      paint,
    );
    canvas.restore();
  }

  void _shineArc(Canvas canvas, Offset center, double radius, Paint paint) {
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      math.pi * 1.1,
      math.pi * 0.55,
      false,
      Paint()
        ..color = paint.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.2
        ..strokeCap = StrokeCap.round,
    );
  }

  void _drawCrown(Canvas canvas) {
    // Perched right on top of capital 'B'
    canvas.save();
    canvas.translate(34, 15);
    canvas.rotate(-0.18);

    // Crown outline
    final crown = Path()
      ..moveTo(-16, 10)
      ..lineTo(-21, -4)
      ..lineTo(-9, 3)
      ..lineTo(0, -9)
      ..lineTo(9, 3)
      ..lineTo(21, -4)
      ..lineTo(16, 10)
      ..close();

    // Dark outline
    canvas.drawPath(
      crown,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5.5
        ..strokeJoin = StrokeJoin.round
        ..color = const Color(0xFF160738),
    );

    // Gold gradient fill
    final goldShader = const LinearGradient(
      colors: [Color(0xFFFFF176), Color(0xFFFFB300), Color(0xFFFF8F00)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ).createShader(const Rect.fromLTWH(-21, -9, 42, 19));
    canvas.drawPath(crown, Paint()..shader = goldShader);

    // Crown jewels
    canvas.drawCircle(const Offset(-21, -4), 2.2, Paint()..color = Colors.white);
    canvas.drawCircle(const Offset(0, -9), 2.8, Paint()..color = Colors.white);
    canvas.drawCircle(const Offset(21, -4), 2.2, Paint()..color = Colors.white);

    // Center ruby jewel
    canvas.drawCircle(const Offset(0, 3), 2.5, Paint()..color = const Color(0xFFE91E63));

    canvas.restore();
  }

  void _drawBouncingBall(Canvas canvas) {
    // Ball sits at x = 170 (between yellow block 2 and green block 3)
    final bx = 170.0;
    final by = 108.0 - ballBounce;
    final rad = 18.0;

    // Drop shadow under ball on blocks
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(170, 114), width: 22 - ballBounce * 0.4, height: 7),
      Paint()..color = Colors.black.withValues(alpha: 0.35),
    );

    // White ball with dark outline
    canvas.drawCircle(
      Offset(bx, by),
      rad + 2,
      Paint()..color = const Color(0xFF1B0C4A),
    );
    canvas.drawCircle(
      Offset(bx, by),
      rad,
      Paint()..color = Colors.white,
    );

    // Specular shine
    canvas.drawCircle(
      Offset(bx - 5, by - 5),
      rad * 0.35,
      Paint()..color = const Color(0xFFE1F5FE),
    );

    // Star flash near ball when it hits the ground
    if (ballBounce < 2.0) {
      final flashStar = Path();
      for (int i = 0; i < 10; i++) {
        final r = i.isEven ? 8.5 : 3.8;
        final a = animT * math.pi + i * math.pi / 5;
        final p = Offset(bx + 16 + r * math.cos(a), by - 10 + r * math.sin(a));
        i == 0 ? flashStar.moveTo(p.dx, p.dy) : flashStar.lineTo(p.dx, p.dy);
      }
      flashStar.close();
      canvas.drawPath(flashStar, Paint()..color = const Color(0xFFFFFF8D));
    }
  }

  @override
  bool shouldRepaint(covariant _LogoPainter old) =>
      old.ballBounce != ballBounce || old.animT != animT;
}

class _BubbleLetter {
  final String char;
  final double x;
  final double y;
  final double rot;
  final double size;

  const _BubbleLetter(this.char, this.x, this.y, this.rot, this.size);
}
