import 'dart:math' as math;
import 'dart:ui' show PathMetric;

import 'package:flutter/widgets.dart';

import 'povad_theme.dart';

/// The same open-wire P geometry is used in the app icon and the live core.
class PovadMark extends StatelessWidget {
  const PovadMark({
    super.key,
    required this.size,
    required this.ink,
    required this.firstPoint,
    required this.secondPoint,
    this.activeInk,
    this.activeProgress = 0,
    this.serialSignalProgress,
    this.tcpSignalProgress,
    this.showPoints = true,
    this.glow = 0,
    this.fillHead = 0,
    this.transitProgress,
    this.transitReverse = false,
  });

  final double size;
  final Color ink, firstPoint, secondPoint;
  final Color? activeInk;
  final double activeProgress;
  final double? serialSignalProgress, tcpSignalProgress;
  final bool showPoints;

  /// Strength of the soft halo under the confirmed (blue) part of the path.
  final double glow;

  /// Brightness of the leading edge while the confirmed part is growing.
  final double fillHead;

  /// Position of the comet that travels while the worker starts or stops.
  final double? transitProgress;
  final bool transitReverse;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(
      painter: _MarkPainter(
        ink: ink,
        firstPoint: firstPoint,
        secondPoint: secondPoint,
        activeInk: activeInk,
        activeProgress: activeProgress,
        serialSignalProgress: serialSignalProgress,
        tcpSignalProgress: tcpSignalProgress,
        showPoints: showPoints,
        glow: glow,
        fillHead: fillHead,
        transitProgress: transitProgress,
        transitReverse: transitReverse,
      ),
    ),
  );
}

class PovadBrandLockup extends StatelessWidget {
  const PovadBrandLockup({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final palette = paletteOf(context);
    final markSize = compact ? 32.0 : 34.0;
    return Semantics(
      label: 'Povad',
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFFFFFFFF),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: palette.border),
              ),
              child: PovadMark(
                size: markSize,
                ink: const Color(0xFF18181B),
                firstPoint: const Color(0xFF2563EB),
                secondPoint: const Color(0xFF2563EB),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Povad',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: compact ? 19 : 20,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.6,
                color: palette.foreground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The open-wire P, in a 64 × 64 design space.
Path povadMarkPath() => Path()
  ..moveTo(17, 52)
  ..lineTo(17, 25)
  ..cubicTo(17, 16, 24, 11, 33, 11)
  ..lineTo(36, 11)
  ..cubicTo(44, 11, 49, 17, 49, 24)
  ..cubicTo(49, 31, 44, 37, 36, 37)
  ..lineTo(26, 37);

const povadSerialTerminal = Offset(17, 52);
const povadTcpTerminal = Offset(26, 37);
const _stroke = 7.3;

class _MarkPainter extends CustomPainter {
  const _MarkPainter({
    required this.ink,
    required this.firstPoint,
    required this.secondPoint,
    required this.activeInk,
    required this.activeProgress,
    required this.serialSignalProgress,
    required this.tcpSignalProgress,
    required this.showPoints,
    required this.glow,
    required this.fillHead,
    required this.transitProgress,
    required this.transitReverse,
  });

  final Color ink, firstPoint, secondPoint;
  final Color? activeInk;
  final double activeProgress;
  final double? serialSignalProgress, tcpSignalProgress;
  final bool showPoints;
  final double glow, fillHead;
  final double? transitProgress;
  final bool transitReverse;

  Paint _strokePaint(Color color, [double width = _stroke]) => Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    final scale = size.width / 64;
    canvas.scale(scale, size.height / 64);
    final path = povadMarkPath();
    final metric = path.computeMetrics().first;
    final active = activeInk;
    final progress = activeProgress.clamp(0.0, 1.0);

    if (active != null && progress > 0 && glow > 0) {
      // A soft halo under the confirmed path; static once a stage settles.
      canvas.drawPath(
        metric.extractPath(0, metric.length * progress),
        _strokePaint(active.withValues(alpha: 0.32 * glow), _stroke + 3)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 16 / scale),
      );
    }

    canvas.drawPath(path, _strokePaint(ink));

    if (active != null && progress > 0) {
      final confirmed = metric.extractPath(0, metric.length * progress);
      final highlight = Color.lerp(active, const Color(0xFFFFFFFF), 0.22)!;
      canvas.drawPath(
        confirmed,
        _strokePaint(active)
          ..shader = LinearGradient(
            begin: Alignment.bottomLeft,
            end: Alignment.topRight,
            colors: [active, highlight],
          ).createShader(const Rect.fromLTWH(10, 4, 46, 52)),
      );
      if (fillHead > 0 && progress < 1) {
        final tangent = metric.getTangentForOffset(metric.length * progress);
        if (tangent != null) _drawSpark(canvas, tangent.position, fillHead);
      }
    }

    final transit = transitProgress;
    if (transit != null) {
      _drawComet(
        canvas,
        metric,
        transitReverse ? 1 - transit : transit,
        transitReverse,
        active ?? ink,
        length: 0.26,
        width: _stroke,
      );
    }

    if (active != null) {
      if (serialSignalProgress != null) {
        _drawPacket(canvas, metric, serialSignalProgress!, false);
      }
      if (tcpSignalProgress != null) {
        _drawPacket(canvas, metric, tcpSignalProgress!, true);
      }
    }

    if (showPoints) {
      canvas.drawCircle(povadSerialTerminal, 5, Paint()..color = firstPoint);
      canvas.drawCircle(povadTcpTerminal, 5, Paint()..color = secondPoint);
    }
    canvas.restore();
  }

