import 'package:flutter/material.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/player_state.dart';
import 'game_icons.dart';

class OutlinedButtonText extends StatelessWidget {
  final String text;
  final double fontSize;
  final double strokeWidth;
  final Color textColor;
  final Color strokeColor;

  const OutlinedButtonText(
    this.text, {
    super.key,
    this.fontSize = 16,
    this.strokeWidth = 3.5,
    this.textColor = Colors.white,
    this.strokeColor = Colors.black,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Black stroke outline
        Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Fredoka',
            fontSize: fontSize,
            fontWeight: FontWeight.w900,
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = strokeWidth
              ..strokeJoin = StrokeJoin.round
              ..strokeCap = StrokeCap.round
              ..color = strokeColor,
          ),
        ),
        // White fill
        Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Fredoka',
            fontSize: fontSize,
            fontWeight: FontWeight.w900,
            color: textColor,
          ),
        ),
      ],
    );
  }
}

class HudRow extends StatelessWidget {
  final PlayerState player;
  final VoidCallback onAddGems;
  final VoidCallback onAddHearts;

  const HudRow({
    super.key,
    required this.player,
    required this.onAddGems,
    required this.onAddHearts,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // 1. Cash Pill - No plus icon
        Expanded(
          flex: 9,
          child: HudPill(
            iconType: 'cash',
            text: GameFormat.currency(player.cash),
            showPlus: false,
          ),
        ),
        const SizedBox(width: 6),

        // 2. Gems Pill - With plus icon (Daily Check-in)
        Expanded(
          flex: 10,
          child: HudPill(
            iconType: 'gem',
            text: GameFormat.currency(player.gems),
            showPlus: true,
            onPlus: onAddGems,
          ),
        ),
        const SizedBox(width: 6),

        // 3. Heart Display - Big heart with number inside!
        Expanded(
          flex: 13,
          child: BigHeartPill(
            hearts: player.hearts,
            maxHearts: PlayerState.maxHearts,
            timeUntilNext: player.timeUntilNextHeart,
            onTap: onAddHearts,
          ),
        ),
      ],
    );
  }
}

class HudPill extends StatelessWidget {
  final String iconType;
  final String text;
  final bool showPlus;
  final VoidCallback? onPlus;

