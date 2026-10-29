import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/layout.dart';
import '../core/theme.dart';
import 'models.dart';

enum Phase { idle, aiming, shooting, recalling, returning, won, lost }

class GameEngine {
  GameEngine({
    required this.layout,
    required List<Block> startBlocks,
    required List<Orb> startOrbs,
    required this.baseBalls,
    this.descendEachTurn = true,
    this.onBlockHit,
    this.onBlockDestroyed,
    this.onOrbTriggered,
  }) {
    blocks = startBlocks;
    orbs = startOrbs;
    ballCount = baseBalls;
    launcherX = layout.w / 2;
    _rebuildGrid();
  }

  Layout layout;
  final int baseBalls;
  final bool descendEachTurn;

  /// Updates layout dynamically during mid-game window resizing or fold/unfold transitions (Apple Duo / iPads)
  void updateLayout(Layout newLayout) {
    final oldW = layout.w;
    layout = newLayout;
    if (oldW > 0) {
      launcherX = (launcherX / oldW) * layout.w;
    } else {
      launcherX = layout.w / 2;
    }
    _rebuildGrid();
  }

  final VoidCallback? onBlockHit;
  final VoidCallback? onBlockDestroyed;
  final VoidCallback? onOrbTriggered;

  late List<Block> blocks;
  late List<Orb> orbs;
  final List<Ball> balls = [];
  final List<Particle> particles = [];
  final List<Bolt> bolts = [];
  final math.Random _rnd = math.Random();

  Phase phase = Phase.idle;
  int ballCount = 30;
  int toFire = 0;
  int landedCount = 0;
  int extraBalls = 0;
  int damage = 1;
  int cashEarned = 0;
  bool isFireActive = false;

  double launcherX = 0;
  double? firstLandX;
  Offset aimDir = const Offset(0, -1);
  double _fireTimer = 0.0;
  double _returnT = 0.0;
  double _fromX = 0.0;

  late List<List<Block?>> _grid;

  int get counter {
    if (phase == Phase.idle || phase == Phase.aiming) {
      return ballCount;
    }
    return landedCount;
  }

  void setAim(Offset target) {
    if (phase != Phase.idle && phase != Phase.aiming) return;
    final from = Offset(launcherX, layout.floorY - layout.r);
    final d = target - from;
    if (d.dy > -layout.cellH * 0.2) return;

    var angle = math.atan2(-d.dy, d.dx);
    final minAngle = 10 * math.pi / 180;
    angle = angle.clamp(minAngle, math.pi - minAngle);

    aimDir = Offset(math.cos(angle), -math.sin(angle));
    phase = Phase.aiming;
  }

  void cancelAim() {
    if (phase == Phase.aiming) {
      phase = Phase.idle;
    }
  }

  void fire() {
    if (phase != Phase.aiming) return;
    toFire = ballCount;
    landedCount = 0;
    firstLandX = null;
    _fireTimer = 0.0;
    phase = Phase.shooting;
  }

  void recall() {
    if (phase != Phase.shooting) return;
    toFire = 0;
    for (final b in balls) {
      if (!b.landed) {
        b.vel = Offset(0, layout.speed * 2.2);
      }
    }
    phase = Phase.recalling;
  }

  // Power-up 1: Smash (removes lowest row of blocks)
  bool triggerSmash() {
    if (phase != Phase.idle) return false;
    final activeBlocks = blocks.where((b) => b.alive).toList();
    if (activeBlocks.isEmpty) return false;
    
    int maxRow = activeBlocks.map((b) => b.row).reduce(math.max);
    final toSmash = activeBlocks.where((b) => b.row == maxRow).toList();
    for (final b in toSmash) {
      _damage(b, b.hp);
    }
    return true;
  }

  // Power-up 2: More Balls (+10 balls)
  bool triggerMoreBalls() {
    if (phase != Phase.idle) return false;
    ballCount += 10;
    _burst(Offset(launcherX, layout.floorY - layout.r), 12);
    return true;
  }

  // Power-up 3: Row Blast (damages all blocks)
  bool triggerRowBlast() {
    if (phase != Phase.idle) return false;
    final activeBlocks = blocks.where((b) => b.alive).toList();
    if (activeBlocks.isEmpty) return false;
    for (final b in activeBlocks) {
      _damage(b, 2);
    }
    return true;
  }

