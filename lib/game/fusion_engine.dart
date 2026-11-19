import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/deterministic_rng.dart';
import '../core/theme.dart';
import 'fusion_models.dart';

/// Grid layout constants for the Fusion board
class FusionLayout {
  FusionLayout(Size size, {double safeTop = 0, double safeBottom = 0})
      : w = size.width,
        h = size.height {
    // Top HUD area
    hudH = safeTop + 120.0;
    // Bottom toolbar area
    bottomH = safeBottom + 105.0;

    boardTop = hudH;
    boardBottom = h - bottomH;
    boardH = boardBottom - boardTop;
    boardW = w;

    cellW = boardW / cols;
    cellH = boardH / rows;
    blockInset = cellW * 0.06;
  }

  static const int cols = 7;
  static const int rows = 9;

  final double w, h;
  late final double hudH, bottomH, boardTop, boardBottom, boardH, boardW;
  late final double cellW, cellH, blockInset;

  Rect cellRect(int col, int row) => Rect.fromLTWH(
        col * cellW,
        boardTop + row * cellH,
        cellW,
        cellH,
      );

  Rect blockRect(int col, int row) => cellRect(col, row).deflate(blockInset);

  Offset cellCenter(int col, int row) => cellRect(col, row).center;

  ({int col, int row})? hitTest(Offset pos) {
    final col = (pos.dx / cellW).floor();
    final row = ((pos.dy - boardTop) / cellH).floor();
    if (col < 0 || col >= cols || row < 0 || row >= rows) return null;
    return (col: col, row: row);
  }
}

/// The enhanced Fusion Engine following Section 3 Core Mechanic Specification
/// Supports multiple goal types, obstacle blocks, and ingredient items.
class FusionEngine extends ChangeNotifier {
  FusionEngine({
    required this.layout,
    required this.levelId,
    required this.maxMoves,
    required this.goal,
    this.mergeRules = const MergeRules(),
    this.fixedSeed,
    this.isTutorial = false,
    this.tutorialBoard,
    this.initialObstacles,
    this.initialIngredients,
  }) {
    _rng = fixedSeed != null ? DeterministicRng(fixedSeed!) : DeterministicRng(levelId * 7919 + DateTime.now().millisecond);
    _init();
  }

  FusionLayout layout;
  final int levelId;
  final int maxMoves;
  final LevelGoal goal;
  final MergeRules mergeRules;
  final int? fixedSeed;
  final bool isTutorial;
  final List<List<int>>? tutorialBoard;
  final List<List<ObstacleType>>? initialObstacles;
  final List<({int col, int row})>? initialIngredients;

  late final DeterministicRng _rng;
  FusionPhase phase = FusionPhase.idle;

  // Grid storage: grid[col][row]
  late List<List<FusionBlock?>> grid;

  // Drag interaction
  FusionBlock? dragBlock;
  Offset? dragPos;
  ({int col, int row})? dragTarget;
  MoveSimulationResult? currentSimulation;

  // Legal merge targets for currently dragged block
  final Set<({int col, int row})> legalMergeTargets = {};

  // Animations
  final List<FusionParticle> particles = [];
  final List<FusionScoreFloat> scoreFloats = [];
  final List<FusionBlock> _poppingBlocks = [];
  List<FusionBlock> get poppingBlocksForPaint => _poppingBlocks;

  int poppedCount = 0; // Legacy & total pop tracker
  int get targetPops => goal.target;
  int movesLeft = 0;
  int score = 0;
  double cascadeMultiplier = 1.0;
  int _nextId = 1;

  int get _id => _nextId++;
  int get _colorCount {
    if (goal.type == GoalType.popColor && goal.targetColorIndex != null) {
      return math.max((3 + (levelId ~/ 4)).clamp(3, 6), goal.targetColorIndex! + 1);
    }
    return (3 + (levelId ~/ 4)).clamp(3, 6);
  }

  void _init() {
    movesLeft = maxMoves;
    grid = List.generate(
      FusionLayout.cols,
      (_) => List.filled(FusionLayout.rows, null, growable: false),
    );

    if (isTutorial && tutorialBoard != null) {
      _fillTutorialGrid(tutorialBoard!);
    } else {
      _fillInitialGrid();
    }

    _applyObstaclesAndIngredients();
  }

