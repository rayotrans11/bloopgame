import 'dart:ui';

/// Color indices for the 6 block colors
/// 0=Pink, 1=Orange, 2=Yellow, 3=Green, 4=Purple, 5=Cyan

enum FusionBlockState {
  idle,
  selected,  // finger is resting on this block
  dragging,  // block is being dragged
  fusing,    // mid-merge animation
  popping,   // exploding away
  dropping,  // falling down from new row
}

class FusionBlock {
  FusionBlock({
    required this.col,
    required this.row,
    required this.colorIndex,
    this.fusionLevel = 1,  // 1=normal, 2=Power (×2), 3=Super (×3 chain blast)
    this.id = 0,
  });

  int col;
  int row;
  final int colorIndex;
  int fusionLevel;
  final int id;

  // Animation state
  FusionBlockState state = FusionBlockState.idle;

  // Visual animation params (all 0..1 progress values)
  double dropProgress = 0.0;    // 0 = at top, 1 = landed in cell
  double popProgress = 0.0;     // 0 = alive, 1 = fully popped
  double fuseProgress = 0.0;    // 0 = not fusing, 1 = done
  double pulseProgress = 0.0;   // hit flash / highlight pulse
  double selectedScale = 1.0;   // 1.0 → 1.12 when selected

  // During drag: exact canvas position for the floating block
  Offset? dragPos;

  // For chain-pop animations: delay offset
  double popDelay = 0.0;

  bool get isAlive => state != FusionBlockState.popping || popProgress < 1.0;
  bool get isPower => fusionLevel >= 2;
  bool get isSuper => fusionLevel >= 3;
}

class FusionParticle {
  FusionParticle({
    required this.pos,
    required this.vel,
    required this.color,
    required this.life,
    this.size = 5.0,
    this.isGem = false,
  }) : maxLife = life;

  Offset pos;
  Offset vel;
  final Color color;
  double life;
  final double maxLife;
  final double size;
  final bool isGem;
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
  idle,         // waiting for player input
  dragging,     // player is dragging a block
  animating,    // fuse/pop animation in progress
  dropping,     // new blocks falling in
  won,
  lost,
}
