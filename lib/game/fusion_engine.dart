import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/theme.dart';
import 'fusion_models.dart';

/// Grid layout constants for the Fusion board
class FusionLayout {
  FusionLayout(Size size, {double safeTop = 0, double safeBottom = 0})
      : w = size.width,
        h = size.height {
    // HUD area at top
    hudH = safeTop + 110.0;

    // Bottom toolbar area
    bottomH = safeBottom + 100.0;

    // Available play area
    boardTop = hudH;
    boardBottom = h - bottomH;
    boardH = boardBottom - boardTop;
    boardW = w;

    // Cell sizes (7 cols × 9 rows)
    cellW = boardW / cols;
    cellH = boardH / rows;

    // Block inset margin
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

  /// Map a canvas position to a grid cell, returns null if out of bounds
  ({int col, int row})? hitTest(Offset pos) {
    final col = (pos.dx / cellW).floor();
    final row = ((pos.dy - boardTop) / cellH).floor();
    if (col < 0 || col >= cols || row < 0 || row >= rows) return null;
    return (col: col, row: row);
  }
}

/// The main game engine for BLOOP FUSION
class FusionEngine extends ChangeNotifier {
  FusionEngine({
    required this.layout,
    required this.targetPops,
    required this.levelId,
    required this.maxMoves,
  }) {
    _init();
  }

  FusionLayout layout;
  final int targetPops;
  final int levelId;
  final int maxMoves;

  FusionPhase phase = FusionPhase.idle;

  // The grid: grid[col][row] = block or null
  late List<List<FusionBlock?>> grid;

  // Active drag state
  FusionBlock? dragBlock;
  Offset? dragPos;
  ({int col, int row})? dragTarget; // highlighted target cell

  // Animation lists
  final List<FusionParticle> particles = [];
  final List<FusionScoreFloat> scoreFloats = [];

  // Game state
  int poppedCount = 0;
  int movesLeft = 0;
  int score = 0;
  int comboMultiplier = 1;

  final math.Random _rng = math.Random();
  int _nextId = 1;

  // ID counter for unique block identification
  int get _id => _nextId++;

  // Colors available (count scales with level)
  int get _colorCount => (3 + (levelId ~/ 4)).clamp(3, 6);

  void _init() {
    movesLeft = maxMoves;
    grid = List.generate(FusionLayout.cols,
        (_) => List.filled(FusionLayout.rows, null, growable: false));
    _fillInitialGrid();
  }

