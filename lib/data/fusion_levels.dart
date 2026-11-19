import '../game/fusion_models.dart';

/// Level goal variety definition (Starting directly at challenging Level 5 mechanics)
class FusionLevelConfig {
  final int levelId;
  final LevelGoal goal;
  final int maxMoves;
  final MergeRules rules;
  final List<List<ObstacleType>>? obstacles; // Grid of obstacles if any
  final List<({int col, int row})>? ingredients; // Positions of special falling items

  const FusionLevelConfig({
    required this.levelId,
    required this.goal,
    required this.maxMoves,
    this.rules = const MergeRules(),
    this.obstacles,
    this.ingredients,
  });

  /// Factory to get curated or procedurally balanced levels
  static FusionLevelConfig get(int levelId, {bool isDailyChallenge = false}) {
    if (isDailyChallenge) {
      return FusionLevelConfig(
        levelId: levelId,
        goal: LevelGoal(
          type: GoalType.reachScore,
          target: 1200,
          title: 'DAILY CHALLENGE',
          description: 'Score 1200 points!',
        ),
        maxMoves: 26,
        rules: const MergeRules(maxMergeDistance: 3),
      );
    }

    // Offset difficulty: Old level 5 becomes new Level 1!
    // Old levels 1-4 (trivial tutorial pop) removed.
    final effectiveLevel = levelId + 4;

    switch (levelId) {
      case 1:
        // New Level 1 (Formerly Level 5): Break 6 Ice blocks
        return FusionLevelConfig(
          levelId: 1,
          goal: LevelGoal(
            type: GoalType.clearObstacles,
            target: 6,
            title: 'BREAK ICE BLOCKS',
            description: 'Pop adjacent blocks to melt 6 Ice blocks!',
          ),
          maxMoves: 22,
          rules: const MergeRules(maxMergeDistance: 3),
          obstacles: _generateObstaclesForLevel1(),
        );

      case 2:
        // New Level 2 (Formerly Level 6): Bring 2 Stars to bottom row
        return FusionLevelConfig(
          levelId: 2,
          goal: LevelGoal(
            type: GoalType.dropToBottom,
            target: 2,
            title: 'RESCUE STARS',
            description: 'Pop blocks underneath to bring 2 Stars to the bottom row!',
          ),
          maxMoves: 20,
          rules: const MergeRules(maxMergeDistance: 3),
          ingredients: const [(col: 2, row: 1), (col: 4, row: 1)],
        );

      case 3:
        // New Level 3 (Formerly Level 7): Pop 18 Specific Color blocks
        return FusionLevelConfig(
          levelId: 3,
          goal: LevelGoal(
            type: GoalType.popColor,
            target: 18,
            targetColorIndex: 0, // Pink
            title: 'POP PINK BLOCKS',
            description: 'Pop 18 Pink blocks!',
          ),
          maxMoves: 18,
          rules: const MergeRules(maxMergeDistance: 3),
        );

      case 4:
        // New Level 4 (Formerly Level 8): Craft 4 Power Blocks
        return FusionLevelConfig(
          levelId: 4,
          goal: LevelGoal(
            type: GoalType.createPower,
            target: 4,
            title: 'CRAFT POWER BLOCKS',
            description: 'Fuse matching blocks to craft 4 Power Blocks (×2)!',
          ),
          maxMoves: 18,
          rules: const MergeRules(maxMergeDistance: 3),
        );

      case 5:
        // New Level 5: Clear 8 Ice and Stone obstacles
        return FusionLevelConfig(
          levelId: 5,
          goal: LevelGoal(
            type: GoalType.clearObstacles,
            target: 8,
            title: 'BREAK OBSTACLES',
            description: 'Break 8 Ice and Stone obstacles!',
          ),
          maxMoves: 22,
          rules: const MergeRules(maxMergeDistance: 2),
          obstacles: _generateProceduralObstacles(effectiveLevel, 8),
        );

      default:
        // Dynamic cycling for levels 6+:
        // Cycles between: popColor, createPower, clearObstacles, dropToBottom, reachScore
        final cycle = effectiveLevel % 5;
        final baseMoves = (16 + (effectiveLevel ~/ 3) * 2).clamp(14, 30);

        switch (cycle) {
          case 0:
            // Available color indices for the current level:
            final maxAvailableColors = (3 + (levelId ~/ 4)).clamp(3, 6);
            final color = (levelId + 1) % maxAvailableColors;
            final count = 16 + (effectiveLevel ~/ 4) * 2;
            return FusionLevelConfig(
              levelId: levelId,
              goal: LevelGoal(
                type: GoalType.popColor,
                target: count,
                targetColorIndex: color,
                title: 'POP COLOR',
                description: 'Pop $count blocks of the designated color!',
              ),
              maxMoves: baseMoves,
              rules: MergeRules(maxMergeDistance: levelId > 15 ? 2 : 3),
            );

          case 1:
            final powers = 4 + (effectiveLevel ~/ 10);
            return FusionLevelConfig(
              levelId: levelId,
              goal: LevelGoal(
                type: GoalType.createPower,
                target: powers,
                title: 'CRAFT POWER BLOCKS',
                description: 'Fuse blocks to craft $powers Power Blocks!',
              ),
              maxMoves: baseMoves,
              rules: MergeRules(maxMergeDistance: levelId > 15 ? 2 : 3),
            );

          case 2:
            final requestedObstacles = (8 + (effectiveLevel ~/ 8) * 2).clamp(8, 16);
            final obstaclesGrid = _generateProceduralObstacles(effectiveLevel, requestedObstacles);
            int actualPlaced = 0;
            for (int c = 0; c < 7; c++) {
              for (int r = 0; r < 9; r++) {
                if (obstaclesGrid[c][r] != ObstacleType.none) {
                  actualPlaced++;
                }
              }
            }

            return FusionLevelConfig(
              levelId: levelId,
              goal: LevelGoal(
                type: GoalType.clearObstacles,
                target: actualPlaced,
                title: 'CLEAR OBSTACLES',
                description: 'Clear $actualPlaced obstacle blocks!',
              ),
              maxMoves: baseMoves + 4,
              rules: MergeRules(maxMergeDistance: levelId > 15 ? 2 : 3),
              obstacles: obstaclesGrid,
            );

          case 3:
            final starCount = (2 + (effectiveLevel ~/ 15)).clamp(2, 4);
            return FusionLevelConfig(
              levelId: levelId,
              goal: LevelGoal(
                type: GoalType.dropToBottom,
                target: starCount,
                title: 'RESCUE STARS',
                description: 'Drop $starCount special Stars to the bottom row!',
              ),
              maxMoves: baseMoves + 2,
              rules: MergeRules(maxMergeDistance: levelId > 15 ? 2 : 3),
              ingredients: List.generate(
                starCount,
                (i) => (col: 1 + i * 2, row: 1),
              ),
            );

          case 4:
          default:
            final scoreTarget = 800 + effectiveLevel * 90;
            return FusionLevelConfig(
              levelId: levelId,
              goal: LevelGoal(
                type: GoalType.reachScore,
                target: scoreTarget,
                title: 'REACH SCORE',
                description: 'Score $scoreTarget points!',
              ),
              maxMoves: baseMoves,
              rules: MergeRules(maxMergeDistance: levelId > 15 ? 2 : 3),
            );
        }
    }
  }

