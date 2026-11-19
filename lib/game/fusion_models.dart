import 'dart:ui';

/// Symbols for Colorblind Mode (Section 2.2)
/// 0: Pink -> Heart
/// 1: Orange -> Triangle
/// 2: Yellow -> Star
/// 3: Green -> Square
/// 4: Purple -> Diamond
/// 5: Cyan -> Circle
enum ColorblindSymbol { heart, triangle, star, square, diamond, circle }

enum BurstType { none, area3x3, lineCross, colorWipe }

/// Obstacle and item types for level variety (Section 3.4 & User Request 2)
enum ObstacleType {
  none,
  ice, // Cracks when adjacent pop occurs, takes 1-2 hits
  stone, // Stronger, requires 2 hits or Super/Mega burst
  ingredient, // Special item (Star/Gem) that must be brought to the bottom row (row 8)
}

/// Goal types for diverse level requirements
enum GoalType {
  popTotal, // Pop N total blocks
  popColor, // Pop N blocks of specific color
  createPower, // Create N Power blocks (x2)
  reachScore, // Reach N points
  clearObstacles, // Clear N ice/stone obstacles
  dropToBottom, // Bring N ingredient stars to the bottom row
}

/// Dynamic Level Goal Tracking
class LevelGoal {
  final GoalType type;
  final int target;
  int current;
  final int? targetColorIndex; // For popColor
  final String title;
  final String description;

  LevelGoal({
    required this.type,
    required this.target,
    this.current = 0,
    this.targetColorIndex,
    required this.title,
    required this.description,
  });

  static const List<String> colorNames = [
    'PINK',
    'ORANGE',
    'YELLOW',
    'GREEN',
    'PURPLE',
    'CYAN',
  ];

  String get dynamicTitle {
    if (type == GoalType.popColor && targetColorIndex != null) {
      final name = colorNames[targetColorIndex! % colorNames.length];
      return 'POP $name';
    }
    return title;
  }

  bool get isMet => current >= target;

  double get progress => target > 0 ? (current / target).clamp(0.0, 1.0) : 1.0;

  LevelGoal clone() => LevelGoal(
        type: type,
        target: target,
        current: current,
        targetColorIndex: targetColorIndex,
        title: title,
        description: description,
      );
}

/// Move simulation result for preview and core execution (Section 2.4 & 3.6)
class MoveSimulationResult {
  final bool isValid;
  final bool isMerge;
  final ({int col, int row}) from;
  final ({int col, int row}) to;
  final int resultingLevel;
  final BurstType burstType;
  final Set<({int col, int row})> popCells;
  final String? invalidReason;

  const MoveSimulationResult({
    required this.isValid,
    required this.isMerge,
    required this.from,
    required this.to,
    this.resultingLevel = 1,
    this.burstType = BurstType.none,
    this.popCells = const {},
    this.invalidReason,
  });

  static const invalid = MoveSimulationResult(
    isValid: false,
    isMerge: false,
    from: (col: -1, row: -1),
    to: (col: -1, row: -1),
  );
}

/// Merge rules configuration per level (Section 3.1)
class MergeRules {
  final int maxMergeDistance; // default 2 Manhattan distance
  final bool requireStraightLine; // default false
  final bool requireClearPath; // default false
  final int maxDragDistance; // 0 = unlimited for empty cells

  const MergeRules({
    this.maxMergeDistance = 2,
    this.requireStraightLine = false,
    this.requireClearPath = false,
    this.maxDragDistance = 0,
  });
}

enum FusionBlockState {
  idle,
  selected, // finger resting on block
  dragging, // block is being dragged
  fusing, // mid-merge animation
  popping, // exploding away
  dropping, // falling down from above
}

class FusionBlock {
  FusionBlock({
    required this.col,
    required this.row,
    required this.colorIndex,
    this.fusionLevel = 1, // 1=Normal, 2=Power (x2), 3=Super (3x3), 4=Mega (Wipe)
    this.id = 0,
    this.burstType = BurstType.none,
    this.obstacle = ObstacleType.none,
    this.obstacleHp = 1,
  });

  int col;
  int row;
  final int colorIndex;
  int fusionLevel;
  final int id;
  BurstType burstType;
  ObstacleType obstacle;
  int obstacleHp;

  // Animation state
  FusionBlockState state = FusionBlockState.idle;

  // Visual animation progress (0.0 .. 1.0)
  double dropProgress = 1.0;
  double popProgress = 0.0;
  double fuseProgress = 0.0;
  double pulseProgress = 0.0;
  double popDelay = 0.0;

  // Screen-space drag coordinate
  Offset? dragPos;

  bool get isAlive => state != FusionBlockState.popping || popProgress < 1.0;
  bool get isPower => fusionLevel == 2 && obstacle == ObstacleType.none;
  bool get isSuper => fusionLevel == 3 && obstacle == ObstacleType.none;
  bool get isMega => fusionLevel >= 4 && obstacle == ObstacleType.none;
  bool get isObstacle => obstacle == ObstacleType.ice || obstacle == ObstacleType.stone;
  bool get isIngredient => obstacle == ObstacleType.ingredient;

  ColorblindSymbol get symbol => ColorblindSymbol.values[colorIndex % ColorblindSymbol.values.length];

  FusionBlock clone() {
    final b = FusionBlock(
      col: col,
      row: row,
      colorIndex: colorIndex,
      fusionLevel: fusionLevel,
      id: id,
      burstType: burstType,
      obstacle: obstacle,
      obstacleHp: obstacleHp,
    );
    b.state = state;
    b.dropProgress = dropProgress;
    b.popProgress = popProgress;
    b.fuseProgress = fuseProgress;
    b.pulseProgress = pulseProgress;
    return b;
  }
}

class FusionParticle {
  FusionParticle({
    required this.pos,
    required this.vel,
    required this.color,
    required this.life,
    this.size = 5.0,
    this.isGem = false,
    this.symbol,
  }) : maxLife = life;

  Offset pos;
  Offset vel;
  final Color color;
  double life;
  final double maxLife;
  final double size;
  final bool isGem;
  final ColorblindSymbol? symbol;
}

class FusionScoreFloat {
  FusionScoreFloat({
    required this.pos,
    required this.text,
    required this.color,
    this.life = 1.4,
  }) : maxLife = life;

  Offset pos;
  final String text;
  final Color color;
  double life;
  final double maxLife;
}

enum FusionPhase {
  idle,
  dragging,
  animating,
  dropping,
  shuffling, // dead-board reshuffle animation
  won,
  lost,
}