  void _applyObstaclesAndIngredients() {
    // Inject obstacle blocks if configured
    if (initialObstacles != null) {
      for (int c = 0; c < FusionLayout.cols; c++) {
        for (int r = 0; r < FusionLayout.rows; r++) {
          final obs = initialObstacles![c][r];
          if (obs != ObstacleType.none) {
            final existing = grid[c][r];
            final color = existing != null ? existing.colorIndex : _rng.nextInt(_colorCount);
            grid[c][r] = FusionBlock(
              col: c,
              row: r,
              colorIndex: color,
              id: _id,
              obstacle: obs,
              obstacleHp: obs == ObstacleType.stone ? 2 : 1,
            );
          }
        }
      }
    }

    // Inject ingredient stars if configured
    if (initialIngredients != null) {
      for (final ing in initialIngredients!) {
        if (ing.col >= 0 && ing.col < FusionLayout.cols && ing.row >= 0 && ing.row < FusionLayout.rows) {
          grid[ing.col][ing.row] = FusionBlock(
            col: ing.col,
            row: ing.row,
            colorIndex: 0,
            id: _id,
            obstacle: ObstacleType.ingredient,
          );
        }
      }
    }
  }

  void _fillTutorialGrid(List<List<int>> tBoard) {
    for (int col = 0; col < FusionLayout.cols; col++) {
      for (int row = 0; row < FusionLayout.rows; row++) {
        final cIdx = tBoard[col][row];
        if (cIdx >= 0) {
          final b = FusionBlock(col: col, row: row, colorIndex: cIdx, id: _id);
          b.state = FusionBlockState.idle;
          b.dropProgress = 1.0;
          grid[col][row] = b;
        }
      }
    }
  }

  void _fillInitialGrid() {
    for (int row = 0; row < FusionLayout.rows; row++) {
      for (int col = 0; col < FusionLayout.cols; col++) {
        grid[col][row] = _newBlock(col, row, dropping: false);
      }
    }
    _breakInitialMatches();
  }

  FusionBlock _newBlock(int col, int row, {bool dropping = true}) {
    final colorIndex = _rng.nextInt(_colorCount);
    final block = FusionBlock(
      col: col,
      row: row,
      colorIndex: colorIndex,
      id: _id,
    );
    if (dropping) {
      block.state = FusionBlockState.dropping;
      block.dropProgress = 0.0;
    } else {
      block.state = FusionBlockState.idle;
      block.dropProgress = 1.0;
    }
    return block;
  }

  void _breakInitialMatches() {
    for (int row = 0; row < FusionLayout.rows; row++) {
      for (int col = 0; col < FusionLayout.cols; col++) {
        final b = grid[col][row];
        if (b == null) continue;

        int attempts = 0;
        while (_has3MatchAt(col, row) && attempts < 12) {
          final newColor = _rng.nextInt(_colorCount);
          grid[col][row] = FusionBlock(
            col: col,
            row: row,
            colorIndex: newColor,
            id: _id,
          );
          attempts++;
        }
      }
    }
  }

  bool _has3MatchAt(int col, int row) {
    final b = grid[col][row];
    if (b == null || b.isObstacle || b.isIngredient) return false;
    final c = b.colorIndex;

    // Check left run
    if (col >= 2) {
      if (grid[col - 1][row]?.colorIndex == c &&
          grid[col - 2][row]?.colorIndex == c &&
          !grid[col - 1][row]!.isObstacle &&
          !grid[col - 2][row]!.isObstacle) {
        return true;
      }
    }
    // Check up run
    if (row >= 2) {
      if (grid[col][row - 1]?.colorIndex == c &&
          grid[col][row - 2]?.colorIndex == c &&
          !grid[col][row - 1]!.isObstacle &&
          !grid[col][row - 2]!.isObstacle) {
        return true;
      }
    }
    return false;
  }

