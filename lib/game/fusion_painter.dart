import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/theme.dart';
import 'fusion_engine.dart';
import 'fusion_models.dart';

/// Paints the entire Fusion game board with 3D dimensional block style
class FusionPainter extends CustomPainter {
  FusionPainter({
    required this.engine,
    required this.layout,
    super.repaint,
  });

  final FusionEngine engine;
  final FusionLayout layout;

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
    _drawBlocks(canvas);
    _drawPoppingBlocks(canvas);
    _drawDragBlock(canvas);
    _drawDropTarget(canvas);
    _drawParticles(canvas);
    _drawScoreFloats(canvas);
  }

  void _drawBackground(Canvas canvas, Size size) {
    final bgGradient = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Color(0xFF0D1035),
        Color(0xFF0A0C28),
        Color(0xFF060820),
      ],
    ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, Paint()..shader = bgGradient);

    // Soft starfield dots
    final starPaint = Paint()..color = Colors.white.withValues(alpha: 0.08);
    final rng = math.Random(42);
    for (int i = 0; i < 60; i++) {
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

  void _drawBlocks(Canvas canvas) {
    for (int col = 0; col < FusionLayout.cols; col++) {
      for (int row = 0; row < FusionLayout.rows; row++) {
        final b = engine.grid[col][row];
        if (b == null) continue;
        if (b.state == FusionBlockState.dragging) continue; // drawn separately
        if (b.state == FusionBlockState.popping) continue;  // drawn separately

        _drawBlockAt(canvas, b, layout.blockRect(col, row));
      }
    }
  }

  void _drawPoppingBlocks(Canvas canvas) {
    for (final b in engine.poppingBlocksForPaint) {
      if (b.popProgress >= 1.0) continue;
      if (b.popDelay > 0) continue;
      final rect = layout.blockRect(b.col, b.row);
      final progress = b.popProgress;
      final scale = 1.0 + progress * 0.4; // expand
      final alpha = (1.0 - progress).clamp(0.0, 1.0);

      canvas.save();
      canvas.translate(rect.center.dx, rect.center.dy);
      canvas.scale(scale);
      canvas.translate(-rect.center.dx, -rect.center.dy);
      _drawBlockAt(canvas, b, rect, overrideAlpha: alpha);
      canvas.restore();
    }
  }

  void _drawBlockAt(Canvas canvas, FusionBlock b, Rect rect,
      {double overrideAlpha = 1.0}) {
    final colorIdx = b.colorIndex % GameColors.blockColors.length;
    final baseColor = GameColors.blockColors[colorIdx];
    final shadeColor = GameColors.blockShades[colorIdx];
    final textColor = GameColors.blockDarkTexts[colorIdx];

    final alpha = overrideAlpha.clamp(0.0, 1.0);

    // Drop animation: slide in from above
    double drawRectDy = 0.0;
    if (b.state == FusionBlockState.dropping) {
      final t = Curves.bounceOut.transform(b.dropProgress);
      drawRectDy = -(1.0 - t) * layout.cellH * (b.row + 1);
    }

    // Fuse animation: scale pulse
    double fuseScale = 1.0;
    if (b.state == FusionBlockState.fusing) {
      fuseScale = 1.0 + 0.15 * math.sin(b.fuseProgress * math.pi);
    }

    // Pulse flash
    final pulseAlpha = b.pulseProgress * 0.5;

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

    // 2. 3D Bottom bevel — deeper and richer
    canvas.drawRRect(
      RRect.fromRectAndRadius(effectiveRect.shift(Offset(0, bevelH)), rad),
      Paint()..color = shadeColor.withValues(alpha: alpha),
    );

    // 3. Main face
    // Power block gets a gradient glow
    if (b.fusionLevel >= 2) {
      final glowColor = b.fusionLevel >= 3
          ? const Color(0xFFFFFFFF)
          : baseColor.withValues(alpha: 0.6);
      canvas.drawRRect(
        RRect.fromRectAndRadius(effectiveRect.inflate(3.0), rad),
        Paint()
          ..color = glowColor.withValues(alpha: 0.3 * alpha)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
    }

    final faceRRect = RRect.fromRectAndRadius(effectiveRect, rad);

    if (b.fusionLevel >= 3) {
      // Super block: rainbow-ish gradient
      canvas.drawRRect(
        faceRRect,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              baseColor,
              HSLColor.fromColor(baseColor).withHue(
                (HSLColor.fromColor(baseColor).hue + 60) % 360,
              ).toColor(),
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

    // 4. Top specular highlight
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

    // 5. Left-side inner bevel highlight
    canvas.drawRRect(
      faceRRect,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.18 * alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );

    // 6. Pulse flash overlay
    if (pulseAlpha > 0) {
      canvas.drawRRect(
        faceRRect,
        Paint()..color = Colors.white.withValues(alpha: pulseAlpha * alpha),
      );
    }

    // 7. Fusion level label / icon
    if (b.fusionLevel == 1) {
      // Normal block: no label (clean look)
    } else if (b.fusionLevel == 2) {
      // Power block: ×2 label
      final fs = effectiveRect.height * 0.38;
      final tp = _tp('×2', fs, color: textColor, weight: FontWeight.w900);
      tp.paint(
        canvas,
        effectiveRect.center - Offset(tp.width / 2, tp.height / 2),
      );
    } else {
      // Super block: ⚡ icon
      final fs = effectiveRect.height * 0.42;
      final tp = _tp('⚡', fs, color: Colors.white, weight: FontWeight.w900);
      tp.paint(
        canvas,
        effectiveRect.center - Offset(tp.width / 2, tp.height / 2),
      );
    }

    canvas.restore();
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

    // Shadow beneath dragged block
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          floatRect.shift(const Offset(0, 8)), Radius.circular(layout.cellW * 0.20)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );

    // Scale up slightly while dragging
    canvas.save();
    canvas.translate(dp.dx, dp.dy);
    canvas.scale(1.1);
    canvas.translate(-dp.dx, -dp.dy);
    _drawBlockAt(canvas, db, floatRect);
    canvas.restore();
  }

  void _drawDropTarget(Canvas canvas) {
    final target = engine.dragTarget;
    if (target == null) return;

    final rect = layout.blockRect(target.col, target.row);
    final rad = Radius.circular(layout.cellW * 0.20);

    // Animated glowing highlight on the target
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.inflate(3), rad),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, rad),
      Paint()..color = Colors.white.withValues(alpha: 0.15),
    );
  }

  void _drawParticles(Canvas canvas) {
    for (final p in engine.particles) {
      final alpha = (p.life / p.maxLife).clamp(0.0, 1.0);
      final paint = Paint()..color = p.color.withValues(alpha: alpha * 0.9);

      if (p.isGem) {
        // Gem-shaped diamond particle
        final r = p.size * 0.5;
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

      // White shadow
      final tpShadow = _tp(f.text, fs, color: Colors.black.withValues(alpha: alpha * 0.4));
      tpShadow.paint(
          canvas, f.pos - Offset(tpShadow.width / 2 - 1, tpShadow.height / 2 - 1));
    }
  }

  @override
  bool shouldRepaint(FusionPainter oldDelegate) => true;
}
