import 'package:flutter_test/flutter_test.dart';
import 'package:bloop_pop/data/levels_data.dart';
import 'package:bloop_pop/data/player_state.dart';
import 'package:bloop_pop/game/engine.dart';
import 'package:bloop_pop/game/models.dart';
import 'package:bloop_pop/core/layout.dart';
import 'package:flutter/material.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Distinct Gameplay Modes & Features Tests', () {
    test('Boss Guardian level generates BossBlock and shield blocks', () {
      final bossDef = LevelRepository.getBossLevel(1);
      expect(bossDef.blocks.any((b) => b.isBoss), isTrue);
      final bossBlocks = bossDef.blocks.where((b) => b.isBoss).toList();
      expect(bossBlocks.length, 6); // 3x2 multi-cell boss
      expect(bossBlocks.first.bossTitle, 'NEON GOLEM');
      expect(bossDef.balls, greaterThanOrEqualTo(35));
    });

    test('Speed Rush generates high-density block field and handles 60s countdown', () {
      final speedDef = LevelRepository.getSpeedRushLevel(42);
      expect(speedDef.blocks.isNotEmpty, isTrue);

      final layout = Layout(const Size(400, 800));
      final engine = GameEngine(
        layout: layout,
        startBlocks: speedDef.blocks,
        startOrbs: speedDef.orbs,
        baseBalls: speedDef.balls,
        descendEachTurn: false,
        gameMode: GameMode.speedRush,
      );

      expect(engine.speedRushTimeRemaining, 60.0);
      for (int i = 0; i < 150; i++) {
        engine.update(1 / 30);
      }
      expect(engine.speedRushTimeRemaining, closeTo(55.0, 0.2));
    });

    test('PlayerState tracks achievements and milestones', () {
      final player = PlayerState();
      expect(player.totalBlocksPopped, 0);
      expect(player.bossesDefeated, 0);

      player.recordBlockPopped(10);
      expect(player.totalBlocksPopped, 10);

      player.recordBossDefeated();
      expect(player.bossesDefeated, 1);

      player.recordSpeedRushScore(150);
      expect(player.speedRushHighScore, 150);

      final claimed = player.claimAchievement('boss_1', gemsReward: 30, cashReward: 0.20);
      expect(claimed, isTrue);
      expect(player.isAchievementClaimed('boss_1'), isTrue);
      // Double claim should return false
      expect(player.claimAchievement('boss_1'), isFalse);
    });

    test('PlayerState supports custom Ball Trail selection', () {
      final player = PlayerState();
      expect(player.ballTrail, 'neon');
      player.setTrail('rainbow');
      expect(player.ballTrail, 'rainbow');
      player.setTrail('fire');
      expect(player.ballTrail, 'fire');
    });

    test('Warp Portals teleport balls across paired coordinates', () {
      final layout = Layout(const Size(400, 800));
      final portal1 = Orb(col: 2, row: 2, kind: OrbKind.portalBlue, portalTargetCol: 8, portalTargetRow: 2);
      final portal2 = Orb(col: 8, row: 2, kind: OrbKind.portalOrange, portalTargetCol: 2, portalTargetRow: 2);

      final engine = GameEngine(
        layout: layout,
        startBlocks: [],
        startOrbs: [portal1, portal2],
        baseBalls: 5,
        descendEachTurn: false,
      );

      final ball = Ball(
        pos: layout.cellCenter(2, 2),
        vel: const Offset(100, 0),
      );
      engine.balls.add(ball);
      engine.phase = Phase.shooting;
      engine.update(0.02);

      // Ball should have been teleported near target portal (8, 2)
      final targetCenter = layout.cellCenter(8, 2);
      expect((ball.pos - targetCenter).distance, lessThan(layout.cellW));
    });

    test('Boss summons mini-drones and activates dynamic energy shield', () {
      final bossDef = LevelRepository.getBossLevel(1);
      final layout = Layout(const Size(400, 800));
      final engine = GameEngine(
        layout: layout,
        startBlocks: bossDef.blocks,
        startOrbs: bossDef.orbs,
        baseBalls: bossDef.balls,
        descendEachTurn: false,
        gameMode: GameMode.bossRush,
      );

      // Force Boss to enter Enraged state (<50% HP)
      for (final b in engine.blocks.where((b) => b.isBoss)) {
        b.hp = 10;
      }
      engine.bossEnraged = true;
      engine.bossTurnCounter = 1; // Next turn will be 2 (even -> trigger drone spawn)

      // Simulate returning balls
      engine.balls.add(Ball(pos: Offset(100, layout.floorY - layout.r), vel: Offset.zero)..landed = true);
      engine.phase = Phase.returning;
      for (int i = 0; i < 10; i++) {
        engine.update(1 / 30); // 10 * (1/30) = 0.33s > 0.18s
      }

      expect(engine.blocks.any((b) => b.isDrone), isTrue);
    });
  });
}