  void _fillInitialGrid() {
    // Fill all 7×9 cells with random blocks, no immediate matches
    for (int row = 0; row < FusionLayout.rows; row++) {
      for (int col = 0; col < FusionLayout.cols; col++) {
        grid[col][row] = _newBlock(col, row, dropping: false);
      }
    }
    // Ensure no 3+ horizontal/vertical same-color runs at start
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
    // Simple approach: for each cell, if it creates a 3+ run, recolor it
    for (int row = 0; row < FusionLayout.rows; row++) {
      for (int col = 0; col < FusionLayout.cols; col++) {
        final b = grid[col][row];
        if (b == null) continue;

        int attempts = 0;
        while (_hasMatchAt(col, row) && attempts < 10) {
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

  bool _hasMatchAt(int col, int row) {
    final b = grid[col][row];
    if (b == null) return false;
    final c = b.colorIndex;

    // Check left-left
    if (col >= 2) {
      final b1 = grid[col - 1][row];
      final b2 = grid[col - 2][row];
      if (b1?.colorIndex == c && b2?.colorIndex == c) return true;
    }
    // Check up-up
    if (row >= 2) {
      final b1 = grid[col][row - 1];
      final b2 = grid[col][row - 2];
      if (b1?.colorIndex == c && b2?.colorIndex == c) return true;
    }
    return false;
  }

  // ─── INPUT HANDLING ───────────────────────────────────────────────────────

  void onDragStart(Offset pos) {
    if (phase != FusionPhase.idle) return;
    final hit = layout.hitTest(pos);
    if (hit == null) return;
    final block = grid[hit.col][hit.row];
    if (block == null || block.state != FusionBlockState.idle) return;

    dragBlock = block;
    dragPos = pos;
    dragTarget = null;
    block.state = FusionBlockState.dragging;
    phase = FusionPhase.dragging;
    notifyListeners();
  }

  void onDragUpdate(Offset pos) {
    if (phase != FusionPhase.dragging || dragBlock == null) return;
    dragPos = pos;

    // Find the target cell under the finger (excluding the drag block's own cell)
    final hit = layout.hitTest(pos);
    if (hit != null && !(hit.col == dragBlock!.col && hit.row == dragBlock!.row)) {
      final target = grid[hit.col][hit.row];
      // Only highlight if same color (potential fuse) or empty (move)
      if (target == null || target.colorIndex == dragBlock!.colorIndex) {
        dragTarget = hit;
      } else {
        dragTarget = null;
      }
    } else {
      dragTarget = null;
    }
    notifyListeners();
  }

  void onDragEnd(Offset pos) {
    if (phase != FusionPhase.dragging || dragBlock == null) return;

    final hit = layout.hitTest(pos);
    final db = dragBlock!;

    // Cancel drag — put block back
    db.state = FusionBlockState.idle;
    db.dragPos = null;
    dragBlock = null;
    dragPos = null;
    dragTarget = null;

    if (hit == null || (hit.col == db.col && hit.row == db.row)) {
      // Dropped on itself — just deselect
      phase = FusionPhase.idle;
      notifyListeners();
      return;
    }

    final targetBlock = grid[hit.col][hit.row];

    if (targetBlock == null) {
      // Move to empty cell
      _moveBlock(db, hit.col, hit.row);
    } else if (targetBlock.colorIndex == db.colorIndex) {
      // FUSE! Same color dropped on same color
      _fuseBlocks(db, targetBlock, hit.col, hit.row);
    } else {
      // Invalid — just cancel
      phase = FusionPhase.idle;
      notifyListeners();
      return;
    }
  }

  void _moveBlock(FusionBlock block, int toCol, int toRow) {
    grid[block.col][block.row] = null;
    block.col = toCol;
    block.row = toRow;
    grid[toCol][toRow] = block;
    block.state = FusionBlockState.idle;
    phase = FusionPhase.idle;
    _consumeMove();
    notifyListeners();
  }

  void _fuseBlocks(FusionBlock draggedBlock, FusionBlock targetBlock, int toCol, int toRow) {
    phase = FusionPhase.animating;

    // Remove dragged block from its old cell
    grid[draggedBlock.col][draggedBlock.row] = null;
    draggedBlock.state = FusionBlockState.fusing;
    draggedBlock.fuseProgress = 0.0;

    // Upgrade target block fusion level
    final newLevel = (targetBlock.fusionLevel + draggedBlock.fusionLevel).clamp(1, 3);
    targetBlock.fusionLevel = newLevel;
    targetBlock.state = FusionBlockState.fusing;
    targetBlock.fuseProgress = 0.0;
    targetBlock.pulseProgress = 1.0;

    // Store for animation
    _pendingFuse = (
      dragged: draggedBlock,
      target: targetBlock,
      toCol: toCol,
      toRow: toRow,
    );

    _consumeMove();
    notifyListeners();
  }

  ({FusionBlock dragged, FusionBlock target, int toCol, int toRow})? _pendingFuse;

  // Called once fuse animation completes
  void _onFuseComplete(FusionBlock target) {
    target.state = FusionBlockState.idle;
    target.fuseProgress = 1.0;
    _pendingFuse = null;

    // If it's a Super block (level 3), immediately auto-pop all neighbors of same color
    if (target.isSuper) {
      _chainPopFrom(target.col, target.row);
    } else {
      // Check if this Power block is now adjacent to 3+ same-color → chain pop
      final chainCount = _countSameColorConnected(target.col, target.row, target.colorIndex);
      if (chainCount >= 3) {
        _chainPopFrom(target.col, target.row);
      } else {
        phase = FusionPhase.idle;
        _checkWinLoss();
      }
    }
    notifyListeners();
  }

  // ─── CHAIN POP LOGIC ──────────────────────────────────────────────────────

  int _countSameColorConnected(int col, int row, int color) {
    final visited = <String>{};
    return _floodCount(col, row, color, visited);
  }

  int _floodCount(int col, int row, int color, Set<String> visited) {
    final key = '$col,$row';
    if (visited.contains(key)) return 0;
    if (col < 0 || col >= FusionLayout.cols) return 0;
    if (row < 0 || row >= FusionLayout.rows) return 0;
    final b = grid[col][row];
    if (b == null || b.colorIndex != color || b.state == FusionBlockState.popping) return 0;
    visited.add(key);
    return 1 +
        _floodCount(col - 1, row, color, visited) +
        _floodCount(col + 1, row, color, visited) +
        _floodCount(col, row - 1, color, visited) +
        _floodCount(col, row + 1, color, visited);
  }

  List<FusionBlock> _floodCollect(int col, int row, int color) {
    final visited = <String>{};
    final result = <FusionBlock>[];
    _floodCollectHelper(col, row, color, visited, result);
    return result;
  }

  void _floodCollectHelper(int col, int row, int color, Set<String> visited, List<FusionBlock> out) {
    final key = '$col,$row';
    if (visited.contains(key)) return;
    if (col < 0 || col >= FusionLayout.cols) return;
    if (row < 0 || row >= FusionLayout.rows) return;
    final b = grid[col][row];
    if (b == null || b.colorIndex != color || b.state == FusionBlockState.popping) return;
    visited.add(key);
    out.add(b);
    _floodCollectHelper(col - 1, row, color, visited, out);
    _floodCollectHelper(col + 1, row, color, visited, out);
    _floodCollectHelper(col, row - 1, color, visited, out);
    _floodCollectHelper(col, row + 1, color, visited, out);
  }

  void _chainPopFrom(int col, int row) {
    final b = grid[col][row];
    if (b == null) return;
    final connected = _floodCollect(col, row, b.colorIndex);

    if (connected.length < 2) {
      phase = FusionPhase.idle;
      _checkWinLoss();
      return;
    }

    phase = FusionPhase.animating;
    final centerPos = layout.cellCenter(col, row);

    for (int i = 0; i < connected.length; i++) {
      final block = connected[i];
      block.state = FusionBlockState.popping;
      block.popDelay = i * 0.04;
      block.popProgress = 0.0;
      grid[block.col][block.row] = null;
      _poppingBlocks.add(block); // track for paint animation

      // Spawn burst particles
      _spawnPopParticles(layout.cellCenter(block.col, block.row), block.colorIndex);
    }

    // Score based on combo size + fusion levels
    final popCount = connected.length;
    final totalFusionLevel = connected.fold(0, (s, b) => s + b.fusionLevel);
    final pts = popCount * 10 * totalFusionLevel * comboMultiplier;
    score += pts;
    poppedCount += popCount;
    comboMultiplier = (comboMultiplier + 1).clamp(1, 8);

    // Score float
    scoreFloats.add(FusionScoreFloat(
      pos: centerPos,
      text: '+$pts',
      color: GameColors.blockColors[b.colorIndex % GameColors.blockColors.length],
    ));

    _pendingDropAfterPop = true;
    notifyListeners();
  }

  bool _pendingDropAfterPop = false;

  void _onPopComplete() {
    // Remove all fully-popped blocks (cleanup)
    for (int col = 0; col < FusionLayout.cols; col++) {
      for (int row = 0; row < FusionLayout.rows; row++) {
        // Already cleared from grid, poppingBlocks list clears via animation
      }
    }

    // Apply gravity: blocks fall down
    _applyGravity();

    // Refill empty top cells
    _refillGrid();

    _pendingDropAfterPop = false;
    phase = FusionPhase.dropping;
    comboMultiplier = 1; // reset combo after drop
    notifyListeners();
  }

  void _applyGravity() {
    for (int col = 0; col < FusionLayout.cols; col++) {
      // Collect non-null blocks from bottom to top
      final existing = <FusionBlock>[];
      for (int row = FusionLayout.rows - 1; row >= 0; row--) {
        final b = grid[col][row];
        if (b != null && b.state != FusionBlockState.popping) {
          existing.add(b);
          grid[col][row] = null;
        }
      }
      // Place them back at the bottom
      for (int i = 0; i < existing.length; i++) {
        final row = FusionLayout.rows - 1 - i;
        existing[i].col = col;
        existing[i].row = row;
        grid[col][row] = existing[i];
      }
    }
  }

  void _refillGrid() {
    // Count empty cells in each column and add new dropping blocks at top
    for (int col = 0; col < FusionLayout.cols; col++) {
      int emptyCount = 0;
      for (int row = 0; row < FusionLayout.rows; row++) {
        if (grid[col][row] == null) emptyCount++;
      }
      // Fill empty rows from top
      int filled = 0;
      for (int row = 0; row < FusionLayout.rows && filled < emptyCount; row++) {
        if (grid[col][row] == null) {
          grid[col][row] = _newBlock(col, row, dropping: true);
          filled++;
        }
      }
    }
  }

  void _onDropComplete() {
    // All blocks are now settled — check for auto-chains (cascade)
    final cascade = _findAutoCascade();
    if (cascade != null) {
      _chainPopFrom(cascade.col, cascade.row);
    } else {
      phase = FusionPhase.idle;
      _checkWinLoss();
    }
  }

  FusionBlock? _findAutoCascade() {
    // Look for any group of 3+ same-color connected blocks (not power blocks, those are intentional)
    for (int col = 0; col < FusionLayout.cols; col++) {
      for (int row = 0; row < FusionLayout.rows; row++) {
        final b = grid[col][row];
        if (b == null || b.state == FusionBlockState.popping) continue;
        // Super blocks auto-cascade
        if (b.isSuper) return b;
      }
    }
    return null;
  }

  void _consumeMove() {
    movesLeft--;
  }

  void _checkWinLoss() {
    if (poppedCount >= targetPops) {
      phase = FusionPhase.won;
    } else if (movesLeft <= 0) {
      phase = FusionPhase.lost;
    }
    notifyListeners();
  }

  // ─── PARTICLES ────────────────────────────────────────────────────────────

  void _spawnPopParticles(Offset center, int colorIndex) {
    final color = GameColors.blockColors[colorIndex % GameColors.blockColors.length];
    for (int i = 0; i < 12; i++) {
      final angle = (_rng.nextDouble() * math.pi * 2);
      final speed = 80 + _rng.nextDouble() * 160;
      particles.add(FusionParticle(
        pos: center,
        vel: Offset(math.cos(angle) * speed, math.sin(angle) * speed),
        color: color,
        life: 0.5 + _rng.nextDouble() * 0.5,
        size: 4.0 + _rng.nextDouble() * 6.0,
        isGem: i < 3,
      ));
    }
  }

  // ─── UPDATE LOOP ──────────────────────────────────────────────────────────

  void update(double dt) {
    bool needsNotify = false;

    // Animate particles
    particles.removeWhere((p) {
      p.pos += p.vel * dt;
      p.vel = Offset(p.vel.dx * 0.9, p.vel.dy * 0.9 + 300 * dt); // gravity
      p.life -= dt;
      return p.life <= 0;
    });
    if (particles.isNotEmpty) needsNotify = true;

    // Animate score floats
    scoreFloats.removeWhere((f) {
      f.pos = Offset(f.pos.dx, f.pos.dy - 60 * dt);
      f.life -= dt;
      return f.life <= 0;
    });
    if (scoreFloats.isNotEmpty) needsNotify = true;

    // Animate block pulses
    for (int col = 0; col < FusionLayout.cols; col++) {
      for (int row = 0; row < FusionLayout.rows; row++) {
        final b = grid[col][row];
        if (b == null) continue;
        if (b.pulseProgress > 0) {
          b.pulseProgress = (b.pulseProgress - dt * 4).clamp(0.0, 1.0);
          needsNotify = true;
        }
        if (b.state == FusionBlockState.dropping && b.dropProgress < 1.0) {
          b.dropProgress = (b.dropProgress + dt * 5.5).clamp(0.0, 1.0);
          if (b.dropProgress >= 1.0) {
            b.state = FusionBlockState.idle;
          }
          needsNotify = true;
        }
      }
    }

    // Animate fusing blocks
    if (_pendingFuse != null) {
      final pf = _pendingFuse!;
      pf.target.fuseProgress = (pf.target.fuseProgress + dt * 4.0).clamp(0.0, 1.0);
      pf.dragged.fuseProgress = (pf.dragged.fuseProgress + dt * 4.0).clamp(0.0, 1.0);
      needsNotify = true;

      if (pf.dragged.fuseProgress >= 1.0 && pf.target.fuseProgress >= 1.0) {
        _onFuseComplete(pf.target);
      }
    }

    // Animate popping blocks
    bool anyPopping = false;
    for (int col = 0; col < FusionLayout.cols; col++) {
      for (int row = 0; row < FusionLayout.rows; row++) {
        // Also scan recently cleared positions (they may still be in animation)
      }
    }

    // Scan ALL blocks including removed ones (store separately for animation)
    _poppingBlocks.removeWhere((b) {
      if (b.popDelay > 0) {
        b.popDelay -= dt;
        return false;
      }
      b.popProgress = (b.popProgress + dt * 3.5).clamp(0.0, 1.0);
      needsNotify = true;
      if (b.popProgress >= 1.0) return true; // remove from animation list
      anyPopping = true;
      return false;
    });

    if (_pendingDropAfterPop && !anyPopping && _pendingFuse == null) {
      _onPopComplete();
      needsNotify = true;
    }

    // Animate dropping phase
    if (phase == FusionPhase.dropping) {
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

  // Store popping blocks separately so they can still be animated after removal from grid
  final List<FusionBlock> _poppingBlocks = [];

  /// Expose popping blocks to the painter for death animations
  List<FusionBlock> get poppingBlocksForPaint => _poppingBlocks;
}
