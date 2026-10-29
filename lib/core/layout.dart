import 'dart:ui';

class Layout {
  Layout(Size size, {double safeTop = 0, double safeBottom = 0})
      : w = size.width,
        h = size.height,
        u = (size.width / 576).clamp(0.5, 2.0) {
    hudH = (160 * u) > (safeTop + 110 * u) ? 160 * u : safeTop + 110 * u;
    bottomH = 137 * u + safeBottom;
    floorY = h - bottomH;
    cellW = w / cols;
    cellH = (floorY - hudH) / rows;
    r = cellW * 0.16;
    speed = w * 2.5;
  }

  static const int cols = 11;
  static const int rows = 14;

  final double w, h, u;
  late final double hudH, bottomH, floorY, cellW, cellH, r, speed;

  Rect cellRect(int c, int row) =>
      Rect.fromLTWH(c * cellW, hudH + row * cellH, cellW, cellH);

  Rect blockRect(int c, int row) =>
      cellRect(c, row).deflate(cellW * 0.05);

  Offset cellCenter(int c, int row) => cellRect(c, row).center;
}
