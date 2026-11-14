import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/layout.dart';
import '../core/theme.dart';
import 'engine.dart';
import 'models.dart';

class GamePainter extends CustomPainter {
  GamePainter({
    required this.engine,
    required this.ballSkin,
    this.ballTrail = 'neon',
    super.repaint,
  });

  final GameEngine engine;
  final String ballSkin;
  final String ballTrail;
  static final Map<String, TextPainter> _tpCache = {};

  TextPainter _text(String s, double size, {Color color = Colors.white, FontWeight weight = FontWeight.w700}) {
    final key = '$s@${size.round()}@${color.toARGB32()}';
    return _tpCache.putIfAbsent(key, () {
      final tp = TextPainter(
        text: TextSpan(
          text: s,
          style: TextStyle(
            fontFamily: 'Fredoka',
            fontWeight: weight,
            fontSize: size,
            color: color,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      return tp;
    });
  }

  @override
  void paint(Canvas canvas, Size size) {
    final l = engine.layout;

    // Background gradient for rich arcade depth
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFF1B1E5C),
          Color(0xFF13154A),
          Color(0xFF0D0F35),
        ],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, bgPaint);

    // Grid blocks
    for (final b in engine.blocks) {
      if (b.hp <= 0 && b.dying > 1.0) continue;
      final rect = l.blockRect(b.col, b.row);
      var scale = 1.0 - 0.12 * b.pulse;
      if (b.dying > 0) {
        scale = (1.0 - b.dying).clamp(0.0, 1.0);
      }
      final c = rect.center;
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.scale(scale);
      canvas.translate(-c.dx, -c.dy);
      _drawBlock(canvas, l, b, rect);
      canvas.restore();
    }

    // Orbs
    for (final o in engine.orbs) {
      if (o.consumed) continue;
      _drawOrb(canvas, l, o);
    }

    // Floor line
    _drawFloorLine(canvas, l);

    // Aim trajectory line
    if (engine.phase == Phase.aiming) {
      _drawAim(canvas, l);
    }

    // Ball Trails
    _drawBallTrails(canvas, l);

    // Balls
    _drawBalls(canvas, l);

    // Lightning bolts (observed in Level 3!)
    for (final bolt in engine.bolts) {
      _drawBolt(canvas, bolt, l);
    }

    // Particle star bursts and streaks
    _drawParticles(canvas, l);

    // Ball counter under floor line
    _drawCounter(canvas, l);
  }