  // Power-up 4: Fire Ball (double damage)
  bool triggerFireBall() {
    if (phase != Phase.idle) return false;
    isFireActive = true;
    damage = 2;
    _burst(Offset(launcherX, layout.floorY - layout.r), 15);
    return true;
  }

  // Power-up 5: Stone Breaker (destroys highest HP block)
  bool triggerStoneBreaker() {
    if (phase != Phase.idle) return false;
    final activeBlocks = blocks.where((b) => b.alive).toList();
    if (activeBlocks.isEmpty) return false;
    activeBlocks.sort((a, b) => b.hp.compareTo(a.hp));
    final target = activeBlocks.first;
    _damage(target, target.hp);
    return true;
  }

  void update(double dt) {
    dt = math.min(dt, 1 / 30);
    if (phase == Phase.shooting || phase == Phase.recalling) {
      _emit(dt);
      final steps = ((layout.speed * dt) / (layout.r * 0.5)).ceil().clamp(1, 12);
      final h = dt / steps;
      for (var i = 0; i < steps; i++) {
        _stepBalls(h);
      }
      if (toFire == 0 && balls.isNotEmpty && balls.every((b) => b.landed)) {
        _beginReturn();
      }
    } else if (phase == Phase.returning) {
      _returnT += dt / 0.18;
      final t = _easeOut(_returnT.clamp(0.0, 1.0));
      final x = _fromX + (launcherX - _fromX) * t;
      for (final b in balls) {
        b.pos = Offset(x, b.pos.dy);
      }
      if (_returnT >= 1.0) {
        _resolveTurn();
      }
    }
    _updateFx(dt);
  }

  double _easeOut(double t) => 1 - (1 - t) * (1 - t) * (1 - t);

  void _emit(double dt) {
    if (toFire <= 0) return;
    _fireTimer -= dt;
    while (_fireTimer <= 0 && toFire > 0) {
      balls.add(Ball(
        pos: Offset(launcherX, layout.floorY - layout.r),
        vel: aimDir * layout.speed,
      ));
      toFire--;
      _fireTimer += 0.055;
    }
  }

  void _stepBalls(double h) {
    final r = layout.r;
    for (final b in balls) {
      if (b.landed) continue;
      b.pos += b.vel * h;

      // Left wall
      if (b.pos.dx < r) {
        b.pos = Offset(r, b.pos.dy);
        b.vel = Offset(b.vel.dx.abs(), b.vel.dy);
      }
      // Right wall
      if (b.pos.dx > layout.w - r) {
        b.pos = Offset(layout.w - r, b.pos.dy);
        b.vel = Offset(-b.vel.dx.abs(), b.vel.dy);
      }
      // Ceiling (below HUD)
      if (b.pos.dy < layout.hudH + r) {
        b.pos = Offset(b.pos.dx, layout.hudH + r);
        b.vel = Offset(b.vel.dx, b.vel.dy.abs());
      }
      // Floor line
      if (b.vel.dy > 0 && b.pos.dy >= layout.floorY - r) {
        b.landed = true;
        b.pos = Offset(b.pos.dx.clamp(r, layout.w - r), layout.floorY - r);
        landedCount++;
        firstLandX ??= b.pos.dx;
        continue;
      }

      _hitBlocks(b);
      _hitOrbs(b);
    }
  }

  void _hitBlocks(Ball b) {
    final r = layout.r;
    final c0 = ((b.pos.dx - r) / layout.cellW).floor();
    final c1 = ((b.pos.dx + r) / layout.cellW).floor();
    final r0 = ((b.pos.dy - layout.hudH - r) / layout.cellH).floor();
    final r1 = ((b.pos.dy - layout.hudH + r) / layout.cellH).floor();

    for (var rr = r0; rr <= r1; rr++) {
      for (var cc = c0; cc <= c1; cc++) {
        if (rr < 0 || rr >= Layout.rows || cc < 0 || cc >= Layout.cols) continue;
        final blk = _grid[rr][cc];
        if (blk == null || !blk.alive) continue;
        if (_collide(b, blk)) {
          return; // one block per ball per substep
        }
      }
    }
  }

