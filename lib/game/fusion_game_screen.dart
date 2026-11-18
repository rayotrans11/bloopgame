import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../core/ads_service.dart';
import '../core/game_audio.dart';
import '../core/theme.dart';
import '../data/player_state.dart';
import '../ui/widgets/hud_pills.dart';
import '../ui/widgets/popups.dart';
import 'fusion_engine.dart';
import 'fusion_models.dart';
import 'fusion_painter.dart';

class FusionGameScreen extends StatefulWidget {
  final int levelId;
  final PlayerState player;

  const FusionGameScreen({
    super.key,
    required this.levelId,
    required this.player,
  });

  @override
  State<FusionGameScreen> createState() => _FusionGameScreenState();
}

class _FusionGameScreenState extends State<FusionGameScreen> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _lastTick = Duration.zero;

  FusionEngine? _engine;
  FusionLayout? _layout;
  bool _dialogShown = false;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      if (_lastTick == Duration.zero) {
        _lastTick = elapsed;
        return;
      }
      final dt = (elapsed - _lastTick).inMicroseconds / 1e6;
      _lastTick = elapsed;

      if (_engine != null) {
        _engine!.update(dt);

        if (!_dialogShown) {
          if (_engine!.phase == FusionPhase.won) {
            _dialogShown = true;
            _onWin();
          } else if (_engine!.phase == FusionPhase.lost) {
            _dialogShown = true;
            _onLose();
          }
        }
      }
    })..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _initEngine(Size size, double safeTop, double safeBottom) {
    if (_layout != null && _layout!.w == size.width && _layout!.h == size.height) return;

    _layout = FusionLayout(size, safeTop: safeTop, safeBottom: safeBottom);
    final targetPops = 25 + widget.levelId * 5;
    final maxMoves = 20 + (widget.levelId ~/ 2) * 2;

    _engine = FusionEngine(
      layout: _layout!,
      targetPops: targetPops,
      levelId: widget.levelId,
      maxMoves: maxMoves,
    );
  }

  void _onWin() {
    GameAudio.instance.play(GameSound.win);
    GameAudio.instance.haptic(GameHaptic.success);
    widget.player.completeLevel(widget.levelId, 0.05);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => GameDialogWrapper(
        title: 'LEVEL COMPLETE!',
        content: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF00E676).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF00E676), width: 2),
              ),
              child: Column(
                children: [
                  const Text(
                    'POPPED BLOCKS',
                    style: TextStyle(
                      fontFamily: 'Fredoka',
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${_engine?.poppedCount ?? 0}',
                    style: const TextStyle(
                      fontFamily: 'Fredoka',
                      color: Color(0xFF00E676),
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'SCORE: ${_engine?.score ?? 0}',
                    style: const TextStyle(
                      fontFamily: 'Fredoka',
                      color: Colors.amberAccent,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              '+15 Gems Earned!',
              style: TextStyle(fontFamily: 'Fredoka', color: Colors.white, fontSize: 16),
            ),
          ],
        ),
        actions: [
          GameButton3D(
            text: 'NEXT LEVEL',
            width: 170,
            height: 52,
            fontSize: 18,
            surfaceColor: const Color(0xFF00E676),
            shadowColor: const Color(0xFF00A344),
            onTap: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) => FusionGameScreen(
                    levelId: widget.levelId + 1,
                    player: widget.player,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _onLose() {
    GameAudio.instance.play(GameSound.lose);
    GameAudio.instance.haptic(GameHaptic.error);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => GameDialogWrapper(
        title: 'OUT OF MOVES!',
        content: Column(
          children: [
            const Icon(Icons.sentiment_dissatisfied_rounded, color: Color(0xFFFF5252), size: 54),
            const SizedBox(height: 12),
            Text(
              'You popped ${_engine?.poppedCount ?? 0} / ${_engine?.targetPops ?? 0} blocks.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontFamily: 'Fredoka', color: Colors.white, fontSize: 16),
            ),
          ],
        ),
        actions: [
          GameButton3D(
            text: 'RETRY',
            width: 140,
            height: 48,
            fontSize: 16,
            surfaceColor: const Color(0xFFFF5252),
            shadowColor: const Color(0xFFD50000),
            onTap: () {
              Navigator.of(ctx).pop();
              if (widget.player.consumeHeartForGame()) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => FusionGameScreen(
                      levelId: widget.levelId,
                      player: widget.player,
                    ),
                  ),
                );
              } else {
                Popups.showOutOfHearts(context, widget.player);
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final size = media.size;
    final safeTop = media.padding.top;
    final safeBottom = media.padding.bottom;

    _initEngine(size, safeTop, safeBottom);

    return Scaffold(
      backgroundColor: GameColors.bgDarkPlayfield,
      body: Stack(
        children: [
          // 1. Gesture Interactive Canvas
          if (_engine != null && _layout != null)
            ListenableBuilder(
              listenable: _engine!,
              builder: (context, _) {
                return GestureDetector(
                  onPanStart: (d) => _engine!.onDragStart(d.localPosition),
                  onPanUpdate: (d) => _engine!.onDragUpdate(d.localPosition),
                  onPanEnd: (d) => _engine!.onDragEnd(d.localPosition),
                  child: CustomPaint(
                    size: size,
                    painter: FusionPainter(
                      engine: _engine!,
                      layout: _layout!,
                    ),
                  ),
                );
              },
            ),

          // 2. Top Game HUD Header
          Positioned(
            top: safeTop + 8,
            left: 16,
            right: 16,
            child: _buildHeader(),
          ),

          // 3. Bottom Goal & Moves Card
          Positioned(
            bottom: safeBottom + 12,
            left: 20,
            right: 20,
            child: _buildBottomBar(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Home Button
        GestureDetector(
          onTap: () {
            UnityAdsService.instance.recordMenuClick();
            Navigator.of(context).pop();
          },
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFF5C4CB2),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF8A7AE6), width: 2),
            ),
            child: const Icon(Icons.home_rounded, color: Colors.white, size: 24),
          ),
        ),

        // Level Pill
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: GameColors.levelPill,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 1.5),
            boxShadow: const [
              BoxShadow(
                color: GameColors.levelPillDark,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Text(
            'LEVEL ${widget.levelId}',
            style: const TextStyle(
              fontFamily: 'Fredoka',
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: 0.6,
            ),
          ),
        ),

        // Settings Button
        GestureDetector(
          onTap: () {
            UnityAdsService.instance.recordMenuClick();
            Popups.showSettings(context, widget.player);
          },
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFF5C4CB2),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF8A7AE6), width: 2),
            ),
            child: const Icon(Icons.settings, color: Colors.white, size: 22),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar() {
    if (_engine == null) return const SizedBox.shrink();

    return ListenableBuilder(
      listenable: _engine!,
      builder: (context, _) {
        final progress = (_engine!.poppedCount / _engine!.targetPops).clamp(0.0, 1.0);

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF16194C).withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF4D3BC6), width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // Moves Left Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF261D52),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFFD600), width: 1.5),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'MOVES',
                      style: TextStyle(
                        fontFamily: 'Fredoka',
                        fontSize: 11,
                        color: Colors.white70,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${_engine!.movesLeft}',
                      style: const TextStyle(
                        fontFamily: 'Fredoka',
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFFFFD600),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),

              // Progress Bar
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'GOAL: POP BLOCKS',
                          style: TextStyle(
                            fontFamily: 'Fredoka',
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          '${_engine!.poppedCount} / ${_engine!.targetPops}',
                          style: const TextStyle(
                            fontFamily: 'Fredoka',
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF00E676),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 10,
                        backgroundColor: Colors.white12,
                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF00E676)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
