import 'dart:math' as math;
import '../game/models.dart';

class LevelDefinition {
  final int level;
  final int balls;
  final List<Block> blocks;
  final List<Orb> orbs;

  LevelDefinition({
    required this.level,
    required this.balls,
    required this.blocks,
    required this.orbs,
  });
}

class LevelRepository {
  static LevelDefinition getLevel(int levelId) {
    if (levelId == 1) {
      return _buildLevel1();
    } else if (levelId == 3) {
      return _buildLevel3();
    } else {
      return _generateLevel(levelId);
    }
  }

  /// Distinct Mode 1: Boss Battle (Guardian Encounter)
  /// Features a centered massive boss block with dynamic shields and special health pool.
  static LevelDefinition getBossLevel(int bossIndex) {
    final blocks = <Block>[];
    final orbs = <Orb>[];
    final bossHp = 40 + (bossIndex * 25);
    final bossTitle = bossIndex == 1
        ? 'NEON GOLEM'
        : bossIndex == 2
            ? 'CRYSTAL TITAN'
            : 'CYBER DRAKE #$bossIndex';

    // The Boss occupies col 4, 5, 6 across rows 2 and 3
    // We register the boss centerpiece at (col 4, row 2) and give it Boss attributes
    blocks.add(Block(
      col: 4,
      row: 2,
      hp: bossHp,
      bossMaxHp: bossHp,
      bossTitle: bossTitle,
      colorIndex: 0, // Neon Crimson / Pink
      kind: BlockKind.boss,
    ));
    blocks.add(Block(
      col: 5,
      row: 2,
      hp: bossHp,
      bossMaxHp: bossHp,
      bossTitle: bossTitle,
      colorIndex: 0,
      kind: BlockKind.boss,
    ));
    blocks.add(Block(
      col: 6,
      row: 2,
      hp: bossHp,
      bossMaxHp: bossHp,
      bossTitle: bossTitle,
      colorIndex: 0,
      kind: BlockKind.boss,
    ));
    blocks.add(Block(
      col: 4,
      row: 3,
      hp: bossHp,
      bossMaxHp: bossHp,
      bossTitle: bossTitle,
      colorIndex: 0,
      kind: BlockKind.boss,
    ));
    blocks.add(Block(
      col: 5,
      row: 3,
      hp: bossHp,
      bossMaxHp: bossHp,
      bossTitle: bossTitle,
      colorIndex: 0,
      kind: BlockKind.boss,
    ));
    blocks.add(Block(
      col: 6,
      row: 3,
      hp: bossHp,
      bossMaxHp: bossHp,
      bossTitle: bossTitle,
      colorIndex: 0,
      kind: BlockKind.boss,
    ));

    // Shield minions around the boss
    for (int c = 2; c <= 8; c++) {
      if (c < 4 || c > 6) {
        blocks.add(Block(col: c, row: 2, hp: 6 + bossIndex * 2, colorIndex: 4));
        blocks.add(Block(col: c, row: 3, hp: 6 + bossIndex * 2, colorIndex: 4));
      }
    }
    // Front barrier row
    for (int c = 3; c <= 7; c++) {
      blocks.add(Block(col: c, row: 4, hp: 4 + bossIndex * 2, colorIndex: 1));
    }

    // Strategic orbs
    orbs.add(Orb(col: 2, row: 1, kind: OrbKind.horizontal));
    orbs.add(Orb(col: 8, row: 1, kind: OrbKind.horizontal));
    orbs.add(Orb(col: 5, row: 1, kind: OrbKind.plusOne));
    orbs.add(Orb(col: 5, row: 5, kind: OrbKind.vertical));

    return LevelDefinition(
      level: 1000 + bossIndex,
      balls: 35 + (bossIndex * 5),
      blocks: blocks,
      orbs: orbs,
    );
  }

  /// Distinct Mode 2: Speed Rush Frenzy (60s Score Attack)
  /// Constantly refreshing high-density block field designed for quick, fast combos.
  static LevelDefinition getSpeedRushLevel(int seed) {
    final rng = math.Random(seed * 31337);
    final blocks = <Block>[];
    final orbs = <Orb>[];

    for (int r = 1; r <= 5; r++) {
      for (int c = 0; c < 11; c++) {
        final roll = rng.nextDouble();
        if (roll < 0.45) {
          final hp = 1 + rng.nextInt(5);
          final colorIdx = rng.nextInt(6);
          blocks.add(Block(col: c, row: r, hp: hp, colorIndex: colorIdx));
        } else if (roll < 0.55 && orbs.length < 5) {
          orbs.add(Orb(
            col: c,
            row: r,
            kind: rng.nextBool() ? OrbKind.horizontal : OrbKind.plusOne,
          ));
        }
      }
    }

    return LevelDefinition(
      level: 2000 + seed,
      balls: 40,
      blocks: blocks,
      orbs: orbs,
    );
  }

