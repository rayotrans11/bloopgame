import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../core/ads_service.dart';
import '../core/game_audio.dart';
import '../core/layout.dart';
import '../core/theme.dart';
import '../data/levels_data.dart';
import '../data/player_state.dart';
import '../ui/widgets/game_icons.dart';
import '../ui/widgets/hud_pills.dart';
import '../ui/widgets/popups.dart';
import 'engine.dart';
import 'models.dart';
import 'painter.dart';

class GameScreen extends StatefulWidget {
  final int levelId;
  final PlayerState player;
  final GameMode gameMode;

  const GameScreen({
    super.key,
    required this.levelId,
    required this.player,
    this.gameMode = GameMode.classic,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final ValueNotifier<int> _repaintTick = ValueNotifier<int>(0);
  Duration _lastTick = Duration.zero;

  GameEngine? _engine;
  Layout? _layout;
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
        _repaintTick.value++;

        if (!_dialogShown) {
          if (_engine!.phase == Phase.won) {
            _dialogShown = true;
            _onWin();
          } else if (_engine!.phase == Phase.lost) {
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
    _repaintTick.dispose();
    super.dispose();
  }

  void _initEngine(Size size, double safeTop, double safeBottom) {
    if (_layout != null && _layout!.w == size.width && _layout!.h == size.height) return;

    _layout = Layout(size, safeTop: safeTop, safeBottom: safeBottom);

    // If engine was already running mid-game when fold/unfold/resize occurred, preserve state!
    if (_engine != null) {
      _engine!.updateLayout(_layout!);
      return;
    }

    final levelDef = widget.gameMode == GameMode.bossRush
        ? LevelRepository.getBossLevel((widget.levelId % 5) + 1)
        : widget.gameMode == GameMode.speedRush
            ? LevelRepository.getSpeedRushLevel(widget.levelId)
            : LevelRepository.getLevel(widget.levelId);

    _engine = GameEngine(
      layout: _layout!,
      startBlocks: levelDef.blocks,
      startOrbs: levelDef.orbs,
      baseBalls: levelDef.balls,
      descendEachTurn: widget.gameMode != GameMode.speedRush,
      gameMode: widget.gameMode,
      onBlockHit: () {
        GameAudio.instance.play(GameSound.blockHit);
        GameAudio.instance.haptic(GameHaptic.light);
      },
      onBlockDestroyed: () {
        widget.player.recordBlockPopped(1);
        GameAudio.instance.play(GameSound.blockPop);
        GameAudio.instance.haptic(GameHaptic.medium);
      },
      onOrbTriggered: () {
        GameAudio.instance.play(GameSound.orb);
        GameAudio.instance.haptic(GameHaptic.selection);
      },
    );
  }

  void _onWin() {
    GameAudio.instance.play(GameSound.win);
    GameAudio.instance.haptic(GameHaptic.success);

    if (widget.gameMode == GameMode.bossRush) {
      widget.player.recordBossDefeated();
      const earned = 0.10; // Extra bonus for defeating a Boss Guardian
      widget.player.addCash(earned);
      widget.player.addGems(15);
      Popups.showWin(context, widget.levelId, earned, () {
        Navigator.of(context).pop();
      }, player: widget.player);
      return;
    }

    if (widget.gameMode == GameMode.speedRush) {
      final finalScore = _engine?.cashEarned ?? 0;
      widget.player.recordSpeedRushScore(finalScore);
      widget.player.addGems(10);
      Popups.showSpeedRushSummary(context, finalScore, widget.player.speedRushHighScore, () {
        Navigator.of(context).pop();
      });
      return;
    }

    const earned = 0.04;
    widget.player.completeLevel(widget.levelId, earned);
    Popups.showWin(context, widget.levelId, earned, () {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => GameScreen(
            levelId: widget.levelId + 1,
            player: widget.player,
            gameMode: widget.gameMode,
          ),
        ),
      );
    }, player: widget.player);
  }

  void _onLose() {
    GameAudio.instance.play(GameSound.lose);
    GameAudio.instance.haptic(GameHaptic.error);
    Popups.showLose(context, () {
      if (widget.player.consumeHeartForGame()) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => GameScreen(
              levelId: widget.levelId,
              player: widget.player,
              gameMode: widget.gameMode,
            ),
          ),
        );
      } else {
        Popups.showOutOfHearts(context, widget.player);
      }
    }, () {
      Navigator.of(context).pop();
    });
  }

  void _fire(GameEngine engine) {
    if (engine.phase != Phase.aiming) return;
    engine.fire();
    GameAudio.instance.play(GameSound.launch);
    GameAudio.instance.haptic(GameHaptic.light);
  }

  void _activatePowerup(
    BuildContext context,
    GameEngine engine,
    String id,
    bool Function() activate,
  ) {
    if (!widget.player.usePowerup(id)) {
      _watchAdForPowerup(context, id);
      return;
    }

    if (activate()) {
      GameAudio.instance.play(GameSound.powerUp);
      GameAudio.instance.haptic(GameHaptic.selection);
    } else {
      widget.player.addPowerup(id, 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);

    return Scaffold(
      backgroundColor: GameColors.bgPlayfield,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest;
          _initEngine(size, mq.padding.top, mq.padding.bottom);
          final engine = _engine!;

          return ListenableBuilder(
            listenable: widget.player,
            builder: (context, _) {
              return Stack(
                children: [
                  // 1. Gesture detector for Direction 4 + 1 Bloop Cannon shooting
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (d) {
                      // Tap to shoot cannon projectile
                      if (engine.shootCannonOrb(d.localPosition)) {
                        GameAudio.instance.play(GameSound.launch);
                        GameAudio.instance.haptic(GameHaptic.light);
                      }
                    },
                    onPanStart: (d) => engine.setAim(d.localPosition),
                    onPanUpdate: (d) => engine.setAim(d.localPosition),
                    onPanEnd: (_) {
                      // Aim release fire
                      if (engine.shootCannonOrb(engine.aimDir * 1000 + Offset(engine.launcherX, engine.layout.floorY))) {
                        GameAudio.instance.play(GameSound.launch);
                        GameAudio.instance.haptic(GameHaptic.light);
                      } else {
                        _fire(engine);
                      }
                      engine.cancelAim();
                    },
                    onPanCancel: engine.cancelAim,
                    child: CustomPaint(
                      size: size,
                      painter: GamePainter(
                        engine: engine,
                        ballSkin: widget.player.ballSkin,
                        ballTrail: widget.player.ballTrail,
                        repaint: _repaintTick,
                      ),
                    ),
                  ),

                  // 2. Top HUD Overlay
                  Positioned(
                    top: mq.padding.top > 0 ? mq.padding.top + 4 : 12,
                    left: 12,
                    right: 12,
                    child: Column(
                      children: [
                        // Row 1: Cash (no plus), Gems (Daily Check-in), Big Heart with number inside
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

                        // Row 2: Settings Button, Mystery Box / Chest Bar, LEVEL N pill, Home Button
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Left group: Settings button + Mystery Box / Chest Progress Bar
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Settings Button (styled like Home button)
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
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.35),
                                          offset: const Offset(0, 2),
                                          blurRadius: 4,
                                        ),
                                      ],
                                    ),
                                    child: const Center(
                                      child: Icon(Icons.settings, color: Colors.white, size: 26),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),

                                // Mystery Chest Progress Bar
                                ChestProgressBar(
                                  progress: widget.player.chestProgress,
                                  onTap: () {
                                    UnityAdsService.instance.recordMenuClick();
                                    Popups.showMysteryChest(context, widget.player);
                                  },
                                ),
                              ],
                            ),

                            // Center: LEVEL N Pill / Speed Rush Timer / Boss Title
                            Container(
                              height: 44,
                              padding: const EdgeInsets.symmetric(horizontal: 18),
                              decoration: BoxDecoration(
                                color: widget.gameMode == GameMode.bossRush
                                    ? const Color(0xFFC2185B)
                                    : widget.gameMode == GameMode.speedRush
                                        ? const Color(0xFFFF6D00)
                                        : GameColors.levelPill,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 1.5),
                                boxShadow: [
                                  BoxShadow(
                                    color: widget.gameMode == GameMode.bossRush
                                        ? const Color(0xFF880E4F)
                                        : widget.gameMode == GameMode.speedRush
                                            ? const Color(0xFFE65100)
                                            : GameColors.levelPillDark,
                                    offset: const Offset(0, 3),
                                  ),
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.3),
                                    offset: const Offset(0, 4),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  widget.gameMode == GameMode.bossRush
                                      ? 'BOSS BATTLE'
                                      : widget.gameMode == GameMode.speedRush
                                          ? '${engine.speedRushTimeRemaining.toInt()}s | ${engine.cashEarned} pts'
                                          : 'LEVEL ${widget.levelId}',
                                  style: const TextStyle(
                                    fontFamily: 'Fredoka',
                                    fontSize: 17,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    letterSpacing: 0.8,
                                    shadows: [
                                      Shadow(color: Colors.black38, offset: Offset(0, 1), blurRadius: 2),
                                    ],
                                  ),
                                ),
                              ),
                            ),

                            // Right: Home Button
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
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.35),
                                      offset: const Offset(0, 2),
                                      blurRadius: 4,
                                    ),
                                  ],
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

                  // 3. Bottom Toolbar Area (Swap Cannon Orb & Power-Up Skills)
                  Positioned(
                    bottom: mq.padding.bottom > 0 ? mq.padding.bottom + 6 : 14,
                    left: 12,
                    right: 12,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // SWAP Cannon Color Button
                        GestureDetector(
                          onTap: () {
                            engine.swapCannonOrbs();
                            GameAudio.instance.play(GameSound.uiTap);
                            GameAudio.instance.haptic(GameHaptic.selection);
                          },
                          child: Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: const Color(0xFF6A1B9A),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFE1BEE7), width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.4),
                                  offset: const Offset(0, 3),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                            child: const Center(
                              child: Icon(Icons.swap_horiz_rounded, color: Colors.white, size: 30),
                            ),
                          ),
                        ),

                        // Powerup 1: Bomb Wave
                        _powerupBtn(
                          context,
                          iconType: 'pu_smash',
                          count: widget.player.powerups['smash'] ?? 0,
                          onTap: () => _activatePowerup(context, engine, 'smash', () {
                            engine.projectileOrbs.add(ProjectileOrb(
                              pos: Offset(engine.launcherX, engine.layout.floorY - engine.layout.r),
                              vel: const Offset(0, -600),
                              colorIndex: CannonColor.bomb,
                            ));
                            return true;
                          }),
                        ),

                        // Powerup 2: Cryo Freeze (Freezes descent for 4s)
                        _powerupBtn(
                          context,
                          iconType: 'pu_row',
                          count: widget.player.powerups['rowBlast'] ?? 0,
                          onTap: () => _activatePowerup(context, engine, 'rowBlast', () {
                            engine.freezeTimer = 4.0;
                            return true;
                          }),
                        ),

                        // Powerup 3: Wildcard Rainbow Orb
                        _powerupBtn(
                          context,
                          iconType: 'pu_fire',
                          count: widget.player.powerups['fire'] ?? 0,
                          onTap: () => _activatePowerup(context, engine, 'fire', () {
                            engine.isWildcardActive = true;
                            return true;
                          }),
                        ),

                        // Powerup 4: Clear Bottom Row
                        _powerupBtn(
                          context,
                          iconType: 'pu_stone',
                          count: widget.player.powerups['stone'] ?? 0,
                          onTap: () => _activatePowerup(context, engine, 'stone', engine.triggerSmash),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _powerupBtn(
    BuildContext context, {
    required String iconType,
    required int count,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 60,
            height: 60,
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: const Color(0xFF161A5B),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: GameColors.pillBorder, width: 2.2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  offset: const Offset(0, 3),
                  blurRadius: 4,
                ),
              ],
            ),
            child: CustomPaint(painter: GameIconPainter(type: iconType)),
          ),

          // Count or Ad badge
          Positioned(
            right: -4,
            top: -4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: count > 0 ? const Color(0xFF00C853) : const Color(0xFFFF9100),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white, width: 1.2),
              ),
              child: Text(
                count > 0 ? '$count' : 'Ad',
                style: const TextStyle(
                  fontFamily: 'Fredoka',
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _watchAdForPowerup(BuildContext context, String id) {
    UnityAdsService.instance.showRewardedAd(
      onRewardGranted: () {
        widget.player.addPowerup(id, 1);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Received +1 free $id power-up!'),
            backgroundColor: const Color(0xFF2E7D32),
            duration: const Duration(seconds: 2),
          ),
        );
      },
      onFailedOrDismissed: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Watch the full video to get the power-up.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
      },
    );
  }
}