  bool _collide(Ball b, Block blk) {
    final rect = layout.blockRect(blk.col, blk.row);
    final r = layout.r;
    final p = b.pos;
    Offset closest;
    bool inside = false;

    if (blk.kind == BlockKind.square) {
      closest = Offset(
        p.dx.clamp(rect.left, rect.right),
        p.dy.clamp(rect.top, rect.bottom),
      );
      inside = rect.contains(p);
      if (inside) {
        final dl = p.dx - rect.left;
        final dr = rect.right - p.dx;
        final dt = p.dy - rect.top;
        final db = rect.bottom - p.dy;
        final m = math.min(math.min(dl, dr), math.min(dt, db));
        final n = m == dl
            ? const Offset(-1, 0)
            : m == dr
                ? const Offset(1, 0)
                : m == dt
                    ? const Offset(0, -1)
                    : const Offset(0, 1);
        b.pos = p + n * (m + r);
        b.vel = _reflect(b.vel, n);
        _normalize(b);
        _damage(blk);
        return true;
      }
    } else {
      final tri = _tri(rect, blk.kind);
      closest = _closestOnPoly(p, tri);
      inside = _inTri(p, tri);
    }

    var d = p - closest;
    var dist = d.distance;
    if (!inside && dist >= r) return false;
    if (dist < 1e-6) dist = 1e-6;
    var n = d / dist;
    if (inside) n = -n;
    b.pos = closest + n * r;
    if (b.vel.dx * n.dx + b.vel.dy * n.dy < 0) {
      b.vel = _reflect(b.vel, n);
      _normalize(b);
    }
    _damage(blk);
    return true;
  }

  void _hitOrbs(Ball b) {
    final rad = layout.cellW * 0.38 + layout.r;
    for (final o in orbs) {
      if (o.consumed) continue;
      if ((layout.cellCenter(o.col, o.row) - b.pos).distance < rad) {
        o.consumed = true;
        _triggerOrb(o);
      }
    }
  }

  void _triggerOrb(Orb o) {
    final c = layout.cellCenter(o.col, o.row);
    _burst(c, 10);
    onOrbTriggered?.call();
    switch (o.kind) {
      case OrbKind.plusOne:
        extraBalls++;
        break;
      case OrbKind.horizontal:
        bolts.add(Bolt(
          a: Offset(0, c.dy),
          b: Offset(layout.w, c.dy),
          isVertical: false,
        ));
        for (final b in blocks.where((b) => b.alive && b.row == o.row)) {
          _damage(b, 1);
        }
        break;
      case OrbKind.vertical:
        bolts.add(Bolt(
          a: Offset(c.dx, layout.hudH),
          b: Offset(c.dx, layout.floorY),
          isVertical: true,
        ));
        for (final b in blocks.where((b) => b.alive && b.col == o.col)) {
          _damage(b, 1);
        }
        break;
    }
  }

  void _damage(Block blk, [int? amount]) {
    final dmg = amount ?? damage;
    blk.hp -= dmg;
    blk.pulse = 1.0;
    onBlockHit?.call();

    if (blk.hp <= 0) {
      blk.hp = 0;
      blk.dying = 0.001;
      _grid[blk.row][blk.col] = null;
      cashEarned += blk.maxHp * 2;
      _burst(layout.cellCenter(blk.col, blk.row), 12);
      onBlockDestroyed?.call();
    }
  }

  void _beginReturn() {
    _fromX = balls.first.pos.dx;
    launcherX = firstLandX ?? launcherX;
    _returnT = 0.0;
    phase = Phase.returning;
  }

  void _resolveTurn() {
    balls.clear();
    ballCount += extraBalls;
    extraBalls = 0;
    damage = 1;
    isFireActive = false;

    blocks.removeWhere((b) => !b.alive && b.dying > 1.0);

    if (blocks.every((b) => !b.alive)) {
      phase = Phase.won;
      return;
    }

    if (descendEachTurn) {
      for (final b in blocks.where((b) => b.alive)) {
        b.row++;
      }
      for (final o in orbs) {
        o.row++;
      }
      _rebuildGrid();
      final bottomRow = Layout.rows - 1;
      if (blocks.any((b) => b.alive && b.row >= bottomRow)) {
        phase = Phase.lost;
        return;
      }
    }
    phase = Phase.idle;
  }