  static List<List<ObstacleType>> _generateObstaclesForLevel1() {
    final grid = List.generate(
      7,
      (_) => List.filled(9, ObstacleType.none),
    );
    // 6 Ice blocks positioned centrally in rows 3 & 5
    grid[2][3] = ObstacleType.ice;
    grid[3][3] = ObstacleType.ice;
    grid[4][3] = ObstacleType.ice;
    grid[2][5] = ObstacleType.ice;
    grid[3][5] = ObstacleType.ice;
    grid[4][5] = ObstacleType.ice;
    return grid;
  }

  static List<List<ObstacleType>> _generateProceduralObstacles(int levelId, int count) {
    final grid = List.generate(
      7,
      (_) => List.filled(9, ObstacleType.none),
    );
    int placed = 0;
    // Allow placing obstacles across central rows 2 through 7 and cols 1 through 5 (30 possible spots)
    for (int r = 2; r <= 7 && placed < count; r++) {
      for (int c = 1; c <= 5 && placed < count; c++) {
        if ((c + r) % 2 == 0) {
          grid[c][r] = (levelId > 15 && placed % 2 == 1) ? ObstacleType.stone : ObstacleType.ice;
          placed++;
        }
      }
    }

    // Secondary pass if more obstacles needed than checkerboard pattern on rows 2-7
    for (int r = 2; r <= 7 && placed < count; r++) {
      for (int c = 1; c <= 5 && placed < count; c++) {
        if (grid[c][r] == ObstacleType.none) {
          grid[c][r] = (levelId > 15 && placed % 2 == 1) ? ObstacleType.stone : ObstacleType.ice;
          placed++;
        }
      }
    }

    return grid;
  }
}