  // ─── PURE SIMULATION FUNCTION (Section 2.4 & 3.6) ──────────────────────────
  static MoveSimulationResult simulateMove({
    required List<List<FusionBlock?>> boardState,
    required ({int col, int row}) from,
    required ({int col, int row}) to,
    required MergeRules rules,
  }) {
    if (from.col == to.col && from.row == to.row) return MoveSimulationResult.invalid;
    if (from.col < 0 || from.col >= FusionLayout.cols || from.row < 0 || from.row >= FusionLayout.rows) {
      return MoveSimulationResult.invalid;
    }
    if (to.col < 0 || to.col >= FusionLayout.cols || to.row < 0 || to.row >= FusionLayout.rows) {
      return MoveSimulationResult.invalid;
    }

    final fromBlock = boardState[from.col][from.row];
    if (fromBlock == null || !fromBlock.isAlive) return MoveSimulationResult.invalid;

    // Obstacles and ingredients cannot be picked up and dragged
    if (fromBlock.isObstacle || fromBlock.isIngredient) return MoveSimulationResult.invalid;

    final targetBlock = boardState[to.col][to.row];
    final manhattan = (from.col - to.col).abs() + (from.row - to.row).abs();

    // 1. Moving to an EMPTY CELL
    if (targetBlock == null) {
      if (rules.maxDragDistance > 0 && manhattan > rules.maxDragDistance) {
        return const MoveSimulationResult(
          isValid: false,
          isMerge: false,
          from: (col: -1, row: -1),
          to: (col: -1, row: -1),
          invalidReason: 'Too far',
        );
      }
      return MoveSimulationResult(
        isValid: true,
        isMerge: false,
        from: from,
        to: to,
        resultingLevel: fromBlock.fusionLevel,
        burstType: BurstType.none,
        popCells: const {},
      );
    }

    // Target cannot be an ingredient or locked obstacle
    if (targetBlock.isIngredient) {
      return const MoveSimulationResult(
        isValid: false,
        isMerge: false,
        from: (col: -1, row: -1),
        to: (col: -1, row: -1),
        invalidReason: 'Cannot merge with star',
      );
    }

    // 2. MERGING with target block: MUST BE SAME COLOR
    if (targetBlock.colorIndex != fromBlock.colorIndex) {
      return const MoveSimulationResult(
        isValid: false,
        isMerge: false,
        from: (col: -1, row: -1),
        to: (col: -1, row: -1),
        invalidReason: 'Colors mismatch',
      );
    }

    // Check merge distance rules
    if (rules.maxMergeDistance > 0 && manhattan > rules.maxMergeDistance) {
      final isStraight = from.col == to.col || from.row == to.row;
      if (!rules.requireStraightLine || !isStraight) {
        return const MoveSimulationResult(
          isValid: false,
          isMerge: false,
          from: (col: -1, row: -1),
          to: (col: -1, row: -1),
          invalidReason: 'Merge distance exceeded',
        );
      }
    }

    // Check clear path if required
    if (rules.requireClearPath) {
      if (!isPathClear(boardState, from, to)) {
        return const MoveSimulationResult(
          isValid: false,
          isMerge: false,
          from: (col: -1, row: -1),
          to: (col: -1, row: -1),
          invalidReason: 'Path blocked',
        );
      }
    }

    // Calculate Resulting Level:
    // Lv1 + Lv1 -> Lv2 (x2)
    // Lv2 + Lv2 -> Lv3 (Super, 3x3 burst)
    // Lv3 + Lv3 -> Lv4 (Mega, Board wipe)
    int resultingLevel;
    if (fromBlock.fusionLevel == targetBlock.fusionLevel) {
      resultingLevel = (fromBlock.fusionLevel + 1).clamp(1, 4);
    } else {
      resultingLevel = math.max(fromBlock.fusionLevel, targetBlock.fusionLevel);
    }

    // Burst Type Evaluation
    BurstType burstType = BurstType.none;
    if (resultingLevel == 3) {
      final isStraight = from.col == to.col || from.row == to.row;
      burstType = isStraight ? BurstType.lineCross : BurstType.area3x3;
    } else if (resultingLevel >= 4) {
      burstType = BurstType.colorWipe;
    }

    // Predict Cells That Would Pop (Group >= 3 or Burst)
    final popCells = <({int col, int row})>{};

    if (burstType == BurstType.area3x3) {
      for (int c = to.col - 1; c <= to.col + 1; c++) {
        for (int r = to.row - 1; r <= to.row + 1; r++) {
          if (c >= 0 && c < FusionLayout.cols && r >= 0 && r < FusionLayout.rows) {
            popCells.add((col: c, row: r));
          }
        }
      }
    } else if (burstType == BurstType.lineCross) {
      for (int c = 0; c < FusionLayout.cols; c++) {
        popCells.add((col: c, row: to.row));
      }
      for (int r = 0; r < FusionLayout.rows; r++) {
        popCells.add((col: to.col, row: r));
      }
    } else if (burstType == BurstType.colorWipe) {
      final wipeColor = fromBlock.colorIndex;
      for (int c = 0; c < FusionLayout.cols; c++) {
        for (int r = 0; r < FusionLayout.rows; r++) {
          if (boardState[c][r]?.colorIndex == wipeColor || (c == to.col && r == to.row)) {
            popCells.add((col: c, row: r));
          }
        }
      }
    } else {
      // Normal Flood-Fill check
      final visited = <String>{};
      final group = <({int col, int row})>[];

      void flood(int c, int r) {
        final key = '$c,$r';
        if (visited.contains(key)) return;
        if (c < 0 || c >= FusionLayout.cols || r < 0 || r >= FusionLayout.rows) return;
        visited.add(key);

        final cellBlock = (c == to.col && r == to.row)
            ? fromBlock
            : ((c == from.col && r == from.row) ? null : boardState[c][r]);

        if (cellBlock != null && cellBlock.colorIndex == fromBlock.colorIndex && !cellBlock.isObstacle && !cellBlock.isIngredient) {
          group.add((col: c, row: r));
          flood(c - 1, r);
          flood(c + 1, r);
          flood(c, r - 1);
          flood(c, r + 1);
        }
      }

      flood(to.col, to.row);
      if (group.length >= 3) {
        popCells.addAll(group);
      }
    }

    return MoveSimulationResult(
      isValid: true,
      isMerge: true,
      from: from,
      to: to,
      resultingLevel: resultingLevel,
      burstType: burstType,
      popCells: popCells,
    );
  }