  static LevelDefinition _buildLevel1() {
    final blocks = <Block>[
      // Row 1 (yellow hp 2)
      for (int c = 2; c <= 9; c++)
        Block(col: c, row: 1, hp: 2, colorIndex: 2), // yellow
      
      // Row 2 (pink hp 3)
      Block(col: 1, row: 2, hp: 3, colorIndex: 0), // pink
      Block(col: 9, row: 2, hp: 3, colorIndex: 0),

      // Row 3 (purple hp 3)
      Block(col: 1, row: 3, hp: 3, colorIndex: 4), // purple
      Block(col: 9, row: 3, hp: 3, colorIndex: 4),

      // Row 4 (orange hp 2)
      Block(col: 1, row: 4, hp: 2, colorIndex: 1), // orange
      for (int c = 3; c <= 7; c++)
        Block(col: c, row: 4, hp: 2, colorIndex: 1),
      Block(col: 9, row: 4, hp: 2, colorIndex: 1),
    ];

    final orbs = <Orb>[
      Orb(col: 1, row: 1, kind: OrbKind.horizontal),
      Orb(col: 5, row: 2, kind: OrbKind.plusOne),
      Orb(col: 7, row: 3, kind: OrbKind.vertical),
    ];

    return LevelDefinition(level: 1, balls: 30, blocks: blocks, orbs: orbs);
  }

  static LevelDefinition _buildLevel3() {
    final blocks = <Block>[
      // Row 1
      Block(col: 0, row: 1, hp: 6, colorIndex: 2), // yellow
      Block(col: 4, row: 1, hp: 5, colorIndex: 2),
      Block(col: 5, row: 1, hp: 6, colorIndex: 2),
      Block(col: 6, row: 1, hp: 5, colorIndex: 2),

      // Row 2
      Block(col: 7, row: 2, hp: 1, colorIndex: 3), // green

      // Row 3
      Block(col: 5, row: 3, hp: 4, colorIndex: 0, kind: BlockKind.triBR), // pink triangle
      Block(col: 8, row: 3, hp: 6, colorIndex: 4), // purple

      // Row 6
      Block(col: 1, row: 6, hp: 1, colorIndex: 3),

      // Row 7
      Block(col: 0, row: 7, hp: 6, colorIndex: 3),
      Block(col: 4, row: 7, hp: 5, colorIndex: 2),
      Block(col: 5, row: 7, hp: 6, colorIndex: 3),
      Block(col: 6, row: 7, hp: 6, colorIndex: 3),
    ];

    final orbs = <Orb>[
      Orb(col: 7, row: 3, kind: OrbKind.vertical),
      Orb(col: 5, row: 6, kind: OrbKind.horizontal),
    ];

    return LevelDefinition(level: 3, balls: 30, blocks: blocks, orbs: orbs);
  }

  static LevelDefinition _generateLevel(int levelId) {
    final rng = math.Random(levelId * 7919);
    final blocks = <Block>[];
    final orbs = <Orb>[];

    final baseHp = math.min(35, 2 + (levelId * 0.4).round());
    final occupied = <String>{};

    final rowsCount = (3 + (levelId % 4)).clamp(3, 7);
    final balls = math.min(60, 25 + levelId);

    for (int r = 1; r <= rowsCount; r++) {
      for (int c = 0; c < 11; c++) {
        final key = '$c,$r';
        if (occupied.contains(key)) continue;

        final roll = rng.nextDouble();
        if (roll < 0.32) {
          occupied.add(key);
          final hp = (baseHp + rng.nextInt(math.max(1, (baseHp * 0.5).round()))).clamp(1, 40);
          final colorIdx = rng.nextInt(6);

          final isTri = levelId >= 2 && rng.nextDouble() < 0.15;
          final kind = isTri
              ? [BlockKind.triBL, BlockKind.triBR, BlockKind.triTL, BlockKind.triTR][rng.nextInt(4)]
              : BlockKind.square;

          blocks.add(Block(col: c, row: r, hp: hp, colorIndex: colorIdx, kind: kind));
        } else if (roll < 0.40 && orbs.length < 4) {
          occupied.add(key);
          final orbRoll = rng.nextDouble();
          final kind = orbRoll < 0.35
              ? OrbKind.plusOne
              : (orbRoll < 0.68 ? OrbKind.horizontal : OrbKind.vertical);
          orbs.add(Orb(col: c, row: r, kind: kind));
        }
      }
    }

    // Ensure at least 6 blocks exist
    if (blocks.length < 6) {
      for (int c = 2; c <= 8; c++) {
        final key = '$c,2';
        if (!occupied.contains(key)) {
          blocks.add(Block(col: c, row: 2, hp: baseHp, colorIndex: c % 6));
        }
      }
    }

    return LevelDefinition(level: levelId, balls: balls, blocks: blocks, orbs: orbs);
  }
}
