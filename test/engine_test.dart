import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:bloop_pop/core/layout.dart';
import 'package:bloop_pop/data/levels_data.dart';
import 'package:bloop_pop/game/engine.dart';
import 'package:bloop_pop/game/models.dart';

void main() {
  group('GameEngine Physics and Mechanics Tests', () {
    late Layout layout;

    setUp(() {
      layout = Layout(const Size(576, 1280));
    });

    test('Initializes with Level 1 layout and correct blocks/orbs', () {
      final level1 = LevelRepository.getLevel(1);
      final engine = GameEngine(
        layout: layout,
        startBlocks: level1.blocks,
        startOrbs: level1.orbs,
        baseBalls: level1.balls,
      );

      expect(engine.ballCount, equals(30));
      expect(engine.blocks.isNotEmpty, isTrue);
      expect(engine.orbs.length, equals(3));
      expect(engine.phase, equals(Phase.idle));
      expect(engine.counter, equals(30));
    });

    test('Aiming sets aim direction and transitions to aiming phase', () {
      final level1 = LevelRepository.getLevel(1);
      final engine = GameEngine(
        layout: layout,
        startBlocks: level1.blocks,
        startOrbs: level1.orbs,
        baseBalls: level1.balls,
      );

      engine.setAim(Offset(layout.w / 2, layout.hudH + 100));
      expect(engine.phase, equals(Phase.aiming));
      expect(engine.aimDir.dy, lessThan(0)); // Aiming upward
    });

    test('Firing transitions to shooting phase and emits balls', () {
      final level1 = LevelRepository.getLevel(1);
      final engine = GameEngine(
        layout: layout,
        startBlocks: level1.blocks,
        startOrbs: level1.orbs,
        baseBalls: level1.balls,
      );

      engine.setAim(Offset(layout.w / 2, layout.hudH + 100));
      engine.fire();

      expect(engine.phase, equals(Phase.shooting));
      expect(engine.toFire, equals(30));

      // Advance by 0.1s
      engine.update(0.1);
      expect(engine.balls.isNotEmpty, isTrue);
    });

    test('Power-up: More Balls increases ball count', () {
      final level1 = LevelRepository.getLevel(1);
      final engine = GameEngine(
        layout: layout,
        startBlocks: level1.blocks,
        startOrbs: level1.orbs,
        baseBalls: 30,
      );

      engine.triggerMoreBalls();
      expect(engine.ballCount, equals(40));
    });

    test('Power-up: Row Blast deals 2 damage to all blocks', () {
      final block = Block(col: 3, row: 2, hp: 5, colorIndex: 1);
      final engine = GameEngine(
        layout: layout,
        startBlocks: [block],
        startOrbs: [],
        baseBalls: 10,
      );

      engine.triggerRowBlast();
      expect(block.hp, equals(3));
    });

    test('Power-up: Fire Ball sets damage to 2 and activates fire', () {
      final engine = GameEngine(
        layout: layout,
        startBlocks: [],
        startOrbs: [],
        baseBalls: 10,
      );

      engine.triggerFireBall();
      expect(engine.damage, equals(2));
      expect(engine.isFireActive, isTrue);
    });
  });
}