  static bool isPathClear(List<List<FusionBlock?>> board, ({int col, int row}) from, ({int col, int row}) to) {
    if (from.col != to.col && from.row != to.row) return false;
    if (from.col == to.col) {
      final start = math.min(from.row, to.row) + 1;
      final end = math.max(from.row, to.row);
      for (int r = start; r < end; r++) {
        if (board[from.col][r] != null) return false;
      }
    } else {
      final start = math.min(from.col, to.col) + 1;
      final end = math.max(from.col, to.col);
      for (int c = start; c < end; c++) {
        if (board[c][from.row] != null) return false;
      }
    }
    return true;
  }

  // ─── USER INTERACTION ─────────────────────────────────────────────────────

  void onDragStart(Offset pos) {
    if (phase != FusionPhase.idle) return;
    final hit = layout.hitTest(pos);
    if (hit == null) return;
    final block = grid[hit.col][hit.row];
    if (block == null || block.state != FusionBlockState.idle) return;
    if (block.isObstacle || block.isIngredient) return; // Cannot drag obstacles or stars directly

    dragBlock = block;
    dragPos = pos;
    dragTarget = null;
    currentSimulation = null;
    block.state = FusionBlockState.dragging;
    phase = FusionPhase.dragging;

    legalMergeTargets.clear();
    for (int c = 0; c < FusionLayout.cols; c++) {
      for (int r = 0; r < FusionLayout.rows; r++) {
        final sim = simulateMove(
          boardState: grid,
          from: (col: block.col, row: block.row),
          to: (col: c, row: r),
          rules: mergeRules,
        );
        if (sim.isValid && sim.isMerge) {
          legalMergeTargets.add((col: c, row: r));
        }
      }
    }

    notifyListeners();
  }

  void onDragUpdate(Offset pos) {
    if (phase != FusionPhase.dragging || dragBlock == null) return;
    dragPos = pos;

    final hit = layout.hitTest(pos);
    if (hit != null && (hit.col != dragBlock!.col || hit.row != dragBlock!.row)) {
      if (dragTarget == null || dragTarget!.col != hit.col || dragTarget!.row != hit.row) {
        dragTarget = hit;
        currentSimulation = simulateMove(
          boardState: grid,
          from: (col: dragBlock!.col, row: dragBlock!.row),
          to: hit,
          rules: mergeRules,
        );
      }
    } else {
      dragTarget = null;
      currentSimulation = null;
    }
    notifyListeners();
  }

