import 'dart:math' as math;
import 'package:flutter/material.dart';

class GameIconPainter extends CustomPainter {
  final String type;
  final double scale;

  GameIconPainter({required this.type, this.scale = 1.0});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 100, size.height / 100);

    switch (type) {
      case 'cash':
        _drawCash(canvas);
        break;
      case 'gem':
        _drawGem(canvas);
        break;
      case 'heart':
        _drawHeart(canvas);
        break;
      case 'mystery_box':
        _drawMysteryBox(canvas);
        break;
      case 'trophy':
        _drawTrophy(canvas);
        break;
      case 'mail':
        _drawMail(canvas);
        break;
      case 'facebook':
        _drawFacebook(canvas);
        break;
      case 'invite':
        _drawInvite(canvas);
        break;
      case 'task':
        _drawTask(canvas);
        break;
      case 'vip':
        _drawVip(canvas);
        break;
      case 'talent':
        _drawTalent(canvas);
        break;
      case 'skin_swirl':
        _drawSkinSwirl(canvas);
        break;
      case 'pu_smash':
        _drawPuSmash(canvas);
        break;
      case 'pu_balls':
        _drawPuBalls(canvas);
        break;
      case 'pu_row':
        _drawPuRow(canvas);
        break;
      case 'pu_fire':
        _drawPuFire(canvas);
        break;
      case 'pu_stone':
        _drawPuStone(canvas);
        break;
    }

    canvas.restore();
  }

  void _drawCash(Canvas canvas) {
    // Stack of dollar bills
    final darkGreen = Paint()..color = const Color(0xFF2E7D32);
    final midGreen = Paint()..color = const Color(0xFF4CAF50);
    final lightGreen = Paint()..color = const Color(0xFF81C784);

    // Bottom note
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(18, 48, 64, 34), const Radius.circular(5)),
      darkGreen,
    );

    // Middle note
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(18, 38, 64, 34), const Radius.circular(5)),
      midGreen,
    );

    // Top note
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(18, 26, 64, 34), const Radius.circular(5)),
      lightGreen,
    );

    // White circle & dollar symbol
    canvas.drawCircle(const Offset(50, 43), 11, Paint()..color = Colors.white.withValues(alpha: 0.85));
    final tp = TextPainter(
      text: const TextSpan(
        text: '\$',
        style: TextStyle(color: Color(0xFF2E7D32), fontSize: 16, fontWeight: FontWeight.w900),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(50 - tp.width / 2, 43 - tp.height / 2));
  }

  void _drawGem(Canvas canvas) {
    // Faceted diamond
    final path = Path()
      ..moveTo(50, 15)
      ..lineTo(82, 38)
      ..lineTo(50, 85)
      ..lineTo(18, 38)
      ..close();

    // Base gradient
    final shader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF80D8FF), Color(0xFF0091EA), Color(0xFF01579B)],
    ).createShader(const Rect.fromLTWH(18, 15, 64, 70));
    canvas.drawPath(path, Paint()..shader = shader);

    // Facet highlights
    final p1 = Path()
      ..moveTo(50, 15)
      ..lineTo(35, 38)
      ..lineTo(50, 85)
      ..close();
    canvas.drawPath(p1, Paint()..color = Colors.white.withValues(alpha: 0.28));

    final pTop = Path()
      ..moveTo(35, 38)
      ..lineTo(50, 15)
      ..lineTo(65, 38)
      ..close();
    canvas.drawPath(pTop, Paint()..color = Colors.white.withValues(alpha: 0.5));
  }

  void _drawHeart(Canvas canvas) {
    final path = Path();
    path.moveTo(50, 32);
    path.cubicTo(50, 18, 20, 14, 20, 42);
    path.cubicTo(20, 62, 42, 78, 50, 88);
    path.cubicTo(58, 78, 80, 62, 80, 42);
    path.cubicTo(80, 14, 50, 18, 50, 32);

    final shader = const RadialGradient(
      center: Alignment(-0.3, -0.3),
      colors: [Color(0xFFFF5252), Color(0xFFD50000), Color(0xFF8B0000)],
    ).createShader(const Rect.fromLTWH(20, 15, 60, 75));
    canvas.drawPath(path, Paint()..shader = shader);

    // Specular highlight
    canvas.drawCircle(const Offset(35, 36), 6, Paint()..color = Colors.white.withValues(alpha: 0.7));
  }

  void _drawMysteryBox(Canvas canvas) {
    // Purple hexagon shield
    final hex = Path();
    for (int i = 0; i < 6; i++) {
      final a = (i * 60 + 30) * math.pi / 180;
      final p = Offset(50 + 46 * math.cos(a), 50 + 46 * math.sin(a));
      i == 0 ? hex.moveTo(p.dx, p.dy) : hex.lineTo(p.dx, p.dy);
    }
    hex.close();
    canvas.drawPath(hex, Paint()..color = const Color(0xFF381B6D));
    canvas.drawPath(
      hex,
      Paint()
        ..color = const Color(0xFF7B3EC9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );

    // 3D Isometric Gold Cube
    // Top face
    final topFace = Path()
      ..moveTo(50, 24)
      ..lineTo(74, 38)
      ..lineTo(50, 52)
      ..lineTo(26, 38)
      ..close();
    canvas.drawPath(topFace, Paint()..color = const Color(0xFFFFE082));

    // Left face
    final leftFace = Path()
      ..moveTo(26, 38)
      ..lineTo(50, 52)
      ..lineTo(50, 78)
      ..lineTo(26, 64)
      ..close();
    canvas.drawPath(leftFace, Paint()..color = const Color(0xFFFFB300));

    // Right face
    final rightFace = Path()
      ..moveTo(74, 38)
      ..lineTo(50, 52)
      ..lineTo(50, 78)
      ..lineTo(74, 64)
      ..close();
    canvas.drawPath(rightFace, Paint()..color = const Color(0xFFFFA000));

    // Question marks on faces
    final tp = TextPainter(
      text: const TextSpan(
        text: '?',
        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(34 - tp.width / 2, 54 - tp.height / 2));
    tp.paint(canvas, Offset(64 - tp.width / 2, 54 - tp.height / 2));
  }

  void _drawTrophy(Canvas canvas) {
    // Golden Cup
    final goldShader = const LinearGradient(
      colors: [Color(0xFFFFEE58), Color(0xFFFFB300), Color(0xFFE65100)],
    ).createShader(const Rect.fromLTWH(20, 20, 60, 60));

    // Cup body
    final cup = Path()
      ..moveTo(28, 25)
      ..lineTo(72, 25)
      ..cubicTo(70, 55, 60, 62, 54, 66)
      ..lineTo(54, 76)
      ..lineTo(64, 76)
      ..lineTo(68, 86)
      ..lineTo(32, 86)
      ..lineTo(36, 76)
      ..lineTo(46, 76)
      ..lineTo(46, 66)
      ..cubicTo(40, 62, 30, 55, 28, 25)
      ..close();
    canvas.drawPath(cup, Paint()..shader = goldShader);

    // Handles
    final handlePaint = Paint()
      ..color = const Color(0xFFFFB300)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5;
    canvas.drawArc(const Rect.fromLTWH(18, 28, 20, 26), math.pi * 0.5, math.pi, false, handlePaint);
    canvas.drawArc(const Rect.fromLTWH(62, 28, 20, 26), -math.pi * 0.5, math.pi, false, handlePaint);

    // Center star medallion
    canvas.drawCircle(const Offset(50, 44), 9, Paint()..color = const Color(0xFF7A2EDB));
    final starPath = Path();
    for (int i = 0; i < 10; i++) {
      final r = i.isEven ? 6.0 : 3.0;
      final a = -math.pi / 2 + i * math.pi / 5;
      final pt = Offset(50 + r * math.cos(a), 44 + r * math.sin(a));
      i == 0 ? starPath.moveTo(pt.dx, pt.dy) : starPath.lineTo(pt.dx, pt.dy);
    }
    starPath.close();
    canvas.drawPath(starPath, Paint()..color = const Color(0xFFFFD54F));
  }

  void _drawMail(Canvas canvas) {
    // Envelope
    final env = RRect.fromRectAndRadius(const Rect.fromLTWH(18, 28, 64, 46), const Radius.circular(8));
    canvas.drawRRect(env, Paint()..color = Colors.white);

    // Flap
    final flap = Path()
      ..moveTo(18, 30)
      ..lineTo(50, 54)
      ..lineTo(82, 30);
    canvas.drawPath(
      flap,
      Paint()
        ..color = const Color(0xFFCFD8DC)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }

  void _drawFacebook(Canvas canvas) {
    canvas.drawCircle(const Offset(50, 50), 38, Paint()..color = const Color(0xFF1877F2));
    final tp = TextPainter(
      text: const TextSpan(
        text: 'f',
        style: TextStyle(
          color: Colors.white,
          fontSize: 54,
          fontWeight: FontWeight.w900,
          fontFamily: 'sans-serif',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(50 - tp.width / 2 + 3, 50 - tp.height / 2));
  }

  void _drawInvite(Canvas canvas) {
    // Two people avatar
    // Blue avatar
    canvas.drawCircle(const Offset(38, 36), 14, Paint()..color = const Color(0xFF00B0FF));
    canvas.drawArc(const Rect.fromLTWH(18, 48, 40, 36), math.pi, math.pi, true, Paint()..color = const Color(0xFF00B0FF));

    // Orange avatar
    canvas.drawCircle(const Offset(62, 40), 12, Paint()..color = const Color(0xFFFF9100));
    canvas.drawArc(const Rect.fromLTWH(46, 52, 34, 30), math.pi, math.pi, true, Paint()..color = const Color(0xFFFF9100));

    // Green plus badge
    canvas.drawCircle(const Offset(70, 70), 12, Paint()..color = const Color(0xFF4CAF50));
    final tp = TextPainter(
      text: const TextSpan(
        text: '+',
        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(70 - tp.width / 2, 70 - tp.height / 2 - 1));
  }

  void _drawTask(Canvas canvas) {
    // Clipboard
    final board = RRect.fromRectAndRadius(const Rect.fromLTWH(24, 20, 52, 66), const Radius.circular(8));
    canvas.drawRRect(board, Paint()..color = const Color(0xFF8D6E63));
    final paper = RRect.fromRectAndRadius(const Rect.fromLTWH(28, 26, 44, 56), const Radius.circular(5));
    canvas.drawRRect(paper, Paint()..color = Colors.white);

    // Clip at top
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(40, 16, 20, 10), const Radius.circular(3)),
      Paint()..color = const Color(0xFFCFD8DC),
    );

    // Checkmarks
    final greenCheck = Paint()
      ..color = const Color(0xFF4CAF50)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    // Row 1
    canvas.drawPath(Path()..moveTo(33, 38)..lineTo(37, 42)..lineTo(44, 34), greenCheck);
    canvas.drawLine(const Offset(48, 38), const Offset(65, 38), Paint()..color = const Color(0xFF90A4AE)..strokeWidth = 2.5);

    // Row 2
    canvas.drawPath(Path()..moveTo(33, 52)..lineTo(37, 56)..lineTo(44, 48), greenCheck);
    canvas.drawLine(const Offset(48, 52), const Offset(65, 52), Paint()..color = const Color(0xFF90A4AE)..strokeWidth = 2.5);

    // Row 3
    canvas.drawPath(Path()..moveTo(33, 66)..lineTo(37, 70)..lineTo(44, 62), greenCheck);
    canvas.drawLine(const Offset(48, 66), const Offset(65, 66), Paint()..color = const Color(0xFF90A4AE)..strokeWidth = 2.5);
  }

  void _drawVip(Canvas canvas) {
    // Gold Hexagon
    final hex = Path();
    for (int i = 0; i < 6; i++) {
      final a = (i * 60) * math.pi / 180;
      final p = Offset(50 + 40 * math.cos(a), 50 + 40 * math.sin(a));
      i == 0 ? hex.moveTo(p.dx, p.dy) : hex.lineTo(p.dx, p.dy);
    }
    hex.close();
    canvas.drawPath(
      hex,
      Paint()
        ..color = const Color(0xFFFFB300)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5,
    );

    // Crown
    final crown = Path()
      ..moveTo(34, 40)
      ..lineTo(38, 28)
      ..lineTo(50, 36)
      ..lineTo(62, 28)
      ..lineTo(66, 40)
      ..close();
    canvas.drawPath(crown, Paint()..color = const Color(0xFFFFD54F));

    // VIP text
    final tp = TextPainter(
      text: const TextSpan(
        text: 'VIP',
        style: TextStyle(
          color: Color(0xFFFFD54F),
          fontSize: 22,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.5,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(50 - tp.width / 2, 45));
  }

  void _drawTalent(Canvas canvas) {
    // Purple Spellbook
    final book = RRect.fromRectAndRadius(const Rect.fromLTWH(22, 20, 56, 64), const Radius.circular(8));
    canvas.drawRRect(book, Paint()..color = const Color(0xFF5E35B1));
    canvas.drawRRect(
      book,
      Paint()
        ..color = const Color(0xFFFFD54F)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );

    // Book corners
    canvas.drawCircle(const Offset(27, 25), 4, Paint()..color = const Color(0xFFFFD54F));
    canvas.drawCircle(const Offset(73, 25), 4, Paint()..color = const Color(0xFFFFD54F));

    // Gold Star on cover
    final star = Path();
    for (int i = 0; i < 10; i++) {
      final r = i.isEven ? 15.0 : 7.0;
      final a = -math.pi / 2 + i * math.pi / 5;
      final pt = Offset(50 + r * math.cos(a), 50 + r * math.sin(a));
      i == 0 ? star.moveTo(pt.dx, pt.dy) : star.lineTo(pt.dx, pt.dy);
    }
    star.close();
    canvas.drawPath(star, Paint()..color = const Color(0xFFFFD54F));

    // Ribbon marker
    final ribbon = Path()
      ..moveTo(45, 80)
      ..lineTo(45, 92)
      ..lineTo(50, 87)
      ..lineTo(55, 92)
      ..lineTo(55, 80)
      ..close();
    canvas.drawPath(ribbon, Paint()..color = const Color(0xFFFFC107));
  }

  void _drawSkinSwirl(Canvas canvas) {
    // Rainbow swirl ball
    const colors = [
      Color(0xFFFF2D8D),
      Color(0xFFFF7A0E),
      Color(0xFFFDBD10),
      Color(0xFF5FBF2B),
      Color(0xFF00E5FF),
      Color(0xFF7A2EDB),
    ];

    final c = const Offset(50, 50);
    const r = 36.0;

    for (int i = 0; i < colors.length; i++) {
      final startA = (i * 60) * math.pi / 180;
      final sweepA = 65 * math.pi / 180;
      final paint = Paint()
        ..color = colors[i]
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(Rect.fromCircle(center: c, radius: r * 0.65), startA, sweepA, false, paint);
    }

    // White shine dot
    canvas.drawCircle(const Offset(40, 40), 6, Paint()..color = Colors.white.withValues(alpha: 0.85));
  }

  // 1. Smash: Yellow block breaking with down arrow
  void _drawPuSmash(Canvas canvas) {
    // Yellow cracked block
    final blockRect = const Rect.fromLTWH(24, 46, 52, 34);
    canvas.drawRRect(
      RRect.fromRectAndRadius(blockRect, const Radius.circular(6)),
      Paint()..color = const Color(0xFFFDBD10),
    );
    // Crack line
    final crack = Path()
      ..moveTo(40, 46)
      ..lineTo(48, 62)
      ..lineTo(58, 80);
    canvas.drawPath(
      crack,
      Paint()
        ..color = const Color(0xFFE65100)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );

    // Blue Down Arrow
    final arrow = Path()
      ..moveTo(50, 46)
      ..lineTo(36, 30)
      ..lineTo(44, 30)
      ..lineTo(44, 14)
      ..lineTo(56, 14)
      ..lineTo(56, 30)
      ..lineTo(64, 30)
      ..close();
    canvas.drawPath(arrow, Paint()..color = const Color(0xFF00B0FF));
    canvas.drawPath(
      arrow,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  // 2. More Balls: White ball + green plus + swoosh
  void _drawPuBalls(Canvas canvas) {
    // Cyan swoosh
    final swoosh = Path()
      ..moveTo(25, 78)
      ..quadraticBezierTo(24, 36, 56, 32)
      ..quadraticBezierTo(38, 52, 42, 78)
      ..close();
    canvas.drawPath(swoosh, Paint()..color = const Color(0xFF00B0FF));

    // White Ball
    canvas.drawCircle(const Offset(52, 44), 16, Paint()..color = Colors.white);
    canvas.drawCircle(const Offset(47, 39), 5, Paint()..color = const Color(0xFFE0E0E0));

    // Green Plus Badge
    canvas.drawCircle(const Offset(68, 30), 10, Paint()..color = const Color(0xFF4CAF50));
    final tp = TextPainter(
      text: const TextSpan(
        text: '+',
        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(68 - tp.width / 2, 30 - tp.height / 2 - 1));
  }

  // 3. Row Blast: Brick row with 3 arrows
  void _drawPuRow(Canvas canvas) {
    // Row of bricks
    const colors = [Color(0xFFFF2D8D), Color(0xFFFDBD10), Color(0xFF5FBF2B), Color(0xFF00B0FF)];
    for (int i = 0; i < 4; i++) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(20.0 + i * 15.5, 48, 13.5, 12), const Radius.circular(2)),
        Paint()..color = colors[i],
      );
    }
    // 3 Arrows pointing down
    for (int i = 0; i < 3; i++) {
      final x = 32.0 + i * 18.0;
      final arrow = Path()
        ..moveTo(x, 42)
        ..lineTo(x - 6, 30)
        ..lineTo(x - 2, 30)
        ..lineTo(x - 2, 20)
        ..lineTo(x + 2, 20)
        ..lineTo(x + 2, 30)
        ..lineTo(x + 6, 30)
        ..close();
      canvas.drawPath(arrow, Paint()..color = const Color(0xFF00B0FF));
    }
    // Floor bracket line
    canvas.drawRect(const Rect.fromLTWH(18, 66, 64, 4), Paint()..color = Colors.white);
  }

  // 4. Fire Ball: Ball with flame + x2
  void _drawPuFire(Canvas canvas) {
    // Flames
    final flame = Path()
      ..moveTo(56, 34)
      ..cubicTo(74, 18, 70, 48, 72, 60)
      ..cubicTo(74, 74, 52, 78, 44, 68)
      ..close();
    canvas.drawPath(flame, Paint()..color = const Color(0xFFFF9100));

    // Inner yellow flame
    final innerFlame = Path()
      ..moveTo(54, 40)
      ..cubicTo(66, 28, 64, 50, 65, 58)
      ..close();
    canvas.drawPath(innerFlame, Paint()..color = const Color(0xFFFFEA00));

    // White ball
    canvas.drawCircle(const Offset(40, 56), 14, Paint()..color = Colors.white);

    // x2 badge
    final tp = TextPainter(
      text: const TextSpan(
        text: 'x2',
        style: TextStyle(
          color: Color(0xFFFFD54F),
          fontSize: 16,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(58, 62));
  }

  // 5. Stone Breaker: 3 stone blocks with heavy blue arrow
  void _drawPuStone(Canvas canvas) {
    // 3 stone blocks
    for (int i = 0; i < 3; i++) {
      final rect = Rect.fromLTWH(24.0 + i * 18, 56, 16, 16);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(3)),
        Paint()..color = const Color(0xFF78909C),
      );
      // dots on stone
      canvas.drawCircle(rect.center + const Offset(-2, -2), 1.5, Paint()..color = const Color(0xFF37474F));
      canvas.drawCircle(rect.center + const Offset(3, 3), 1.5, Paint()..color = const Color(0xFF37474F));
    }

    // Heavy down arrow
    final arrow = Path()
      ..moveTo(50, 48)
      ..lineTo(34, 30)
      ..lineTo(44, 30)
      ..lineTo(44, 14)
      ..lineTo(56, 14)
      ..lineTo(56, 30)
      ..lineTo(66, 30)
      ..close();
    canvas.drawPath(arrow, Paint()..color = const Color(0xFF00B0FF));
    canvas.drawPath(
      arrow,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