  const HudPill({
    super.key,
    required this.iconType,
    required this.text,
    this.showPlus = true,
    this.onPlus,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
      decoration: BoxDecoration(
        color: GameColors.pillFill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: GameColors.pillBorder, width: 2.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            offset: const Offset(0, 3),
            blurRadius: 4,
          ),
        ],
      ),
      child: Row(
        children: [
          // Icon
          SizedBox(
            width: 28,
            height: 28,
            child: CustomPaint(
              painter: GameIconPainter(type: iconType),
            ),
          ),
          const SizedBox(width: 3),

          // Value
          Expanded(
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  text,
                  style: const TextStyle(
                    fontFamily: 'Fredoka',
                    fontWeight: FontWeight.w700,
                    fontSize: 14.5,
                    color: Colors.white,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ),
          ),

          // Plus button (if enabled)
          if (showPlus) ...[
            const SizedBox(width: 2),
            GestureDetector(
              onTap: onPlus,
              child: Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: GameColors.plusBlue,
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(color: GameColors.plusBlueBorder, width: 1.2),
                  boxShadow: const [
                    BoxShadow(
                      color: GameColors.plusBlueDark,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(Icons.add, color: Colors.white, size: 18),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Big glossy 3D heart with the number of hearts INSIDE the heart icon!
class BigHeartPill extends StatelessWidget {
  final int hearts;
  final int maxHearts;
  final Duration timeUntilNext;
  final VoidCallback onTap;

  const BigHeartPill({
    super.key,
    required this.hearts,
    required this.maxHearts,
    required this.timeUntilNext,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final statusText = hearts >= maxHearts ? 'MAX' : GameFormat.timer(timeUntilNext);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          color: GameColors.pillFill,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: GameColors.pillBorder, width: 2.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              offset: const Offset(0, 3),
              blurRadius: 4,
            ),
          ],
        ),
        child: Row(
          children: [
            // BIG Heart with number inside
            SizedBox(
              width: 38,
              height: 38,
              child: CustomPaint(
                painter: _BigHeartPainter(hearts: hearts),
              ),
            ),
            const SizedBox(width: 4),

            // Timer or MAX text
            Expanded(
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    statusText,
                    style: TextStyle(
                      fontFamily: 'Fredoka',
                      fontWeight: FontWeight.w800,
                      fontSize: 13.5,
                      color: hearts >= maxHearts ? const Color(0xFFFFD54F) : Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 2),

            // Plus button
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: GameColors.plusBlue,
                borderRadius: BorderRadius.circular(7),
                border: Border.all(color: GameColors.plusBlueBorder, width: 1.2),
                boxShadow: const [
                  BoxShadow(
                    color: GameColors.plusBlueDark,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: const Center(
                child: Icon(Icons.add, color: Colors.white, size: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BigHeartPainter extends CustomPainter {
  final int hearts;

  _BigHeartPainter({required this.hearts});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Heart Path
    final path = Path();
    path.moveTo(w * 0.5, h * 0.28);
    path.cubicTo(w * 0.5, h * 0.12, w * 0.08, h * 0.08, w * 0.08, h * 0.42);
    path.cubicTo(w * 0.08, h * 0.65, w * 0.38, h * 0.84, w * 0.5, h * 0.96);
    path.cubicTo(w * 0.62, h * 0.84, w * 0.92, h * 0.65, w * 0.92, h * 0.42);
    path.cubicTo(w * 0.92, h * 0.08, w * 0.5, h * 0.12, w * 0.5, h * 0.28);
    path.close();

    // Dark 3D Drop Shadow behind heart
    canvas.drawPath(
      path.shift(const Offset(0, 2.5)),
      Paint()..color = const Color(0xFF5A0000),
    );

    // Glowing outline
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFFFF8A80)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );

    // Radial Gradient Core
    final shader = RadialGradient(
      center: const Alignment(-0.25, -0.3),
      colors: const [Color(0xFFFF5252), Color(0xFFE53935), Color(0xFFB71C1C)],
    ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawPath(path, Paint()..shader = shader);

    // Top-Left Glossy Specular Highlight Arc
    final hlPath = Path();
    hlPath.moveTo(w * 0.22, h * 0.26);
    hlPath.quadraticBezierTo(w * 0.28, h * 0.16, w * 0.44, h * 0.22);
    canvas.drawPath(
      hlPath,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.8
        ..strokeCap = StrokeCap.round,
    );

    // Centered Heart Number inside the heart!
    final text = '$hearts';
    final fontSize = text.length > 1 ? 17.0 : 19.0;

    // Black text stroke for supreme contrast
    final shadowTp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: 'Fredoka',
          fontSize: fontSize,
          fontWeight: FontWeight.w900,
          foreground: Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3.5
            ..strokeJoin = StrokeJoin.round
            ..strokeCap = StrokeCap.round
            ..color = const Color(0xFF6B0000),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    // Crisp white text fill
    final fillTp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: 'Fredoka',
          fontSize: fontSize,
          fontWeight: FontWeight.w900,
          color: Colors.white,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final centerOffset = Offset(w * 0.5 - fillTp.width / 2, h * 0.46 - fillTp.height / 2);
    shadowTp.paint(canvas, centerOffset + const Offset(0, 1));
    fillTp.paint(canvas, centerOffset);
  }

  @override
  bool shouldRepaint(covariant _BigHeartPainter old) => old.hearts != hearts;
}

class ChestProgressBar extends StatelessWidget {
  final int progress; // 0..50
  final VoidCallback onTap;

  const ChestProgressBar({super.key, required this.progress, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final pct = (progress / 50.0).clamp(0.0, 1.0);

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        height: 42,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Track bar
            Container(
              width: 95,
              height: 20,
              decoration: BoxDecoration(
                color: GameColors.chestTrack,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF5D3110), width: 1.8),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.3), offset: const Offset(0, 2)),
                ],
              ),
              child: Stack(
                children: [
                  // Progress fill
                  FractionallySizedBox(
                    widthFactor: pct,
                    child: Container(
                      decoration: BoxDecoration(
                        color: GameColors.chestFill,
                        borderRadius: BorderRadius.circular(8),
                        gradient: const LinearGradient(
                          colors: [Color(0xFF80D8FF), Color(0xFF00B0FF)],
                        ),
                      ),
                    ),
                  ),
                  // Progress text
                  Center(
                    child: Text(
                      '$progress/50',
                      style: const TextStyle(
                        fontFamily: 'Fredoka',
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        shadows: [
                          Shadow(color: Colors.black54, offset: Offset(0, 1), blurRadius: 2),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 3),

            // Mystery Gift Box Cube
            SizedBox(
              width: 38,
              height: 38,
              child: CustomPaint(
                painter: GameIconPainter(type: 'mystery_box'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class GameButton3D extends StatefulWidget {
  final String text;
  final VoidCallback onTap;
  final Color surfaceColor;
  final Color shadowColor;
  final double width;
  final double height;
  final double fontSize;
  final bool pulsing;

  const GameButton3D({
    super.key,
    required this.text,
    required this.onTap,
    this.surfaceColor = GameColors.startBlue,
    this.shadowColor = GameColors.startBlueDark,
    this.width = 240,
    this.height = 64,
    this.fontSize = 28,
    this.pulsing = false,
  });

  @override
  State<GameButton3D> createState() => _GameButton3DState();
}

class _GameButton3DState extends State<GameButton3D> with SingleTickerProviderStateMixin {
  bool _pressed = false;
  late final AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget btn = GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 60),
        width: widget.width,
        height: widget.height,
        margin: EdgeInsets.only(top: _pressed ? 4 : 0),
        decoration: BoxDecoration(
          color: widget.surfaceColor,
          borderRadius: BorderRadius.circular(widget.height / 2),
          border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: widget.shadowColor,
              offset: Offset(0, _pressed ? 2 : 6),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              offset: Offset(0, _pressed ? 4 : 8),
              blurRadius: 6,
            ),
          ],
        ),
        child: Center(
          child: OutlinedButtonText(
            widget.text,
            fontSize: widget.fontSize,
            strokeWidth: 4.0,
          ),
        ),
      ),
    );

    if (widget.pulsing) {
      return AnimatedBuilder(
        animation: _pulseCtrl,
        builder: (context, child) {
          final scale = 1.0 + _pulseCtrl.value * 0.04;
          return Transform.scale(scale: scale, child: child);
        },
        child: btn,
      );
    }

    return btn;
  }
}