  void onDragEnd(Offset pos) {
    if (phase != FusionPhase.dragging || dragBlock == null) return;

    final hit = layout.hitTest(pos);
    final db = dragBlock!;
    final fromPos = (col: db.col, row: db.row);

    db.state = FusionBlockState.idle;
    db.dragPos = null;
    dragBlock = null;
    dragPos = null;
    dragTarget = null;
    legalMergeTargets.clear();

    if (hit == null || (hit.col == fromPos.col && hit.row == fromPos.row)) {
      currentSimulation = null;
      phase = FusionPhase.idle;
      notifyListeners();
      return;
    }

    final sim = simulateMove(
      boardState: grid,
      from: fromPos,
      to: hit,
      rules: mergeRules,
    );
    currentSimulation = null;

    if (!sim.isValid) {
      phase = FusionPhase.idle;
      notifyListeners();
      return;
    }

    // Consumes 1 move on legal action
    movesLeft--;

    if (!sim.isMerge) {
      // Reposition block to empty cell
      grid[fromPos.col][fromPos.row] = null;
      db.col = hit.col;
      db.row = hit.row;
      grid[hit.col][hit.row] = db;
      phase = FusionPhase.idle;
      _checkWinLoss();
      _checkDeadBoard();
      notifyListeners();
    } else {
      _executeMerge(db, grid[hit.col][hit.row]!, sim);
    }
  }

  void _executeMerge(FusionBlock dragged, FusionBlock target, MoveSimulationResult sim) {
    phase = FusionPhase.animating;
    cascadeMultiplier = 1.0;

    grid[dragged.col][dragged.row] = null;
    dragged.state = FusionBlockState.fusing;
    dragged.fuseProgress = 0.0;

    target.fusionLevel = sim.resultingLevel;
    target.burstType = sim.burstType;
    target.state = FusionBlockState.fusing;
    target.fuseProgress = 0.0;
    target.pulseProgress = 1.0;

    // Track Goal Type: createPower
    if (sim.resultingLevel >= 2) {
      _trackGoalProgress(GoalType.createPower, 1);
    }

    _pendingFuse = (
      dragged: dragged,
      target: target,
      sim: sim,
    );

    notifyListeners();
  }

  ({FusionBlock dragged, FusionBlock target, MoveSimulationResult sim})? _pendingFuse;

  void _onFuseComplete(FusionBlock target, MoveSimulationResult sim) {
    target.state = FusionBlockState.idle;
    target.fuseProgress = 1.0;
    _pendingFuse = null;

    if (sim.popCells.isNotEmpty) {
      _executePop(sim.popCells, center: layout.cellCenter(sim.to.col, sim.to.row));
    } else {
      phase = FusionPhase.idle;
      _checkWinLoss();
      _checkDeadBoard();
      notifyListeners();
    }
  }

