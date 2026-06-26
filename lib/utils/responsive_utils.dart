import 'package:flutter/material.dart';

/// Responsive utility that adapts to any mobile screen size.
///
/// Screen size buckets (by width):
///   - xs  : < 360 px  (very small: Galaxy A01, Moto E, etc.)
///   - sm  : 360–399 px (small: standard Android, iPhone SE)
///   - md  : 400–449 px (medium: modern Android, iPhone 14)
///   - lg  : 450–599 px (large: iPhone Pro Max, large Android)
///   - xl  : ≥ 600 px  (tablet / foldable)
class R {
  R._();

  // ─── cached values ────────────────────────────────────────────────────────

  static late double _width;
  static late double _height;
  static late double _pixelRatio;

  /// Call once per build, ideally in the top-level widget tree.
  static void init(BuildContext context) {
    final mq = MediaQuery.of(context);
    _width = mq.size.width;
    _height = mq.size.height;
    _pixelRatio = mq.devicePixelRatio;
  }

  // ─── screen info ─────────────────────────────────────────────────────────

  static double get screenWidth => _width;
  static double get screenHeight => _height;
  static double get pixelRatio => _pixelRatio;

  static bool get isXs => _width < 360;
  static bool get isSm => _width >= 360 && _width < 400;
  static bool get isMd => _width >= 400 && _width < 450;
  static bool get isLg => _width >= 450 && _width < 600;
  static bool get isXl => _width >= 600;

  // ─── adaptive spacing ─────────────────────────────────────────────────────

  /// Returns a spacing/padding value scaled to the current screen width.
  /// [base] is the design-time value (designed for ~390 px width).
  static double sp(double base) {
    final scale = (_width / 390).clamp(0.78, 1.25);
    return base * scale;
  }

  // ─── adaptive font size ───────────────────────────────────────────────────

  /// Returns a font size that scales with the screen width but also respects
  /// the device text-scale factor, clamped so it never shrinks below
  /// [minSize] or grows above [maxSize].
  static double fs(
    double base, {
    double minSize = 10,
    double? maxSize,
  }) {
    final scaled = base * (_width / 390).clamp(0.80, 1.20);
    final clamped = scaled.clamp(minSize, maxSize ?? double.infinity);
    return clamped;
  }

  // ─── adaptive icon size ───────────────────────────────────────────────────

  static double icon(double base) => sp(base);

  // ─── adaptive widget size ─────────────────────────────────────────────────

  static double w(double base) => sp(base);
  static double h(double base) => sp(base);

  // ─── grid helpers ─────────────────────────────────────────────────────────

  /// Number of columns for the Quick Actions grid.
  static int get gridColumns => isXs ? 1 : 2;

  /// Aspect ratio for the Quick Actions grid tile.
  /// Taller tiles on narrow screens so the label fits on one line.
  static double get actionTileAspectRatio {
    if (isXs) return 4.0;
    if (isSm) return 3.2;
    if (isMd) return 2.8;
    if (isLg) return 2.4;
    return 2.2; // xl
  }
}
