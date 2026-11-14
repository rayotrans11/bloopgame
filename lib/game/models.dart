import 'dart:ui';

enum BlockKind { square, triBL, triBR, triTL, triTR, boss, drone }
enum OrbKind { horizontal, vertical, plusOne, portalBlue, portalOrange, rainbow, bomb, freeze }
enum GameMode { classic, bossRush, speedRush }

/// Color pallet indices for marble / bubble orbs:
/// 0: Pink/Magenta (0xFFFF2D8D)
/// 1: Electric Orange (0xFFFF6D00)
/// 2: Radiant Yellow (0xFFFFD600)
/// 3: Neon Green (0xFF00E676)
/// 4: Vivid Purple (0xFF7C4DFF)
/// 5: Cyan Blue (0xFF00E5FF)
/// 6: Rainbow Wildcard (-1 / wildcard)
/// 7: Bomb (-2)
class CannonColor {
  static const int pink = 0;
  static const int orange = 1;
  static const int yellow = 2;
  static const int green = 3;
  static const int purple = 4;
  static const int cyan = 5;
  static const int wildcard = 6;
  static const int bomb = 7;
  static const int freeze = 8;
  static const int count = 6; // basic match colors
}

/// A descending target orb in the real-time siege field
class TargetOrb {
  TargetOrb({
    required this.col,
    required this.row,
    required this.colorIndex,
    this.hp = 1,
    this.isBoss = false,
    this.bossMaxHp,
    this.bossTitle,
  }) : maxHp = hp;

  int col;
  double row; // continuous real-time descent
  int colorIndex; // 0..5 or special
  int hp;
  final int maxHp;
  final bool isBoss;
  final int? bossMaxHp;
  final String? bossTitle;

  double pulse = 0.0;
  double dying = 0.0;
  bool isFalling = false; // When disconnected from cluster ceiling
  Offset fallVel = Offset.zero;

  bool get alive => hp > 0;
}

/// A projectile marble shot from the Cannon
class ProjectileOrb {
  ProjectileOrb({
    required this.pos,
    required this.vel,
    required this.colorIndex,
  });

  Offset pos;
  Offset vel;
  final int colorIndex;
  final List<Offset> trail = [];
  bool active = true;
}

/// Legacy Block class maintained for full backwards compatibility
class Block {
  Block({
    required this.col,
    required this.row,
    required this.hp,
    required this.colorIndex,
    this.kind = BlockKind.square,
    this.isStone = false,
    this.bossMaxHp,
    this.bossTitle,
  }) : maxHp = hp;

  int col;
  int row;
  int hp;
  final int maxHp;
  final int colorIndex;
  final BlockKind kind;
  final bool isStone;
  final int? bossMaxHp;
  final String? bossTitle;

  bool get isBoss => kind == BlockKind.boss;
  bool get isDrone => kind == BlockKind.drone;

  double pulse = 0.0;
  double dying = 0.0;

  bool get alive => hp > 0;
}

class Orb {
  Orb({
    required this.col,
    required this.row,
    required this.kind,
    this.portalTargetCol,
    this.portalTargetRow,
  });

  int col;
  int row;
  final OrbKind kind;
  int? portalTargetCol;
  int? portalTargetRow;
  bool consumed = false;
  double pulse = 0.0;

  bool get isPortal => kind == OrbKind.portalBlue || kind == OrbKind.portalOrange;
}

class Ball {
  Ball({
    required this.pos,
    required this.vel,
  });

  Offset pos;
  Offset vel;
  bool landed = false;
  final List<Offset> trail = [];
  double portalCooldown = 0.0;
}

class Particle {
  Particle({
    required this.pos,
    required this.vel,
    required this.life,
    required this.color,
    this.isStreak = false,
    this.size = 6.0,
  }) : maxLife = life;

  Offset pos;
  Offset vel;
  double life;
  final double maxLife;
  final Color color;
  final bool isStreak;
  final double size;
}

class Bolt {
  Bolt({
    required this.a,
    required this.b,
    this.isVertical = false,
    this.life = 0.35,
  }) : maxLife = life;

  final Offset a;
  final Offset b;
  final bool isVertical;
  double life;
  final double maxLife;
}