  void _rebuildGrid() {
    _grid = List.generate(Layout.rows, (_) => List<Block?>.filled(Layout.cols, null));
    for (final b in blocks) {
      if (b.alive && b.row >= 0 && b.row < Layout.rows) {
        _grid[b.row][b.col] = b;
      }
    }
  }

  void _burst(Offset c, int count) {
    for (var i = 0; i < count; i++) {
      final a = _rnd.nextDouble() * math.pi * 2;
      final speed = 70 + _rnd.nextDouble() * 200;
      final color = GameColors.fxStarColors[_rnd.nextInt(GameColors.fxStarColors.length)];
      particles.add(Particle(
        pos: c,
        vel: Offset(math.cos(a), math.sin(a)) * speed,
        life: 0.45 + _rnd.nextDouble() * 0.2,
        color: color,
        size: 5.0 + _rnd.nextDouble() * 4.0,
      ));
    }
    for (var i = 0; i < 6; i++) {
      final a = _rnd.nextDouble() * math.pi * 2;
      particles.add(Particle(
        pos: c,
        vel: Offset(math.cos(a), math.sin(a)) * 260,
        life: 0.22,
        color: Colors.white,
        isStreak: true,
      ));
    }
  }

  void _updateFx(double dt) {
    for (final p in particles) {
      p.pos += p.vel * dt;
      p.life -= dt;
    }
    particles.removeWhere((p) => p.life <= 0);

    for (final b in bolts) {
      b.life -= dt;
    }
    bolts.removeWhere((b) => b.life <= 0);

    for (final b in blocks) {
      if (b.pulse > 0) {
        b.pulse = math.max(0.0, b.pulse - dt / 0.09);
      }
      if (b.dying > 0) {
        b.dying += dt / 0.12;
      }
    }
  }

  Offset _reflect(Offset v, Offset n) {
    final dot = v.dx * n.dx + v.dy * n.dy;
    return v - n * (2 * dot);
  }

  void _normalize(Ball b) {
    final s = layout.speed;
    var v = b.vel / b.vel.distance;
    const minY = 0.14;
    if (v.dy.abs() < minY) {
      final sy = v.dy < 0 ? -1.0 : 1.0;
      final sx = v.dx < 0 ? -1.0 : 1.0;
      v = Offset(sx * math.sqrt(1 - minY * minY), sy * minY);
    }
    b.vel = v * s;
  }

  List<Offset> _tri(Rect r, BlockKind k) {
    switch (k) {
      case BlockKind.triBR:
        return [r.topRight, r.bottomRight, r.bottomLeft];
      case BlockKind.triBL:
        return [r.topLeft, r.bottomLeft, r.bottomRight];
      case BlockKind.triTR:
        return [r.topLeft, r.topRight, r.bottomRight];
      case BlockKind.triTL:
        return [r.topLeft, r.topRight, r.bottomLeft];
      default:
        return [];
    }
  }

  Offset _closestOnSeg(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final t = (((p - a).dx * ab.dx + (p - a).dy * ab.dy) /
            (ab.dx * ab.dx + ab.dy * ab.dy))
        .clamp(0.0, 1.0);
    return a + ab * t;
  }

  Offset _closestOnPoly(Offset p, List<Offset> poly) {
    Offset best = poly[0];
    var bestD = double.infinity;
    for (var i = 0; i < poly.length; i++) {
      final c = _closestOnSeg(p, poly[i], poly[(i + 1) % poly.length]);
      final d = (c - p).distanceSquared;
      if (d < bestD) {
        bestD = d;
        best = c;
      }
    }
    return best;
  }

  bool _inTri(Offset p, List<Offset> t) {
    double s(Offset a, Offset b, Offset c) =>
        (a.dx - c.dx) * (b.dy - c.dy) - (b.dx - c.dx) * (a.dy - c.dy);
    final d1 = s(p, t[0], t[1]);
    final d2 = s(p, t[1], t[2]);
    final d3 = s(p, t[2], t[0]);
    final neg = d1 < 0 || d2 < 0 || d3 < 0;
    final pos = d1 > 0 || d2 > 0 || d3 > 0;
    return !(neg && pos);
  }
}
