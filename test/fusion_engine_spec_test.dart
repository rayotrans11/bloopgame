import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bloop_pop/game/fusion_engine.dart';
import 'package:bloop_pop/game/fusion_models.dart';
import 'package:bloop_pop/core/deterministic_rng.dart';

void main() {
  group('Color Fusion Pop - Section 3 Core Mechanics Unit Tests', () {
    test('3.1 & 3.2 Merge Results Table and Manhattan Distance constraint', () {
      final board = List.generate(
        FusionLayout.cols,
        (_) => List<FusionBlock?>.filled(FusionLayout.rows, null, growable: false),
      );

      // Place Lv1 Pink block at (2, 2)
      board[2][2] = FusionBlock(col: 2, row: 2, colorIndex: 0, fusionLevel: 1);
      // Place Lv1 Pink block at (2, 4) - Manhattan distance = 2 (legal by default)
      board[2][4] = FusionBlock(col: 2, row: 4, colorIndex: 0, fusionLevel: 1);
      // Place Lv1 Pink block at (2, 5) - Manhattan distance = 3 (illegal when maxMergeDistance = 2)
      board[2][5] = FusionBlock(col: 2, row: 5, colorIndex: 0, fusionLevel: 1);

      const rules = MergeRules(maxMergeDistance: 2, requireStraightLine: false);

      // Distance 2 -> Valid merge, Lv1 + Lv1 -> Lv2
      final simLegal = FusionEngine.simulateMove(
        boardState: board,
        from: (col: 2, row: 2),
        to: (col: 2, row: 4),
        rules: rules,
      );
      expect(simLegal.isValid, isTrue);
      expect(simLegal.isMerge, isTrue);
      expect(simLegal.resultingLevel, equals(2));

      // Distance 3 -> Invalid merge
      final simIllegal = FusionEngine.simulateMove(
        boardState: board,
        from: (col: 2, row: 2),
        to: (col: 2, row: 5),
        rules: rules,
      );
      expect(simIllegal.isValid, isFalse);
    });

    test('3.2 Lv2 + Lv2 -> Lv3 Super Block & Lv3 + Lv3 -> Lv4 Mega Block', () {
      final board = List.generate(
        FusionLayout.cols,
        (_) => List<FusionBlock?>.filled(FusionLayout.rows, null, growable: false),
      );

      board[1][1] = FusionBlock(col: 1, row: 1, colorIndex: 2, fusionLevel: 2);
      board[1][2] = FusionBlock(col: 1, row: 2, colorIndex: 2, fusionLevel: 2);

      const rules = MergeRules(maxMergeDistance: 2);

      final simSuper = FusionEngine.simulateMove(
        boardState: board,
        from: (col: 1, row: 1),
        to: (col: 1, row: 2),
        rules: rules,
      );
      expect(simSuper.resultingLevel, equals(3));
      expect(simSuper.burstType, isNot(BurstType.none));

      // Mega Block test
      board[3][3] = FusionBlock(col: 3, row: 3, colorIndex: 1, fusionLevel: 3);
      board[3][4] = FusionBlock(col: 3, row: 4, colorIndex: 1, fusionLevel: 3);

      final simMega = FusionEngine.simulateMove(
        boardState: board,
        from: (col: 3, row: 3),
        to: (col: 3, row: 4),
        rules: rules,
      );
      expect(simMega.resultingLevel, equals(4));
      expect(simMega.burstType, equals(BurstType.colorWipe));
    });

    test('3.5 Group >= 3 Popping Rule vs Setup Move', () {
      final board = List.generate(
        FusionLayout.cols,
        (_) => List<FusionBlock?>.filled(FusionLayout.rows, null, growable: false),
      );

      // Case A: Isolated 2 blocks merge without 3rd neighbor -> Setup move (no pop)
      board[0][0] = FusionBlock(col: 0, row: 0, colorIndex: 4, fusionLevel: 1);
      board[0][1] = FusionBlock(col: 0, row: 1, colorIndex: 4, fusionLevel: 1);

      final simSetup = FusionEngine.simulateMove(
        boardState: board,
        from: (col: 0, row: 0),
        to: (col: 0, row: 1),
        rules: const MergeRules(),
      );
      expect(simSetup.isValid, isTrue);
      expect(simSetup.isMerge, isTrue);
      expect(simSetup.popCells.isEmpty, isTrue); // Setup move, no pop!

      // Case B: 3rd and 4th neighbor present so connected cluster >= 3 blocks
      board[0][2] = FusionBlock(col: 0, row: 2, colorIndex: 4, fusionLevel: 1);
      board[0][3] = FusionBlock(col: 0, row: 3, colorIndex: 4, fusionLevel: 1);
      final simPop = FusionEngine.simulateMove(
        boardState: board,
        from: (col: 0, row: 0),
        to: (col: 0, row: 1),
        rules: const MergeRules(),
      );
      expect(simPop.popCells.length, greaterThanOrEqualTo(3));
    });

    test('1.4 Deterministic Mulberry32 PRNG exact sequence reproducibility', () {
      final rngA = DeterministicRng(20261118);
      final rngB = DeterministicRng(20261118);

      final listA = List.generate(50, (_) => rngA.nextInt(6));
      final listB = List.generate(50, (_) => rngB.nextInt(6));

      expect(listA, equals(listB));
    });

    test('3.4 Level Goals: Goal completes and prevents infinite cascade loop', () {
      final layout = FusionLayout(const Size(360, 640));
      final goal = LevelGoal(
        type: GoalType.popTotal,
        target: 5,
        title: 'TEST POP',
        description: 'Test pop goal',
      );

      final engine = FusionEngine(
        layout: layout,
        levelId: 1,
        maxMoves: 10,
        goal: goal,
      );

      expect(engine.phase, equals(FusionPhase.idle));
      expect(engine.goal.isMet, isFalse);

      // Artificially satisfy goal
      engine.goal.current = 5;
      expect(engine.goal.isMet, isTrue);

      // Tick update triggers check
      engine.update(0.1);
      expect(engine.phase, equals(FusionPhase.won));
    });

    test('3.4 Obstacles & Ingredients integration', () {
      final layout = FusionLayout(const Size(360, 640));
      final goal = LevelGoal(
        type: GoalType.clearObstacles,
        target: 2,
        title: 'CLEAR OBSTACLES',
        description: 'Clear obstacles test',
      );

      final obsGrid = List.generate(
        FusionLayout.cols,
        (_) => List.filled(FusionLayout.rows, ObstacleType.none),
      );
      obsGrid[2][2] = ObstacleType.ice;

      final engine = FusionEngine(
        layout: layout,
        levelId: 5,
        maxMoves: 15,
        goal: goal,
        initialObstacles: obsGrid,
        initialIngredients: const [(col: 3, row: 1)],
      );

      expect(engine.grid[2][2]?.isObstacle, isTrue);
      expect(engine.grid[3][1]?.isIngredient, isTrue);
    });
  });
}
