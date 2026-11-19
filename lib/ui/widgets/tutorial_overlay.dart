import 'package:flutter/material.dart';

class TutorialStep {
  final int stepId;
  final ({int col, int row}) from;
  final ({int col, int row}) to;
  final String instruction;
  final String title;

  const TutorialStep({
    required this.stepId,
    required this.from,
    required this.to,
    required this.instruction,
    required this.title,
  });
}

class TutorialOverlay extends StatefulWidget {
  final TutorialStep step;
  final Rect fromRect;
  final Rect toRect;
  final VoidCallback onDismiss;

  const TutorialOverlay({
    super.key,
    required this.step,
    required this.fromRect,
    required this.toRect,
    required this.onDismiss,
  });

  @override
  State<TutorialOverlay> createState() => _TutorialOverlayState();
}

class _TutorialOverlayState extends State<TutorialOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController _handCtrl;

  @override
  void initState() {
    super.initState();
    _handCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
  }

  @override
  void dispose() {
    _handCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: true, // lets player touch through to make the drag move
      child: AnimatedBuilder(
        animation: _handCtrl,
        builder: (context, _) {
          final t = Curves.easeInOut.transform(_handCtrl.value);
          final handPos = Offset.lerp(widget.fromRect.center, widget.toRect.center, t)!;

          return Stack(
            children: [
              // Message card at bottom/top
              Positioned(
                top: widget.fromRect.top > 250 ? widget.fromRect.top - 85 : widget.toRect.bottom + 15,
                left: 24,
                right: 24,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF16194C).withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF00E676), width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.5),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.step.title,
                          style: const TextStyle(
                            fontFamily: 'Fredoka',
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF00E676),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          widget.step.instruction,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontFamily: 'Fredoka',
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Animated Drag Hand Pointer
              Positioned(
                left: handPos.dx - 22,
                top: handPos.dy - 10,
                child: Transform.rotate(
                  angle: -0.2,
                  child: Container(
                    decoration: const BoxDecoration(
                      boxShadow: [
                        BoxShadow(color: Colors.black45, blurRadius: 6, offset: Offset(2, 3)),
                      ],
                    ),
                    child: const Icon(
                      Icons.touch_app_rounded,
                      color: Color(0xFFFFD600),
                      size: 44,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