  void _executePop(Set<({int col, int row})> cells, {required Offset center}) {
    phase = FusionPhase.animating;
    int popScoreSum = 0;
    int popCount = 0;
    final damagedObstacles = <({int col, int row})>{};

    var delayIdx = 0;
    for (final c in cells) {
      final block = grid[c.col][c.row];
      if (block != null && block.isAlive) {
        if (block.isObstacle) {
          // Obstacle directly hit by burst
          damagedObstacles.add(c);
          continue;
        }

        if (block.isIngredient) {
          // Ingredients don't pop, they fall
          continue;
        }

        block.state = FusionBlockState.popping;
        block.popDelay = delayIdx * 0.035;
        block.popProgress = 0.0;
        grid[c.col][c.row] = null;
        _poppingBlocks.add(block);

        popScoreSum += (10 * block.fusionLevel * cascadeMultiplier).round();
        popCount++;

        // Track Goal Types
        _trackGoalProgress(GoalType.popTotal, 1);
        if (goal.type == GoalType.popColor && goal.targetColorIndex == block.colorIndex) {
          _trackGoalProgress(GoalType.popColor, 1);
        }

        _spawnPopParticles(layout.cellCenter(block.col, block.row), block.colorIndex, block.symbol);
        delayIdx++;

        // Check 4 adjacent cells for obstacles to damage
        for (final offset in const [(-1, 0), (1, 0), (0, -1), (0, 1)]) {
          final ac = block.col + offset.$1;
          final ar = block.row + offset.$2;
          if (ac >= 0 && ac < FusionLayout.cols && ar >= 0 && ar < FusionLayout.rows) {
            final adj = grid[ac][ar];
            if (adj != null && adj.isObstacle) {
              damagedObstacles.add((col: ac, row: ar));
            }
          }
        }
      }
    }

    // Damage collected obstacles
    for (final obsPos in damagedObstacles) {
      final obsBlock = grid[obsPos.col][obsPos.row];
      if (obsBlock != null && obsBlock.isObstacle) {
        obsBlock.obstacleHp--;
        if (obsBlock.obstacleHp <= 0) {
          obsBlock.state = FusionBlockState.popping;
          obsBlock.popProgress = 0.0;
          grid[obsPos.col][obsPos.row] = null;
          _poppingBlocks.add(obsBlock);
          _spawnPopParticles(layout.cellCenter(obsBlock.col, obsBlock.row), obsBlock.colorIndex);
          _trackGoalProgress(GoalType.clearObstacles, 1);
        } else {
          obsBlock.pulseProgress = 1.0;
        }
      }
    }

    score += popScoreSum;
    poppedCount += popCount;
    _trackGoalProgress(GoalType.reachScore, popScoreSum, isAbsolute: false);
    cascadeMultiplier += 0.5;

    if (popScoreSum > 0) {
      scoreFloats.add(FusionScoreFloat(
        pos: center,
        text: '+$popScoreSum',
        color: const Color(0xFFFFD600),
      ));
    }

    _pendingDropAfterPop = true;
    notifyListeners();
  }

  void _trackGoalProgress(GoalType type, int delta, {bool isAbsolute = false}) {
    if (goal.type == type) {
      if (isAbsolute) {
        goal.current = delta;
      } else {
        goal.current += delta;
      }
    }
  }

  bool _pendingDropAfterPop = false;

  void _onPopComplete() {
    _applyGravity();
    _refillGrid();
    _pendingDropAfterPop = false;
    phase = FusionPhase.dropping;
    notifyListeners();
  }

  void _applyGravity() {
    for (int col = 0; col < FusionLayout.cols; col++) {
      final columnBlocks = <FusionBlock>[];
      for (int row = FusionLayout.rows - 1; row >= 0; row--) {
        final b = grid[col][row];
        if (b != null && b.isAlive) {
          columnBlocks.add(b);
          grid[col][row] = null;
        }
      }
      for (int i = 0; i < columnBlocks.length; i++) {
        final row = FusionLayout.rows - 1 - i;
        final b = columnBlocks[i];
        b.col = col;
        b.row = row;
        grid[col][row] = b;

        // Check if ingredient reached bottom row (row 8)
        if (b.isIngredient && row == FusionLayout.rows - 1) {
          b.state = FusionBlockState.popping;
          b.popProgress = 0.0;
          grid[col][row] = null;
          _poppingBlocks.add(b);
          _spawnPopParticles(layout.cellCenter(col, row), 2); // Yellow sparkle
          _trackGoalProgress(GoalType.dropToBottom, 1);
          scoreFloats.add(FusionScoreFloat(
            pos: layout.cellCenter(col, row),
            text: 'RESCUED! ⭐',
            color: const Color(0xFFFFD600),
          ));
        }
      }
    }
  }

  void _refillGrid() {
    for (int col = 0; col < FusionLayout.cols; col++) {
      int emptyCount = 0;
      for (int row = 0; row < FusionLayout.rows; row++) {
        if (grid[col][row] == null) emptyCount++;
      }
      int filled = 0;
      for (int row = 0; row < FusionLayout.rows && filled < emptyCount; row++) {
        if (grid[col][row] == null) {
          grid[col][row] = _newBlock(col, row, dropping: true);
          filled++;
        }
      }
    }
  }