  void _drawBlock(Canvas canvas, Layout l, Block b, Rect rect) {
    if (b.isBoss) {
      _drawBossBlock(canvas, l, b, rect);
      return;
    }

    if (b.isDrone) {
      _drawDroneBlock(canvas, l, b, rect);
      return;
    }

    final colorIdx = b.colorIndex % GameColors.blockColors.length;
    final baseColor = GameColors.blockColors[colorIdx];
    final shadeColor = GameColors.blockShades[colorIdx];
    final textColor = GameColors.blockDarkTexts[colorIdx];

    // Exaggerated chubby cartoon corner radius & 3D bevel
    final rad = Radius.circular(l.cellW * 0.22);
    final fillPaint = Paint()..color = baseColor;
    final shadePaint = Paint()..color = shadeColor;
    final bevelH = (5.5 * l.u).clamp(3.0, 7.5);

    if (b.kind == BlockKind.square) {
      // 1. Soft bottom ambient neon drop shadow
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect.shift(Offset(0, bevelH + 2 * l.u)), rad),
        Paint()
          ..color = shadeColor.withValues(alpha: 0.5)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 4 * l.u),
      );

      // 2. Chunky 3D bottom bevel
      final shadeRRect = RRect.fromRectAndRadius(rect.shift(Offset(0, bevelH)), rad);
      canvas.drawRRect(shadeRRect, shadePaint);

      // 3. Top glossy neon cartoon face
      final topRRect = RRect.fromRectAndRadius(rect, rad);
      canvas.drawRRect(topRRect, fillPaint);

      // 4. Inset border highlight for toy/candy depth
      canvas.drawRRect(
        topRRect,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.25)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6 * l.u,
      );

      // 5. Cartoon pill specular glossy sheen
      final highlightRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(rect.left + 3.5 * l.u, rect.top + 2.5 * l.u, rect.width - 7 * l.u, rect.height * 0.32),
        Radius.circular(l.cellW * 0.16),
      );
      canvas.drawRRect(
        highlightRect,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.35)
          ..style = PaintingStyle.fill,
      );
    } else {
      // Triangle block
      final pts = _triPts(rect, b.kind);
      final path = Path()..addPolygon(pts, true);

      // 3D shade
      final shadePath = Path()..addPolygon(pts.map((p) => p + Offset(0, bevelH)).toList(), true);
      canvas.drawPath(shadePath, shadePaint);
      canvas.drawPath(path, fillPaint);

      // Specular line on triangle hypotenuse
      final hlPath = Path()
        ..moveTo(pts[0].dx, pts[0].dy)
        ..lineTo(pts[1].dx, pts[1].dy);
      canvas.drawPath(
        hlPath,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.35)
          ..strokeWidth = 2.5 * l.u
          ..style = PaintingStyle.stroke,
      );
    }

    // Dynamic Deep Contrast Dark Number with stamped toy engraving look
    final fs = math.min(l.cellW, l.cellH) * 0.50;
    final tp = _text('${b.hp}', fs, color: textColor, weight: FontWeight.w900);
    Offset c = rect.center;
    if (b.kind != BlockKind.square) {
      final pts = _triPts(rect, b.kind);
      c = (pts[0] + pts[1] + pts[2]) / 3;
    }

    // Stamped subtle inner highlight under number
    final tpUnder = _text('${b.hp}', fs, color: Colors.white.withValues(alpha: 0.25), weight: FontWeight.w900);
    tpUnder.paint(canvas, c - Offset(tpUnder.width / 2, tpUnder.height / 2 - 1.2 * l.u));

    // Crisp dark text
    tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
  }

  void _drawBossBlock(Canvas canvas, Layout l, Block b, Rect rect) {
    final fillPaint = Paint()
      ..shader = LinearGradient(
        colors: engine.bossEnraged
            ? const [Color(0xFFFF0055), Color(0xFFFF5252)]
            : const [Color(0xFFFF1744), Color(0xFFD500F9)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(rect);

    final rad = Radius.circular(l.cellW * 0.18);
    final topRRect = RRect.fromRectAndRadius(rect, rad);
    canvas.drawRRect(topRRect, fillPaint);

    // Glowing border (Flashing yellow when reflective energy shield is active)
    final glowColor = engine.bossShieldActive
        ? const Color(0xFFFFEA00)
        : engine.bossEnraged
            ? const Color(0xFFFF1744)
            : const Color(0xFFFF4081);

    final glowPaint = Paint()
      ..color = glowColor.withValues(alpha: engine.bossShieldActive ? 0.95 : 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = (engine.bossShieldActive ? 4.0 : 2.5) * l.u;
    canvas.drawRRect(topRRect, glowPaint);

    // Shield active indicator ring
    if (engine.bossShieldActive) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect.inflate(3 * l.u), Radius.circular(l.cellW * 0.22)),
        Paint()
          ..color = const Color(0xFFFFD600).withValues(alpha: 0.6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8 * l.u,
      );
    }

    // HP Text
    final fs = math.min(l.cellW, l.cellH) * 0.5;
    final tp = _text('${b.hp}', fs, color: Colors.white, weight: FontWeight.w900);
    tp.paint(canvas, rect.center - Offset(tp.width / 2, tp.height / 2));
  }

  void _drawDroneBlock(Canvas canvas, Layout l, Block b, Rect rect) {
    final fillPaint = Paint()..color = const Color(0xFF651FFF);
    final rad = Radius.circular(l.cellW * 0.16);
    final topRRect = RRect.fromRectAndRadius(rect, rad);
    canvas.drawRRect(topRRect, fillPaint);

    final borderPaint = Paint()
      ..color = const Color(0xFFB388FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0 * l.u;
    canvas.drawRRect(topRRect, borderPaint);

    // Drone HP
    final fs = math.min(l.cellW, l.cellH) * 0.5;
    final tp = _text('${b.hp}', fs, color: Colors.white, weight: FontWeight.w800);
    tp.paint(canvas, rect.center - Offset(tp.width / 2, tp.height / 2));
  }

  void _drawBallTrails(Canvas canvas, Layout l) {
    if (ballTrail == 'none') return;

    for (final b in engine.balls) {
      if (b.landed || b.trail.isEmpty) continue;

      for (var i = 0; i < b.trail.length; i++) {
        final pt = b.trail[i];
        final frac = 1.0 - (i / b.trail.length);
        final r = l.r * frac * 0.8;

        Color trailColor;
        switch (ballTrail) {
          case 'rainbow':
            const rainbow = [
              Color(0xFFFF1744),
              Color(0xFFFF9100),
              Color(0xFFFFEA00),
              Color(0xFF00E676),
              Color(0xFF00E5FF),
              Color(0xFFD500F9),
            ];
            trailColor = rainbow[i % rainbow.length].withValues(alpha: frac * 0.75);
            break;
          case 'fire':
            trailColor = (i.isEven ? const Color(0xFFFF3D00) : const Color(0xFFFFD600)).withValues(alpha: frac * 0.75);
            break;
          case 'cosmic':
            trailColor = (i.isEven ? const Color(0xFF7C4DFF) : const Color(0xFF00E5FF)).withValues(alpha: frac * 0.75);
            break;
          case 'neon':
          default:
            trailColor = const Color(0xFF00E5FF).withValues(alpha: frac * 0.75);
            break;
        }

        canvas.drawCircle(pt, r, Paint()..color = trailColor);
      }
    }
  }

  List<Offset> _triPts(Rect r, BlockKind k) {
    switch (k) {
      case BlockKind.triBR:
        return [r.topRight, r.bottomRight, r.bottomLeft];
      case BlockKind.triBL:
        return [r.topLeft, r.bottomLeft, r.bottomRight];
      case BlockKind.triTR:
        return [r.topLeft, r.topRight, r.bottomRight];
      case BlockKind.triTL:
        return [r.topLeft, r.topRight, r.bottomLeft];
      default:
        return [r.topLeft, r.topRight, r.bottomLeft];
    }
  }

  void _drawOrb(Canvas canvas, Layout l, Orb o) {
    final c = l.cellCenter(o.col, o.row);
    final rad = l.cellW * 0.38;

    // Glowing aura
    canvas.drawCircle(
      c,
      rad + 3 * l.u,
      Paint()
        ..color = GameColors.orbRim.withValues(alpha: 0.35)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 5 * l.u),
    );

    // Orb body gradient
    final shader = const RadialGradient(
      center: Alignment(-0.35, -0.4),
      colors: [GameColors.orbCoreStart, GameColors.orbCoreEnd],
    ).createShader(Rect.fromCircle(center: c, radius: rad));

    canvas.drawCircle(c, rad, Paint()..shader = shader);

    // Golden rim
    canvas.drawCircle(
      c,
      rad,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.8 * l.u
        ..color = GameColors.orbRim,
    );

    // Top-left shiny highlight
    canvas.drawCircle(
      c + Offset(-rad * 0.35, -rad * 0.35),
      rad * 0.22,
      Paint()..color = Colors.white.withValues(alpha: 0.65),
    );

    // Inner icon
    final whitePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.8 * l.u
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final k = rad * 0.44;
    switch (o.kind) {
      case OrbKind.horizontal:
        // Horizontal arrows `<>`
        canvas.drawPath(
          Path()
            ..moveTo(c.dx - 2 * l.u, c.dy - k)
            ..lineTo(c.dx - k - 2 * l.u, c.dy)
            ..lineTo(c.dx - 2 * l.u, c.dy + k)
            ..moveTo(c.dx + 2 * l.u, c.dy - k)
            ..lineTo(c.dx + k + 2 * l.u, c.dy)
            ..lineTo(c.dx + 2 * l.u, c.dy + k),
          whitePaint,
        );
        break;
      case OrbKind.vertical:
        // Vertical arrows `↕`
        canvas.drawPath(
          Path()
            ..moveTo(c.dx - k, c.dy - 2 * l.u)
            ..lineTo(c.dx, c.dy - k - 2 * l.u)
            ..lineTo(c.dx + k, c.dy - 2 * l.u)
            ..moveTo(c.dx - k, c.dy + 2 * l.u)
            ..lineTo(c.dx, c.dy + k + 2 * l.u)
            ..lineTo(c.dx + k, c.dy + 2 * l.u),
          whitePaint,
        );
        break;
      case OrbKind.plusOne:
        final tp = _text('+1', rad * 0.95);
        tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
        break;
      case OrbKind.portalBlue:
      case OrbKind.portalOrange:
        final isBlue = o.kind == OrbKind.portalBlue;
        final portalColor = isBlue ? const Color(0xFF00E5FF) : const Color(0xFFFF9100);
        // Swirling Portal vortex
        canvas.drawCircle(
          c,
          rad * 0.85,
          Paint()
            ..color = portalColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3.5 * l.u,
        );
        canvas.drawCircle(
          c,
          rad * 0.45,
          Paint()..color = portalColor.withValues(alpha: 0.8),
        );
        final tpP = _text('🌀', rad * 0.9);
        tpP.paint(canvas, c - Offset(tpP.width / 2, tpP.height / 2));
        break;
    }
  }

  void _drawFloorLine(Canvas canvas, Layout l) {
    // Soft top glow
    canvas.drawRect(
      Rect.fromLTWH(0, l.floorY - 4 * l.u, l.w, 3 * l.u),
      Paint()..color = Colors.white.withValues(alpha: 0.2),
    );

    // Crisp white floor line
    canvas.drawRect(
      Rect.fromLTWH(0, l.floorY - 1.5 * l.u, l.w, 3.0 * l.u),
      Paint()..color = Colors.white,
    );
  }

  void _drawBalls(Canvas canvas, Layout l) {
    // Launch base ball if idle or returning
    if (engine.phase == Phase.idle ||
        engine.phase == Phase.aiming ||
        engine.phase == Phase.returning ||
        (engine.phase == Phase.shooting && engine.toFire > 0)) {
      _drawSingleBall(canvas, Offset(engine.launcherX, l.floorY - l.r), l.r, l);
    }

    // In-flight balls
    for (final b in engine.balls) {
      if (b.landed) continue;
      _drawSingleBall(canvas, b.pos, l.r, l);
    }
  }

  void _drawSingleBall(Canvas canvas, Offset pos, double r, Layout l) {
    switch (ballSkin) {
      case 'basketball':
        // Orange base
        canvas.drawCircle(pos, r, Paint()..color = const Color(0xFFFF6D00));
        final seam = Paint()
          ..color = const Color(0xFF212121)
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1.0, 1.2 * l.u);
        canvas.drawLine(pos - Offset(0, r), pos + Offset(0, r), seam);
        canvas.drawLine(pos - Offset(r, 0), pos + Offset(r, 0), seam);
        canvas.drawArc(Rect.fromCircle(center: pos - Offset(r * 0.85, 0), radius: r * 0.75), -math.pi * 0.4, math.pi * 0.8, false, seam);
        canvas.drawArc(Rect.fromCircle(center: pos + Offset(r * 0.85, 0), radius: r * 0.75), math.pi * 0.6, math.pi * 0.8, false, seam);
        break;

      case 'tricolor':
        // 3-color swirl: cyan, pink, yellow
        final rect = Rect.fromCircle(center: pos, radius: r);
        canvas.drawArc(rect, -math.pi * 0.5, math.pi * 2 / 3, true, Paint()..color = const Color(0xFF00E5FF));
        canvas.drawArc(rect, -math.pi * 0.5 + math.pi * 2 / 3, math.pi * 2 / 3, true, Paint()..color = const Color(0xFFFF2D8D));
        canvas.drawArc(rect, -math.pi * 0.5 + math.pi * 4 / 3, math.pi * 2 / 3, true, Paint()..color = const Color(0xFFFFD600));
        break;

      case 'star':
        // Blue ball with white stripes
        canvas.drawCircle(pos, r, Paint()..color = const Color(0xFF1E88E5));
        final strPaint = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1.0, 1.6 * l.u);
        canvas.drawArc(Rect.fromCenter(center: pos + Offset(0, -r * 0.45), width: r * 1.6, height: r * 0.7), math.pi * 0.15, math.pi * 0.7, false, strPaint);
        canvas.drawArc(Rect.fromCenter(center: pos, width: r * 1.9, height: r * 0.75), math.pi * 0.1, math.pi * 0.8, false, strPaint);
        canvas.drawArc(Rect.fromCenter(center: pos + Offset(0, r * 0.45), width: r * 1.6, height: r * 0.7), math.pi * 0.15, math.pi * 0.7, false, strPaint);
        break;

      case 'star_burst':
        // Golden orange with purple stars
        canvas.drawCircle(pos, r, Paint()..color = const Color(0xFFFFB300));
        final pPaint = Paint()..color = const Color(0xFF7B1FA2);
        _drawMiniStar(canvas, pos + Offset(-r * 0.35, -r * 0.3), r * 0.32, pPaint);
        _drawMiniStar(canvas, pos + Offset(r * 0.4, -r * 0.2), r * 0.28, pPaint);
        _drawMiniStar(canvas, pos + Offset(0, r * 0.35), r * 0.35, pPaint);
        break;

      case 'white':
        canvas.drawCircle(pos, r, Paint()..color = Colors.white);
        break;

      case 'yellow':
      default:
        // Default golden yellow ball
        final shader = RadialGradient(
          center: const Alignment(-0.35, -0.35),
          colors: const [Color(0xFFFFF176), Color(0xFFFFC107), Color(0xFFFF8F00)],
        ).createShader(Rect.fromCircle(center: pos, radius: r));
        canvas.drawCircle(pos, r, Paint()..shader = shader);
        break;
    }

    // Specular 3D Highlight
    canvas.drawCircle(
      pos + Offset(-r * 0.32, -r * 0.32),
      r * 0.28,
      Paint()..color = Colors.white.withValues(alpha: 0.75),
    );
  }

  void _drawMiniStar(Canvas canvas, Offset ctr, double r, Paint p) {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final rad = i.isEven ? r : r * 0.45;
      final a = -math.pi / 2 + i * math.pi / 5;
      final pt = ctr + Offset(math.cos(a), math.sin(a)) * rad;
      i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
    }
    path.close();
    canvas.drawPath(path, p);
  }

  void _drawAim(Canvas canvas, Layout l) {
    var pos = Offset(engine.launcherX, l.floorY - l.r);
    var dir = engine.aimDir;
    final dotPaint = Paint()..color = Colors.white.withValues(alpha: 0.8);
    var bounces = 0;
    var travelled = 0.0;

    while (bounces < 2 && travelled < l.h * 1.4) {
      final tx = dir.dx > 0
          ? (l.w - l.r - pos.dx) / dir.dx
          : dir.dx < 0
              ? (l.r - pos.dx) / dir.dx
              : double.infinity;
      final ty = dir.dy < 0 ? (l.hudH + l.r - pos.dy) / dir.dy : double.infinity;
      final t = math.min(tx, ty);
      final end = pos + dir * t;

      // Draw dots
      final d = end - pos;
      final dist = d.distance;
      final step = 16 * l.u;
      for (var s = step; s < dist; s += step) {
        final p = pos + d / dist * s;
        canvas.drawCircle(p, 2.8 * l.u, dotPaint);
      }

      travelled += t;
      pos = end;
      if (tx <= ty) {
        dir = Offset(-dir.dx, dir.dy);
      } else {
        dir = Offset(dir.dx, -dir.dy);
      }
      bounces++;
    }
  }

  void _drawBolt(Canvas canvas, Bolt b, Layout l) {
    final rnd = math.Random((b.a.dx + b.a.dy).toInt() ^ (b.b.dx + b.b.dy).toInt());
    final path = Path()..moveTo(b.a.dx, b.a.dy);
    const segs = 16;
    final d = b.b - b.a;
    final dist = d.distance;
    final perp = Offset(-d.dy, d.dx) / (dist > 0 ? dist : 1.0);

    for (var i = 1; i < segs; i++) {
      final jitter = (rnd.nextDouble() - 0.5) * 22 * l.u;
      final pt = b.a + d * (i / segs) + perp * jitter;
      path.lineTo(pt.dx, pt.dy);
    }
    path.lineTo(b.b.dx, b.b.dy);

    final a = (b.life / b.maxLife).clamp(0.0, 1.0);

    // Wide electric glow
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10 * l.u
        ..color = GameColors.lightningGlow.withValues(alpha: 0.45 * a)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 8 * l.u),
    );

    // Inner bright yellow
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.5 * l.u
        ..color = GameColors.lightningGlow.withValues(alpha: 0.85 * a),
    );

    // Core white beam
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2 * l.u
        ..color = Colors.white.withValues(alpha: a),
    );
  }

  void _drawParticles(Canvas canvas, Layout l) {
    for (final p in engine.particles) {
      final a = (p.life / p.maxLife).clamp(0.0, 1.0);
      final paint = Paint()..color = p.color.withValues(alpha: a);

      if (p.isStreak) {
        paint.strokeWidth = 1.8 * l.u;
        final len = p.vel.distance;
        final dir = len > 0 ? p.vel / len : const Offset(1, 0);
        canvas.drawLine(p.pos, p.pos + dir * 16 * l.u * a, paint);
      } else {
        _drawStar(canvas, p.pos, p.size * l.u * (0.4 + 0.6 * a), paint);
      }
    }
  }

  void _drawStar(Canvas canvas, Offset ctr, double r, Paint p) {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final rad = i.isEven ? r : r * 0.45;
      final a = -math.pi / 2 + i * math.pi / 5;
      final pt = ctr + Offset(math.cos(a), math.sin(a)) * rad;
      if (i == 0) {
        path.moveTo(pt.dx, pt.dy);
      } else {
        path.lineTo(pt.dx, pt.dy);
      }
    }
    path.close();
    canvas.drawPath(path, p);
  }

  void _drawCounter(Canvas canvas, Layout l) {
    final label = 'x${engine.counter}';
    final tp = _text(label, 26 * l.u, weight: FontWeight.w700);
    tp.paint(canvas, Offset(engine.launcherX - tp.width / 2, l.floorY + 7 * l.u));
  }

  @override
  bool shouldRepaint(covariant GamePainter oldDelegate) => true;
}
