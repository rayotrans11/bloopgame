import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/theme.dart';
import 'fusion_engine.dart';
import 'fusion_models.dart';

/// Paints the entire Fusion game board with 3D dimensional block style,
/// Ghost Preview (Section 2.4), and Colorblind Mode symbols (Section 2.2).
class FusionPainter extends CustomPainter {
  FusionPainter({
    required this.engine,
    required this.layout,
    required this.colorblindMode,
    this.equippedSkin = 'candy',
    this.equippedTheme = 'neon_night',
    super.repaint,
  });

  final FusionEngine engine;
  final FusionLayout layout;
  final bool colorblindMode;
  final String equippedSkin;
  final String equippedTheme;

  static final Map<String, TextPainter> _tpCache = {};

  TextPainter _tp(String s, double size,
      {Color color = Colors.white, FontWeight weight = FontWeight.w900}) {
    final key = '$s@${size.toStringAsFixed(1)}@${color.toARGB32()}';
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
    _drawBackground(canvas, size);
    _drawGridSlots(canvas);
    _drawLegalMergeTargetHints(canvas);
    _drawGhostPreview(canvas);
    _drawBlocks(canvas);
    _drawPoppingBlocks(canvas);
    _drawDragBlock(canvas);
    _drawParticles(canvas);
    _drawScoreFloats(canvas);
  }

  void _drawBackground(Canvas canvas, Size size) {
    List<Color> themeColors;
    switch (equippedTheme) {
      case 'sunset':
        themeColors = const [Color(0xFF2C103C), Color(0xFF1B0B2E), Color(0xFF0F041A)];
        break;
      case 'ocean':
        themeColors = const [Color(0xFF0A2540), Color(0xFF06182B), Color(0xFF020C17)];
        break;
      case 'candy_land':
        themeColors = const [Color(0xFF2E173C), Color(0xFF1D0E29), Color(0xFF12061C)];
        break;
      case 'neon_night':
      default:
        themeColors = const [Color(0xFF0D1035), Color(0xFF0A0C28), Color(0xFF060820)];
        break;
    }

    final bgGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: themeColors,
    ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, Paint()..shader = bgGradient);

