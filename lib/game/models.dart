import 'dart:ui';

enum BlockKind { square, triBL, triBR, triTL, triTR }
enum OrbKind { horizontal, vertical, plusOne }

class Block {
  Block({
    required this.col,
    required this.row,
    required this.hp,
    required this.colorIndex,
    this.kind = BlockKind.square,
    this.isStone = false,
  }) : maxHp = hp;

  int col;
  int row;
  int hp;
  final int maxHp;
  final int colorIndex;
  final BlockKind kind;
  final bool isStone;

  double pulse = 0.0; // 1.0 down to 0.0 on hit
  double dying = 0.0; // 0.0 alive, >0.0 exploding/shrinking

  bool get alive => hp > 0;
}

class Orb {
  Orb({
    required this.col,
    required this.row,
    required this.kind,
  });

  int col;
  int row;
  final OrbKind kind;
  bool consumed = false;
  double pulse = 0.0;
}

class Ball {
  Ball({
    required this.pos,
    required this.vel,
  });

  Offset pos;
  Offset vel;
  bool landed = false;
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
