import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../core/ads_service.dart';
import '../core/game_audio.dart';
import '../core/progression_service.dart';
import '../core/theme.dart';
import '../data/fusion_levels.dart';
import '../data/player_state.dart';
import '../ui/widgets/hud_pills.dart';
import '../ui/widgets/popups.dart';
import '../ui/widgets/tutorial_overlay.dart';
import 'fusion_engine.dart';
import 'fusion_models.dart';
import 'fusion_painter.dart';

class FusionGameScreen extends StatefulWidget {
  final int levelId;
  final PlayerState player;
  final bool isDailyChallenge;
  final int? fixedSeed;

  const FusionGameScreen({
    super.key,
    required this.levelId,
    required this.player,
    this.isDailyChallenge = false,
    this.fixedSeed,
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
  TutorialStep? _currentTutorialStep;

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
    final levelConfig = FusionLevelConfig.get(
      widget.levelId,
      isDailyChallenge: widget.isDailyChallenge,
    );

    // Fast introduction tutorial only on Level 1
    final isTut = widget.levelId == 1 && !widget.isDailyChallenge;

    _engine = FusionEngine(
      layout: _layout!,
      levelId: widget.levelId,
      maxMoves: levelConfig.maxMoves,
      goal: levelConfig.goal,
      mergeRules: levelConfig.rules,
      fixedSeed: widget.fixedSeed,
      isTutorial: isTut,
      initialObstacles: levelConfig.obstacles,
      initialIngredients: levelConfig.ingredients,
    );

    if (isTut) {
      _setupTutorialStep();
    }
  }

  void _setupTutorialStep() {
    if (widget.levelId == 1) {
      _currentTutorialStep = const TutorialStep(
        stepId: 1,
        from: (col: 2, row: 2),
        to: (col: 3, row: 2),
        title: 'BREAK THE ICE! 🧊',
        instruction: 'Merge blocks next to the ice to break them and clear the level!',
      );
    }
  }

  void _onWin() {
    GameAudio.instance.play(GameSound.win);
    GameAudio.instance.haptic(GameHaptic.success);

    final movesLeft = _engine?.movesLeft ?? 0;
    final maxMoves = _engine?.maxMoves ?? 20;
    final score = _engine?.score ?? 0;

    // Record Progression, compute stars and bonus gems (Section 1.1 & 1.2)
    final bonusGems = ProgressionService.instance.recordLevelCompletion(
      levelId: widget.levelId,
      movesLeft: movesLeft,
      maxMoves: maxMoves,
      score: score,
    );
    widget.player.addGems(bonusGems);
    widget.player.completeLevel(widget.levelId, 0.05);

    // Record completed level count for interstitial ad every 2 levels
    final shouldShowAd = UnityAdsService.instance.recordLevelComplete();

    final stars = ProgressionService.instance.getLevelProgress(widget.levelId).stars;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => GameDialogWrapper(
        title: 'LEVEL COMPLETE!',
        content: Column(
          children: [
            // Stars animated display (Section 1.2)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (i) {
                final earned = i < stars;
                return TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: earned ? 1.0 : 0.0),
                  duration: Duration(milliseconds: 400 + i * 200),
                  curve: Curves.elasticOut,
                  builder: (context, scale, child) {
                    return Transform.scale(
                      scale: scale.clamp(0.0, 1.2),
                      child: Icon(
                        Icons.star_rounded,
                        size: 42,
                        color: earned ? const Color(0xFFFFD600) : Colors.white24,
                      ),
                    );
                  },
                );
              }),
            ),
            const SizedBox(height: 14),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF00E676).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF00E676), width: 2),
              ),
              child: Column(
                children: [
                  Text(
                    'SCORE: $score',
                    style: const TextStyle(
                      fontFamily: 'Fredoka',
                      color: Color(0xFF00E676),
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Moves Left: $movesLeft / $maxMoves',
                    style: const TextStyle(
                      fontFamily: 'Fredoka',
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '+$bonusGems Gems Earned!',
              style: const TextStyle(fontFamily: 'Fredoka', color: Color(0xFFFFD600), fontSize: 16, fontWeight: FontWeight.bold),
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

              void goToNextLevel() {
                if (!mounted) return;
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => FusionGameScreen(
                      levelId: widget.levelId + 1,
                      player: widget.player,
                    ),
                  ),
                );
              }

              if (shouldShowAd) {
                UnityAdsService.instance.showInterstitialAd(
                  onDismissed: goToNextLevel,
                );
              } else {
                goToNextLevel();
              }
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
      builder: (ctx) => ListenableBuilder(
        listenable: widget.player,
        builder: (ctx, _) {
          return GameDialogWrapper(
            title: 'OUT OF MOVES!',
            content: Column(
              children: [
                const Icon(Icons.sentiment_dissatisfied_rounded, color: Color(0xFFFF5252), size: 54),
                const SizedBox(height: 10),
                Text(
                  'You popped ${_engine?.poppedCount ?? 0} / ${_engine?.targetPops ?? 0} blocks.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontFamily: 'Fredoka', color: Colors.white, fontSize: 16),
                ),
                const SizedBox(height: 14),

                // Option 1: Watch Ad to Get +5 Moves
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1B2358),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF3F51B5), width: 1.5),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00C853).withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.movie, color: Color(0xFF00E676), size: 24),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '+5 Extra Moves',
                              style: TextStyle(
                                fontFamily: 'Fredoka',
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                              ),
                            ),
                            Text(
                              'Watch video to keep playing!',
                              style: TextStyle(
                                fontFamily: 'Fredoka',
                                color: Colors.white70,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00C853),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          UnityAdsService.instance.showRewardedAd(
                            onRewardGranted: () {
                              _engine?.addMoves(5);
                              _dialogShown = false;
                              Navigator.of(ctx).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('🎉 Granted +5 Extra Moves!'),
                                  backgroundColor: Color(0xFF2E7D32),
                                ),
                              );
                            },
                            onFailedOrDismissed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Watch full ad to get extra moves.'),
                                  backgroundColor: Colors.orange,
                                ),
                              );
                            },
                          );
                        },
                        child: const OutlinedButtonText('Watch', fontSize: 13),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // Option 2: Watch Ad for +1 Heart
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1B2358),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF3F51B5), width: 1.5),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF5252).withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.favorite, color: Color(0xFFFF5252), size: 24),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Hearts: ${widget.player.hearts}/${PlayerState.maxHearts}',
                              style: const TextStyle(
                                fontFamily: 'Fredoka',
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                              ),
                            ),
                            const Text(
                              'Need hearts to retry level',
                              style: TextStyle(
                                fontFamily: 'Fredoka',
                                color: Colors.white70,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF1744),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          UnityAdsService.instance.showRewardedAd(
                            onRewardGranted: () {
                              widget.player.addHearts(1);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('🎉 Received +1 Heart!'),
                                  backgroundColor: Color(0xFF2E7D32),
                                ),
                              );
                            },
                            onFailedOrDismissed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Watch full ad to get a Heart.'),
                                  backgroundColor: Colors.orange,
                                ),
                              );
                            },
                          );
                        },
                        child: const OutlinedButtonText('+1 Heart', fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              GameButton3D(
                text: 'RETRY',
                width: 130,
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
              GameButton3D(
                text: 'HOME',
                width: 120,
                height: 48,
                fontSize: 16,
                surfaceColor: const Color(0xFF5C4CB2),
                shadowColor: const Color(0xFF3F3385),
                onTap: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        },
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
              listenable: Listenable.merge([_engine!, ProgressionService.instance]),
              builder: (context, _) {
                final prog = ProgressionService.instance;
                return GestureDetector(
                  onPanStart: (d) {
                    if (_currentTutorialStep != null) {
                      setState(() => _currentTutorialStep = null);
                    }
                    _engine!.onDragStart(d.localPosition);
                  },
                  onPanUpdate: (d) => _engine!.onDragUpdate(d.localPosition),
                  onPanEnd: (d) => _engine!.onDragEnd(d.localPosition),
                  child: CustomPaint(
                    size: size,
                    painter: FusionPainter(
                      engine: _engine!,
                      layout: _layout!,
                      colorblindMode: prog.colorblindMode,
                      equippedSkin: prog.equippedSkin,
                      equippedTheme: prog.equippedTheme,
                    ),
                  ),
                );
              },
            ),

          // 2. Tutorial Overlay (Section 2.1)
          if (_currentTutorialStep != null && _layout != null)
            TutorialOverlay(
              step: _currentTutorialStep!,
              fromRect: _layout!.blockRect(_currentTutorialStep!.from.col, _currentTutorialStep!.from.row),
              toRect: _layout!.blockRect(_currentTutorialStep!.to.col, _currentTutorialStep!.to.row),
              onDismiss: () => setState(() => _currentTutorialStep = null),
            ),

          // 3. Top Game HUD Header
          Positioned(
            top: safeTop > 0 ? safeTop + 4 : 12,
            left: 12,
            right: 12,
            child: ListenableBuilder(
              listenable: widget.player,
              builder: (context, _) => Column(
                children: [
                  HudRow(
                    player: widget.player,
                    onAddGems: () {
                      UnityAdsService.instance.recordMenuClick();
                      Popups.showDailyCheckIn(context, widget.player);
                    },
                    onAddHearts: () {
                      UnityAdsService.instance.recordMenuClick();
                      Popups.showOutOfHearts(context, widget.player);
                    },
                  ),
                  const SizedBox(height: 10),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GestureDetector(
                            onTap: () {
                              UnityAdsService.instance.recordMenuClick();
                              Popups.showSettings(context, widget.player);
                            },
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: const Color(0xFF5C4CB2),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: const Color(0xFF8A7AE6), width: 2),
                              ),
                              child: const Center(
                                child: Icon(Icons.settings, color: Colors.white, size: 26),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),

                          ChestProgressBar(
                            progress: widget.player.chestProgress,
                            onTap: () {
                              UnityAdsService.instance.recordMenuClick();
                              Popups.showMysteryChest(context, widget.player);
                            },
                          ),
                        ],
                      ),

                      // Center Level / Daily Title
                      Container(
                        height: 44,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        decoration: BoxDecoration(
                          color: widget.isDailyChallenge ? const Color(0xFFFF6D00) : GameColors.levelPill,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 1.5),
                          boxShadow: const [
                            BoxShadow(color: GameColors.levelPillDark, offset: Offset(0, 3)),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            widget.isDailyChallenge ? 'DAILY CHALLENGE' : 'LEVEL ${widget.levelId}',
                            style: const TextStyle(
                              fontFamily: 'Fredoka',
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                      ),

                      GestureDetector(
                        onTap: () {
                          UnityAdsService.instance.recordMenuClick();
                          Navigator.of(context).pop();
                        },
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0xFF5C4CB2),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFF8A7AE6), width: 2),
                          ),
                          child: const Center(
                            child: Icon(Icons.home_rounded, color: Colors.white, size: 28),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // 4. Bottom Goal & Animated Moves Counter (Section 2.3)
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

  /// Section 2.3: Goal Bar and Animated Moves Counter
  Widget _buildBottomBar() {
    if (_engine == null) return const SizedBox.shrink();

    return ListenableBuilder(
      listenable: _engine!,
      builder: (context, _) {
        final goal = _engine!.goal;
        final progress = goal.progress;
        final moves = _engine!.movesLeft;
        final isLowMoves = moves <= 3;

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
              // Moves Left Pill with scale "bump" & pulse when <= 3 (Section 2.3)
              TweenAnimationBuilder<double>(
                key: ValueKey(moves),
                tween: Tween(begin: 1.25, end: 1.0),
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutBack,
                builder: (context, scale, child) {
                  return Transform.scale(
                    scale: scale,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isLowMoves ? const Color(0xFFB71C1C) : const Color(0xFF261D52),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isLowMoves ? const Color(0xFFFF5252) : const Color(0xFFFFD600),
                          width: 1.8,
                        ),
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
                            '$moves',
                            style: TextStyle(
                              fontFamily: 'Fredoka',
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: isLowMoves ? Colors.white : const Color(0xFFFFD600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(width: 14),

              // Smooth Animated Goal Bar (Section 2.3 & User Request 2)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (goal.type == GoalType.popColor && goal.targetColorIndex != null) ...[
                              Container(
                                width: 14,
                                height: 14,
                                margin: const EdgeInsets.only(right: 6),
                                decoration: BoxDecoration(
                                  color: GameColors.blockColors[goal.targetColorIndex! % GameColors.blockColors.length],
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ] else if (goal.type == GoalType.createPower) ...[
                              const Padding(
                                padding: EdgeInsets.only(right: 4),
                                child: Text('×2', style: TextStyle(color: Color(0xFFFFD600), fontWeight: FontWeight.bold, fontSize: 13)),
                              ),
                            ] else if (goal.type == GoalType.clearObstacles) ...[
                              const Padding(
                                padding: EdgeInsets.only(right: 6),
                                child: Icon(Icons.ac_unit_rounded, color: Color(0xFF00E5FF), size: 16),
                              ),
                            ] else if (goal.type == GoalType.dropToBottom) ...[
                              const Padding(
                                padding: EdgeInsets.only(right: 6),
                                child: Icon(Icons.star_rounded, color: Color(0xFFFFD600), size: 18),
                              ),
                            ],
                            Text(
                              'GOAL: ${goal.dynamicTitle}',
                              style: const TextStyle(
                                fontFamily: 'Fredoka',
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '${goal.current} / ${goal.target}',
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
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: progress),
                      duration: const Duration(milliseconds: 350),
                      curve: Curves.easeOutCubic,
                      builder: (context, animValue, _) {
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: animValue,
                            minHeight: 10,
                            backgroundColor: Colors.white12,
                            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF00E676)),
                          ),
                        );
                      },
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