    // Subtle ambient stars
    final starPaint = Paint()..color = Colors.white.withValues(alpha: 0.08);
    final rng = math.Random(77);
    for (int i = 0; i < 45; i++) {
      canvas.drawCircle(
        Offset(rng.nextDouble() * size.width, rng.nextDouble() * size.height),
        rng.nextDouble() * 1.5 + 0.5,
        starPaint,
      );
    }
  }

  void _drawGridSlots(Canvas canvas) {
    final slotPaint = Paint()
      ..color = const Color(0xFF1A1E5A).withValues(alpha: 0.7)
      ..style = PaintingStyle.fill;
    final slotBorderPaint = Paint()
      ..color = const Color(0xFF2A2E7A).withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final rad = Radius.circular(layout.cellW * 0.18);

    for (int col = 0; col < FusionLayout.cols; col++) {
      for (int row = 0; row < FusionLayout.rows; row++) {
        final rect = layout.blockRect(col, row);
        final rRect = RRect.fromRectAndRadius(rect, rad);
        canvas.drawRRect(rRect, slotPaint);
        canvas.drawRRect(rRect, slotBorderPaint);
      }
    }
  }

  /// Section 3.1 UX: Softly highlight legal merge targets when drag starts
  void _drawLegalMergeTargetHints(Canvas canvas) {
    if (engine.phase != FusionPhase.dragging || engine.legalMergeTargets.isEmpty) return;

    final hintBorder = Paint()
      ..color = const Color(0xFF00E5FF).withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;

    for (final target in engine.legalMergeTargets) {
      final rect = layout.blockRect(target.col, target.row);
      final rad = Radius.circular(layout.cellW * 0.20);
      canvas.drawRRect(RRect.fromRectAndRadius(rect.inflate(2), rad), hintBorder);
    }
  }

  /// Section 2.4: Ghost Preview while dragging with simulated merge result and pop highlights
  void _drawGhostPreview(Canvas canvas) {
    final sim = engine.currentSimulation;
    final db = engine.dragBlock;
    if (sim == null || db == null || engine.phase != FusionPhase.dragging) return;

    final targetRect = layout.blockRect(sim.to.col, sim.to.row);
    final rad = Radius.circular(layout.cellW * 0.20);

    if (!sim.isValid) {
      // Dimmed invalid indicator
      canvas.drawRRect(
        RRect.fromRectAndRadius(targetRect, rad),
        Paint()
          ..color = Colors.redAccent.withValues(alpha: 0.2)
          ..style = PaintingStyle.fill,
      );
      return;
    }

    // 1. Glowing border on valid drop target cell
    canvas.drawRRect(
      RRect.fromRectAndRadius(targetRect.inflate(3), rad),
      Paint()
        ..color = const Color(0xFF00E676).withValues(alpha: 0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );

    // 2. Translucent preview ghost block showing simulated merge level
    final ghostBlock = db.clone()
      ..fusionLevel = sim.resultingLevel
      ..burstType = sim.burstType;
    _drawBlockAt(canvas, ghostBlock, targetRect, overrideAlpha: 0.65);

    // 3. Highlight blocks that WOULD POP with subtle pulsing outline
    if (sim.popCells.isNotEmpty) {
      final popOutline = Paint()
        ..color = Colors.amberAccent.withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.8;

      for (final cell in sim.popCells) {
        final cRect = layout.blockRect(cell.col, cell.row);
        canvas.drawRRect(RRect.fromRectAndRadius(cRect.inflate(2.5), rad), popOutline);
      }
    }
  }

  void _drawBlocks(Canvas canvas) {
    for (int col = 0; col < FusionLayout.cols; col++) {
      for (int row = 0; row < FusionLayout.rows; row++) {
        final b = engine.grid[col][row];
        if (b == null) continue;
        if (b.state == FusionBlockState.dragging) continue;
        if (b.state == FusionBlockState.popping) continue;

        _drawBlockAt(canvas, b, layout.blockRect(col, row));
      }
    }
  }

  void _drawPoppingBlocks(Canvas canvas) {
    for (final b in engine.poppingBlocksForPaint) {
      if (b.popProgress >= 1.0 || b.popDelay > 0) continue;
      final rect = layout.blockRect(b.col, b.row);
      final progress = b.popProgress;
      final scale = 1.0 + progress * 0.45;
      final alpha = (1.0 - progress).clamp(0.0, 1.0);

      canvas.save();
      canvas.translate(rect.center.dx, rect.center.dy);
      canvas.scale(scale);
      canvas.translate(-rect.center.dx, -rect.center.dy);
      _drawBlockAt(canvas, b, rect, overrideAlpha: alpha);
      canvas.restore();
    }
  }

  void _drawBlockAt(Canvas canvas, FusionBlock b, Rect rect, {double overrideAlpha = 1.0}) {
    final colorIdx = b.colorIndex % GameColors.blockColors.length;
    final baseColor = GameColors.blockColors[colorIdx];
    final shadeColor = GameColors.blockShades[colorIdx];
    final textColor = GameColors.blockDarkTexts[colorIdx];
    final alpha = overrideAlpha.clamp(0.0, 1.0);

    double drawRectDy = 0.0;
    if (b.state == FusionBlockState.dropping) {
      final t = Curves.bounceOut.transform(b.dropProgress);
      drawRectDy = -(1.0 - t) * layout.cellH * (b.row + 1);
    }

    double fuseScale = 1.0;
    if (b.state == FusionBlockState.fusing) {
      fuseScale = 1.0 + 0.18 * math.sin(b.fuseProgress * math.pi);
    }

    final effectiveRect = rect.shift(Offset(0, drawRectDy));
    final bevelH = layout.cellW * 0.11;
    final rad = Radius.circular(layout.cellW * 0.20);

    canvas.save();
    if (fuseScale != 1.0) {
      canvas.translate(effectiveRect.center.dx, effectiveRect.center.dy);
      canvas.scale(fuseScale);
      canvas.translate(-effectiveRect.center.dx, -effectiveRect.center.dy);
    }

    // 1. Bottom shadow
    canvas.drawRRect(
      RRect.fromRectAndRadius(effectiveRect.shift(Offset(0, bevelH + 2)), rad),
      Paint()
        ..color = shadeColor.withValues(alpha: 0.45 * alpha)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );

    // 2. 3D Bottom Bevel
    canvas.drawRRect(
      RRect.fromRectAndRadius(effectiveRect.shift(Offset(0, bevelH)), rad),
      Paint()..color = shadeColor.withValues(alpha: alpha),
    );

    // 3. Power / Super / Mega Glow
    if (b.fusionLevel >= 2) {
      final glowColor = b.fusionLevel >= 4
          ? const Color(0xFFFFD600)
          : (b.fusionLevel >= 3 ? Colors.white : baseColor);
      canvas.drawRRect(
        RRect.fromRectAndRadius(effectiveRect.inflate(3.5), rad),
        Paint()
          ..color = glowColor.withValues(alpha: 0.35 * alpha)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
    }

    // 4. Main Block Face
    final faceRRect = RRect.fromRectAndRadius(effectiveRect, rad);

    if (b.isIngredient) {
      // Star / Ingredient Special Item
      canvas.drawRRect(
        faceRRect,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFEA00), Color(0xFFFF9100)],
          ).createShader(effectiveRect),
      );
      // Crisp 5-point vector star
      _drawVectorStar(canvas, effectiveRect.center, effectiveRect.height * 0.38, alpha);
      canvas.restore();
      return;
    } else if (b.obstacle == ObstacleType.stone) {
      // Stone Obstacle: 3D slate stone block with carved bevel
      canvas.drawRRect(
        faceRRect,
        Paint()..color = const Color(0xFF546E7A),
      );
      // Stone cracks
      final crackPaint = Paint()
        ..color = const Color(0xFF263238).withValues(alpha: 0.7 * alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      final c = effectiveRect.center;
      final s = effectiveRect.width * 0.28;
      canvas.drawLine(c - Offset(s, s * 0.6), c + Offset(s * 0.4, s * 0.2), crackPaint);
      canvas.drawLine(c + Offset(s * 0.4, s * 0.2), c + Offset(s * 0.9, -s * 0.2), crackPaint);
      canvas.drawLine(c, c + Offset(-s * 0.2, s * 0.8), crackPaint);
      canvas.restore();
      return;
    } else if (b.obstacle == ObstacleType.ice) {
      // Ice Obstacle: Frosty cyan ice crystal
      canvas.drawRRect(
        faceRRect,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFE0F7FA), Color(0xFF80DEEA)],
          ).createShader(effectiveRect),
      );
      // Frosted ice border
      canvas.drawRRect(
        faceRRect,
        Paint()
          ..color = const Color(0xFFB2EBF2).withValues(alpha: 0.9 * alpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );
      // Ice crystal vector snowflake/crack
      _drawIceCrystal(canvas, effectiveRect.center, effectiveRect.height * 0.35, alpha);
      canvas.restore();
      return;
    }

    if (b.fusionLevel >= 4) {
      // Mega Block (Lv4): Radiant Rainbow Gradient & Crown
      canvas.drawRRect(
        faceRRect,
        Paint()
          ..shader = const SweepGradient(
            colors: [
              Color(0xFFFF2D8D),
              Color(0xFFFF9100),
              Color(0xFFFFEA00),
              Color(0xFF00E676),
              Color(0xFF00E5FF),
              Color(0xFFD500F9),
              Color(0xFFFF2D8D),
            ],
          ).createShader(effectiveRect)
          ..color = Colors.white.withValues(alpha: alpha),
      );
    } else if (b.fusionLevel >= 3) {
      // Super Block (Lv3): Dynamic HSL Gradient
      canvas.drawRRect(
        faceRRect,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              baseColor,
              HSLColor.fromColor(baseColor).withHue((HSLColor.fromColor(baseColor).hue + 55) % 360).toColor(),
              baseColor,
            ],
          ).createShader(effectiveRect)
          ..color = baseColor.withValues(alpha: alpha),
      );
    } else {
      canvas.drawRRect(
        faceRRect,
        Paint()..color = baseColor.withValues(alpha: alpha),
      );
    }

    // 5. Specular highlight
    final highlightRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        effectiveRect.left + effectiveRect.width * 0.08,
        effectiveRect.top + effectiveRect.height * 0.05,
        effectiveRect.width * 0.84,
        effectiveRect.height * 0.28,
      ),
      Radius.circular(layout.cellW * 0.14),
    );
    canvas.drawRRect(
      highlightRRect,
      Paint()..color = Colors.white.withValues(alpha: 0.32 * alpha),
    );

    // 6. Colorblind Mode Symbol (Section 2.2: sized ~40% width, high contrast centered)
    if (colorblindMode) {
      _drawColorblindSymbol(canvas, b.symbol, effectiveRect.center, effectiveRect.width * 0.38, alpha);
    }

    // 7. Fusion Level Marker (Section 2.2: corner placement when symbol present)
    if (b.fusionLevel == 2) {
      // Lv2 Power Block (x2)
      final fs = effectiveRect.height * (colorblindMode ? 0.30 : 0.38);
      final tp = _tp('×2', fs, color: textColor, weight: FontWeight.w900);
      final textPos = colorblindMode
          ? Offset(effectiveRect.right - tp.width - 4, effectiveRect.bottom - tp.height - 2)
          : effectiveRect.center - Offset(tp.width / 2, tp.height / 2);
      tp.paint(canvas, textPos);
    } else if (b.fusionLevel == 3) {
      // Lv3 Super Block (⚡)
      final fs = effectiveRect.height * (colorblindMode ? 0.32 : 0.42);
      final tp = _tp('⚡', fs, color: Colors.white, weight: FontWeight.w900);
      final textPos = colorblindMode
          ? Offset(effectiveRect.right - tp.width - 3, effectiveRect.bottom - tp.height - 2)
          : effectiveRect.center - Offset(tp.width / 2, tp.height / 2);
      tp.paint(canvas, textPos);
    } else if (b.fusionLevel >= 4) {
      // Lv4 Mega Block (👑)
      final fs = effectiveRect.height * (colorblindMode ? 0.32 : 0.44);
      final tp = _tp('👑', fs, color: Colors.white, weight: FontWeight.w900);
      final textPos = colorblindMode
          ? Offset(effectiveRect.right - tp.width - 3, effectiveRect.bottom - tp.height - 2)
          : effectiveRect.center - Offset(tp.width / 2, tp.height / 2);
      tp.paint(canvas, textPos);
    }

    canvas.restore();
  }

  /// High-contrast white symbol with dark outline (Section 2.2)
  void _drawColorblindSymbol(Canvas canvas, ColorblindSymbol sym, Offset center, double size, double alpha) {
    final fillPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.95 * alpha)
      ..style = PaintingStyle.fill;
    final strokePaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.75 * alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final r = size / 2;

    switch (sym) {
      case ColorblindSymbol.heart:
        final path = Path();
        path.moveTo(center.dx, center.dy + r * 0.65);
        path.cubicTo(center.dx - r * 1.1, center.dy - r * 0.1, center.dx - r * 0.75, center.dy - r * 0.95, center.dx, center.dy - r * 0.35);
        path.cubicTo(center.dx + r * 0.75, center.dy - r * 0.95, center.dx + r * 1.1, center.dy - r * 0.1, center.dx, center.dy + r * 0.65);
        canvas.drawPath(path, fillPaint);
        canvas.drawPath(path, strokePaint);
        break;

      case ColorblindSymbol.triangle:
        final path = Path()
          ..moveTo(center.dx, center.dy - r * 0.85)
          ..lineTo(center.dx + r * 0.85, center.dy + r * 0.7)
          ..lineTo(center.dx - r * 0.85, center.dy + r * 0.7)
          ..close();
        canvas.drawPath(path, fillPaint);
        canvas.drawPath(path, strokePaint);
        break;

      case ColorblindSymbol.star:
        final path = Path();
        for (int i = 0; i < 10; i++) {
          final rad = i.isEven ? r * 0.9 : r * 0.42;
          final a = -math.pi / 2 + i * math.pi / 5;
          final pt = center + Offset(math.cos(a) * rad, math.sin(a) * rad);
          i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
        }
        path.close();
        canvas.drawPath(path, fillPaint);
        canvas.drawPath(path, strokePaint);
        break;

      case ColorblindSymbol.square:
        final rect = Rect.fromCenter(center: center, width: r * 1.45, height: r * 1.45);
        canvas.drawRect(rect, fillPaint);
        canvas.drawRect(rect, strokePaint);
        break;

      case ColorblindSymbol.diamond:
        final path = Path()
          ..moveTo(center.dx, center.dy - r * 0.9)
          ..lineTo(center.dx + r * 0.8, center.dy)
          ..lineTo(center.dx, center.dy + r * 0.9)
          ..lineTo(center.dx - r * 0.8, center.dy)
          ..close();
        canvas.drawPath(path, fillPaint);
        canvas.drawPath(path, strokePaint);
        break;

      case ColorblindSymbol.circle:
        canvas.drawCircle(center, r * 0.8, fillPaint);
        canvas.drawCircle(center, r * 0.8, strokePaint);
        break;
    }
  }

  void _drawVectorStar(Canvas canvas, Offset center, double radius, double alpha) {
    final path = Path();
    for (int i = 0; i < 10; i++) {
      final rad = i.isEven ? radius : radius * 0.48;
      final a = -math.pi / 2 + i * math.pi / 5;
      final pt = center + Offset(math.cos(a) * rad, math.sin(a) * rad);
      i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
    }
    path.close();

    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.95 * alpha)
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFFFF6F00).withValues(alpha: 0.85 * alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );
  }

  void _drawIceCrystal(Canvas canvas, Offset center, double radius, double alpha) {
    final paint = Paint()
      ..color = const Color(0xFF006064).withValues(alpha: 0.75 * alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < 6; i++) {
      final angle = i * math.pi / 3;
      final arm = Offset(math.cos(angle), math.sin(angle));
      final tip = center + arm * radius;
      canvas.drawLine(center, tip, paint);

      // Branchlets
      final branchPoint = center + arm * (radius * 0.6);
      final bAngle1 = angle + math.pi / 4;
      final bAngle2 = angle - math.pi / 4;
      final bLen = radius * 0.32;
      canvas.drawLine(branchPoint, branchPoint + Offset(math.cos(bAngle1), math.sin(bAngle1)) * bLen, paint);
      canvas.drawLine(branchPoint, branchPoint + Offset(math.cos(bAngle2), math.sin(bAngle2)) * bLen, paint);
    }
  }

  void _drawDragBlock(Canvas canvas) {
    final db = engine.dragBlock;
    final dp = engine.dragPos;
    if (db == null || dp == null) return;

    final floatRect = Rect.fromCenter(
      center: dp,
      width: layout.cellW - layout.blockInset * 2,
      height: layout.cellH - layout.blockInset * 2,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(floatRect.shift(const Offset(0, 8)), Radius.circular(layout.cellW * 0.20)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );

    canvas.save();
    canvas.translate(dp.dx, dp.dy);
    canvas.scale(1.12);
    canvas.translate(-dp.dx, -dp.dy);
    _drawBlockAt(canvas, db, floatRect);
    canvas.restore();
  }

  void _drawParticles(Canvas canvas) {
    for (final p in engine.particles) {
      final alpha = (p.life / p.maxLife).clamp(0.0, 1.0);
      final paint = Paint()..color = p.color.withValues(alpha: alpha * 0.9);

      if (p.isGem) {
        final r = p.size * 0.55;
        final path = Path()
          ..moveTo(p.pos.dx, p.pos.dy - r * 1.3)
          ..lineTo(p.pos.dx + r, p.pos.dy)
          ..lineTo(p.pos.dx, p.pos.dy + r)
          ..lineTo(p.pos.dx - r, p.pos.dy)
          ..close();
        canvas.drawPath(path, paint);
      } else {
        canvas.drawCircle(p.pos, p.size * alpha, paint);
      }
    }
  }

  void _drawScoreFloats(Canvas canvas) {
    for (final f in engine.scoreFloats) {
      final alpha = (f.life / f.maxLife).clamp(0.0, 1.0);
      final fs = 18.0 + (1.0 - alpha) * 6;
      final tp = _tp(f.text, fs, color: f.color.withValues(alpha: alpha));
      tp.paint(canvas, f.pos - Offset(tp.width / 2, tp.height / 2));

      final tpShadow = _tp(f.text, fs, color: Colors.black.withValues(alpha: alpha * 0.4));
      tpShadow.paint(canvas, f.pos - Offset(tpShadow.width / 2 - 1, tpShadow.height / 2 - 1));
    }
  }

  @override
  bool shouldRepaint(FusionPainter oldDelegate) => true;
}