  void _drawSpark(
    Canvas canvas,
    Offset at,
    double strength, [
    Color halo = const Color(0xFFFFFFFF),
  ]) {
    canvas.drawCircle(
      at,
      5.5,
      Paint()
        ..color = halo.withValues(alpha: 0.6 * strength)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.drawCircle(
      at,
      2.1,
      Paint()
        ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.95 * strength),
    );
  }

  /// A tapered gradient trail. [head] is the leading edge on the path.
  void _drawComet(
    Canvas canvas,
    PathMetric metric,
    double head,
    bool reverse,
    Color color, {
    required double length,
    required double width,
  }) {
    const steps = 14;
    final direction = reverse ? 1.0 : -1.0;
    for (var i = steps - 1; i >= 0; i--) {
      final start = head + direction * length * (i + 1) / steps;
      final end = head + direction * length * i / steps;
      final a = math.min(start, end).clamp(0.0, 1.0);
      final b = math.max(start, end).clamp(0.0, 1.0);
      if (b - a <= 0) continue;
      final fade = 1 - i / steps;
      canvas.drawPath(
        metric.extractPath(metric.length * a, metric.length * b),
        _strokePaint(
          color.withValues(alpha: math.pow(fade, 1.6).toDouble()),
          width * (0.6 + 0.4 * fade),
        )..strokeCap = StrokeCap.butt,
      );
    }
    if (head >= 0 && head <= 1) {
      final tangent = metric.getTangentForOffset(metric.length * head);
      if (tangent != null) _drawSpark(canvas, tangent.position, 1, color);
    }
  }

  void _drawPacket(
    Canvas canvas,
    PathMetric metric,
    double progress,
    bool reverse,
  ) {
    final eased = Curves.easeInOutCubic.transform(progress.clamp(0.0, 1.0));
    final head = reverse ? 1 - eased : eased;
    // Fade in near the source and out at the destination terminal.
    final envelope = math.min(1.0, math.min(progress * 6, (1 - progress) * 6));
    const steps = 9;
    final direction = reverse ? 1.0 : -1.0;
    for (var i = steps - 1; i >= 0; i--) {
      final offset = head + direction * 0.016 * i;
      if (offset < 0 || offset > 1) continue;
      final tangent = metric.getTangentForOffset(metric.length * offset);
      if (tangent == null) continue;
      final fade = 1 - i / steps;
      canvas.drawCircle(
        tangent.position,
        i == 0 ? 2.0 : 1.0 + 0.9 * fade,
        Paint()
          ..color = const Color(
            0xFFFFFFFF,
          ).withValues(alpha: envelope * (i == 0 ? 1.0 : 0.55 * fade * fade)),
      );
    }
    final tangent = metric.getTangentForOffset(metric.length * head);
    if (tangent != null) {
      canvas.drawCircle(
        tangent.position,
        4.6,
        Paint()
          ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.42 * envelope)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.6),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MarkPainter old) =>
      old.ink != ink ||
      old.firstPoint != firstPoint ||
      old.secondPoint != secondPoint ||
      old.activeInk != activeInk ||
      old.activeProgress != activeProgress ||
      old.serialSignalProgress != serialSignalProgress ||
      old.tcpSignalProgress != tcpSignalProgress ||
      old.showPoints != showPoints ||
      old.glow != glow ||
      old.fillHead != fillHead ||
      old.transitProgress != transitProgress ||
      old.transitReverse != transitReverse;
}