  /// CRITICAL FIX: Level completion condition & cascade termination.
  /// When goal is met, stops auto-cascading and cleanly marks level won.
  void _onDropComplete() {
    // 1. If goal is met, DO NOT CASCADE further! Transition directly to won state.
    if (_isGoalMet()) {
      phase = FusionPhase.won;
      notifyListeners();
      return;
    }

    // 2. Check automatic cascade matches only if level is not yet won
    final cascadeCells = _findAutoCascadeCells();
    if (cascadeCells.isNotEmpty) {
      final first = cascadeCells.first;
      _executePop(cascadeCells, center: layout.cellCenter(first.col, first.row));
    } else {
      phase = FusionPhase.idle;
      _checkWinLoss();
      _checkDeadBoard();
      notifyListeners();
    }
  }

  Set<({int col, int row})> _findAutoCascadeCells() {
    final visited = <String>{};
    final matchCells = <({int col, int row})>{};

    for (int col = 0; col < FusionLayout.cols; col++) {
      for (int row = 0; row < FusionLayout.rows; row++) {
        final key = '$col,$row';
        if (visited.contains(key)) continue;
        final b = grid[col][row];
        if (b == null || !b.isAlive || b.isObstacle || b.isIngredient) continue;

        final group = <({int col, int row})>[];
        void flood(int c, int r, int color) {
          final k = '$c,$r';
          if (visited.contains(k)) return;
          if (c < 0 || c >= FusionLayout.cols || r < 0 || r >= FusionLayout.rows) return;
          final cur = grid[c][r];
          if (cur == null || !cur.isAlive || cur.isObstacle || cur.isIngredient || cur.colorIndex != color) return;
          visited.add(k);
          group.add((col: c, row: r));
          flood(c - 1, r, color);
          flood(c + 1, r, color);
          flood(c, r - 1, color);
          flood(c, r + 1, color);
        }

        flood(col, row, b.colorIndex);
        if (group.length >= 3) {
          matchCells.addAll(group);
        }
      }
    }
    return matchCells;
  }

  bool _isGoalMet() {
    return goal.isMet;
  }

  void _checkDeadBoard() {
    if (phase != FusionPhase.idle) return;

    bool hasValidMove = false;
    for (int c1 = 0; c1 < FusionLayout.cols && !hasValidMove; c1++) {
      for (int r1 = 0; r1 < FusionLayout.rows && !hasValidMove; r1++) {
        final b1 = grid[c1][r1];
        if (b1 == null || b1.isObstacle || b1.isIngredient) continue;
        for (int c2 = 0; c2 < FusionLayout.cols && !hasValidMove; c2++) {
          for (int r2 = 0; r2 < FusionLayout.rows && !hasValidMove; r2++) {
            if (c1 == c2 && r1 == r2) continue;
            final sim = simulateMove(
              boardState: grid,
              from: (col: c1, row: r1),
              to: (col: c2, row: r2),
              rules: mergeRules,
            );
            if (sim.isValid) {
              hasValidMove = true;
            }
          }
        }
      }
    }

    if (!hasValidMove) {
      _autoShuffle();
    }
  }

  void _autoShuffle() {
    phase = FusionPhase.shuffling;
    final allBlocks = <FusionBlock>[];
    for (int c = 0; c < FusionLayout.cols; c++) {
      for (int r = 0; r < FusionLayout.rows; r++) {
        final b = grid[c][r];
        if (b != null && !b.isObstacle && !b.isIngredient) {
          allBlocks.add(b);
          grid[c][r] = null;
        }
      }
    }

    for (int i = allBlocks.length - 1; i > 0; i--) {
      final j = _rng.nextInt(i + 1);
      final temp = allBlocks[i];
      allBlocks[i] = allBlocks[j];
      allBlocks[j] = temp;
    }

    var idx = 0;
    for (int c = 0; c < FusionLayout.cols; c++) {
      for (int r = 0; r < FusionLayout.rows; r++) {
        if (grid[c][r] == null && idx < allBlocks.length) {
          final b = allBlocks[idx++];
          b.col = c;
          b.row = r;
          b.state = FusionBlockState.dropping;
          b.dropProgress = 0.0;
          grid[c][r] = b;
        }
      }
    }

    scoreFloats.add(FusionScoreFloat(
      pos: Offset(layout.w / 2, layout.boardTop + layout.boardH / 2),
      text: 'SHUFFLE!',
      color: const Color(0xFF00E5FF),
    ));

    notifyListeners();
  }

