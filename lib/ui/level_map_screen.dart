import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/progression_service.dart';
import '../core/theme.dart';
import '../data/player_state.dart';
import 'widgets/hud_pills.dart';
import 'widgets/popups.dart';
import '../game/fusion_game_screen.dart';

class LevelMapScreen extends StatefulWidget {
  final PlayerState player;

  const LevelMapScreen({super.key, required this.player});

  @override
  State<LevelMapScreen> createState() => _LevelMapScreenState();
}

class _LevelMapScreenState extends State<LevelMapScreen> {
  final ScrollController _scrollCtrl = ScrollController();
  final int totalLevels = 60;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autoScrollToCurrentLevel();
    });
  }

  void _autoScrollToCurrentLevel() {
    final highest = ProgressionService.instance.highestUnlockedLevel;
    // Levels run from bottom (1) to top (60)
    // Level 1 is at the bottom, so reverse position
    final targetLevel = highest.clamp(1, totalLevels);
    final offset = (totalLevels - targetLevel) * 95.0;
    if (_scrollCtrl.hasClients) {
      _scrollCtrl.animateTo(
        offset.clamp(0.0, _scrollCtrl.position.maxScrollExtent),
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GameColors.bgDarkPlayfield,
      body: SafeArea(
        child: ListenableBuilder(
          listenable: Listenable.merge([widget.player, ProgressionService.instance]),
          builder: (context, _) {
            final prog = ProgressionService.instance;
            final highest = prog.highestUnlockedLevel;
            final totalStars = prog.totalStars;

            return Column(
              children: [
                // Top Header: Total Stars, Daily Challenge Button, Shop Button, Back Button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Back Button
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: const Color(0xFF5C4CB2),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFF8A7AE6), width: 2),
                          ),
                          child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 24),
                        ),
                      ),

                      // Stars Counter Pill (Section 1.2)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF261D52),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFFFD600), width: 1.8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.star_rounded, color: Color(0xFFFFD600), size: 24),
                            const SizedBox(width: 6),
                            Text(
                              '$totalStars STARS',
                              style: const TextStyle(
                                fontFamily: 'Fredoka',
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Daily Challenge shortcut
                      GestureDetector(
                        onTap: () => _openDailyChallenge(),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [Color(0xFFFF9100), Color(0xFFFF3D00)]),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.calendar_month_rounded, color: Colors.white, size: 18),
                              SizedBox(width: 4),
                              Text(
                                'DAILY',
                                style: TextStyle(
                                  fontFamily: 'Fredoka',
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Scrollable Level Map (Bottom = Level 1, Top = Level 60)
                Expanded(
                  child: ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    itemCount: totalLevels,
                    itemBuilder: (context, index) {
                      // Reverse index so 60 is at top, 1 at bottom
                      final levelId = totalLevels - index;
                      final isUnlocked = levelId <= highest;
                      final isCompleted = levelId < highest;
                      final isMilestone = levelId % 10 == 0;
                      final stars = prog.getLevelProgress(levelId).stars;

                      // S-curve horizontal wave offset
                      final waveOffset = math.sin(levelId * 0.75) * 65.0;

                      return Transform.translate(
                        offset: Offset(waveOffset, 0),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Center(
                            child: _buildLevelNode(
                              levelId: levelId,
                              isUnlocked: isUnlocked,
                              isCompleted: isCompleted,
                              isMilestone: isMilestone,
                              stars: stars,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildLevelNode({
    required int levelId,
    required bool isUnlocked,
    required bool isCompleted,
    required bool isMilestone,
    required int stars,
  }) {
    final size = isMilestone ? 74.0 : 62.0;

    return GestureDetector(
      onTap: () {
        if (!isUnlocked) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Reach Level $levelId to unlock!'), backgroundColor: Colors.orange),
          );
          return;
        }
        _showPreLevelDialog(levelId);
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: isMilestone
                  ? const LinearGradient(colors: [Color(0xFFFFD600), Color(0xFFFF6D00)])
                  : (isUnlocked
                      ? const LinearGradient(colors: [Color(0xFF00E676), Color(0xFF00B0FF)])
                      : const LinearGradient(colors: [Color(0xFF424242), Color(0xFF212121)])),
              border: Border.all(
                color: isUnlocked ? Colors.white : Colors.white24,
                width: isMilestone ? 3.5 : 2.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: isUnlocked ? const Color(0xFF00E676).withValues(alpha: 0.5) : Colors.black38,
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Center(
              child: isMilestone
                  ? const Icon(Icons.card_giftcard_rounded, color: Colors.white, size: 32)
                  : (isUnlocked
                      ? Text(
                          '$levelId',
                          style: const TextStyle(
                            fontFamily: 'Fredoka',
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.lock_rounded, color: Colors.white54, size: 26)),
            ),
          ),
          const SizedBox(height: 4),

          // Star rating below completed node (Section 1.2)
          if (isCompleted || stars > 0)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) {
                return Icon(
                  Icons.star_rounded,
                  size: 16,
                  color: i < stars ? const Color(0xFFFFD600) : Colors.white24,
                );
              }),
            ),
        ],
      ),
    );
  }

  void _showPreLevelDialog(int levelId) {
    final prog = ProgressionService.instance.getLevelProgress(levelId);
    final targetPops = 25 + levelId * 5;
    final maxMoves = 20 + (levelId ~/ 2) * 2;

    showDialog(
      context: context,
      builder: (ctx) => GameDialogWrapper(
        title: 'LEVEL $levelId',
        content: Column(
          children: [
            Text(
              'Goal: Pop $targetPops blocks in $maxMoves moves!',
              textAlign: TextAlign.center,
              style: const TextStyle(fontFamily: 'Fredoka', fontSize: 16, color: Colors.white),
            ),
            const SizedBox(height: 12),
            if (prog.stars > 0)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(3, (i) {
                  return Icon(
                    Icons.star_rounded,
                    size: 26,
                    color: i < prog.stars ? const Color(0xFFFFD600) : Colors.white24,
                  );
                }),
              ),
          ],
        ),
        actions: [
          GameButton3D(
            text: 'PLAY',
            width: 150,
            height: 50,
            fontSize: 20,
            surfaceColor: const Color(0xFF00E676),
            shadowColor: const Color(0xFF00A344),
            onTap: () {
              Navigator.of(ctx).pop();
              if (widget.player.consumeHeartForGame()) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => FusionGameScreen(
                      levelId: levelId,
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

  void _openDailyChallenge() {
    final todayKey = DateTime.now().toUtc().toString().substring(0, 10).replaceAll('-', '');
    final seed = int.tryParse(todayKey) ?? 20261118;

    if (widget.player.consumeHeartForGame()) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => FusionGameScreen(
            levelId: 999,
            player: widget.player,
            isDailyChallenge: true,
            fixedSeed: seed,
          ),
        ),
      );
    } else {
      Popups.showOutOfHearts(context, widget.player);
    }
  }
}