  void addMoves(int extra) {
    movesLeft += extra;
    phase = FusionPhase.idle;
    notifyListeners();
  }

  void _checkWinLoss() {
    if (_isGoalMet()) {
      phase = FusionPhase.won;
    } else if (movesLeft <= 0) {
      phase = FusionPhase.lost;
    }
    notifyListeners();
  }

  void _spawnPopParticles(Offset center, int colorIndex, [ColorblindSymbol? symbol]) {
    final color = GameColors.blockColors[colorIndex % GameColors.blockColors.length];
    for (int i = 0; i < 14; i++) {
      final angle = (_rng.nextDouble() * math.pi * 2);
      final speed = 90 + _rng.nextDouble() * 180;
      particles.add(FusionParticle(
        pos: center,
        vel: Offset(math.cos(angle) * speed, math.sin(angle) * speed),
        color: color,
        life: 0.5 + _rng.nextDouble() * 0.45,
        size: 4.0 + _rng.nextDouble() * 5.0,
        isGem: i < 3,
        symbol: symbol,
      ));
    }
  }

  // ─── TICK UPDATE ──────────────────────────────────────────────────────────

  void update(double dt) {
    if (phase == FusionPhase.idle) {
      _checkWinLoss();
    }

    bool needsNotify = false;

    particles.removeWhere((p) {
      p.pos += p.vel * dt;
      p.vel = Offset(p.vel.dx * 0.92, p.vel.dy * 0.92 + 320 * dt);
      p.life -= dt;
      return p.life <= 0;
    });
    if (particles.isNotEmpty) needsNotify = true;

    scoreFloats.removeWhere((f) {
      f.pos = Offset(f.pos.dx, f.pos.dy - 55 * dt);
      f.life -= dt;
      return f.life <= 0;
    });
    if (scoreFloats.isNotEmpty) needsNotify = true;

    // Dropping and pulse updates
    for (int col = 0; col < FusionLayout.cols; col++) {
      for (int row = 0; row < FusionLayout.rows; row++) {
        final b = grid[col][row];
        if (b == null) continue;
        if (b.pulseProgress > 0) {
          b.pulseProgress = (b.pulseProgress - dt * 4).clamp(0.0, 1.0);
          needsNotify = true;
        }
        if (b.state == FusionBlockState.dropping && b.dropProgress < 1.0) {
          b.dropProgress = (b.dropProgress + dt * 5.2).clamp(0.0, 1.0);
          if (b.dropProgress >= 1.0) {
            b.state = FusionBlockState.idle;
          }
          needsNotify = true;
        }
      }
    }

    if (_pendingFuse != null) {
      final pf = _pendingFuse!;
      pf.target.fuseProgress = (pf.target.fuseProgress + dt * 4.2).clamp(0.0, 1.0);
      pf.dragged.fuseProgress = (pf.dragged.fuseProgress + dt * 4.2).clamp(0.0, 1.0);
      needsNotify = true;
      if (pf.dragged.fuseProgress >= 1.0 && pf.target.fuseProgress >= 1.0) {
        _onFuseComplete(pf.target, pf.sim);
      }
    }

    bool anyPopping = false;
    _poppingBlocks.removeWhere((b) {
      if (b.popDelay > 0) {
        b.popDelay -= dt;
        return false;
      }
      b.popProgress = (b.popProgress + dt * 3.6).clamp(0.0, 1.0);
      needsNotify = true;
      if (b.popProgress >= 1.0) return true;
      anyPopping = true;
      return false;
    });

    if (_pendingDropAfterPop && !anyPopping && _pendingFuse == null) {
      _onPopComplete();
      needsNotify = true;
    }

    if (phase == FusionPhase.dropping || phase == FusionPhase.shuffling) {
      bool anyDropping = false;
      for (int col = 0; col < FusionLayout.cols; col++) {
        for (int row = 0; row < FusionLayout.rows; row++) {
          final b = grid[col][row];
          if (b != null && b.state == FusionBlockState.dropping) {
            anyDropping = true;
            break;
          }
        }
        if (anyDropping) break;
      }
      if (!anyDropping) {
        _onDropComplete();
        needsNotify = true;
      }
    }

    if (needsNotify) notifyListeners();
  }
}
