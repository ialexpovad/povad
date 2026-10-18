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
  });

  final double size;
  final Color ink, firstPoint, secondPoint;
  final Color? activeInk;
  final double activeProgress;
  final double? serialSignalProgress, tcpSignalProgress;
  final bool showPoints;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(
      painter: _MarkPainter(
        ink,
        firstPoint,
        secondPoint,
        activeInk,
        activeProgress,
        serialSignalProgress,
        tcpSignalProgress,
        showPoints,
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
    final markSize = compact ? 32.0 : 36.0;
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
                fontSize: compact ? 19 : 21,
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

class _MarkPainter extends CustomPainter {
  const _MarkPainter(
    this.ink,
    this.firstPoint,
    this.secondPoint,
    this.activeInk,
    this.activeProgress,
    this.serialSignalProgress,
    this.tcpSignalProgress,
    this.showPoints,
  );

  final Color ink, firstPoint, secondPoint;
  final Color? activeInk;
  final double activeProgress;
  final double? serialSignalProgress, tcpSignalProgress;
  final bool showPoints;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 64, size.height / 64);
    final path = Path()
      ..moveTo(17, 52)
      ..lineTo(17, 25)
      ..cubicTo(17, 16, 24, 11, 33, 11)
      ..lineTo(36, 11)
      ..cubicTo(44, 11, 49, 17, 49, 24)
      ..cubicTo(49, 31, 44, 37, 36, 37)
      ..lineTo(26, 37);
    canvas.drawPath(
      path,
      Paint()
        ..color = ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7.3
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    if (activeInk != null && activeProgress > 0) {
      final metric = path.computeMetrics().first;
      canvas.drawPath(
        metric.extractPath(0, metric.length * activeProgress.clamp(0, 1)),
        Paint()
          ..color = activeInk!
          ..style = PaintingStyle.stroke
          ..strokeWidth = 7.3
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }
    if (activeInk != null &&
        (serialSignalProgress != null || tcpSignalProgress != null)) {
      final metric = path.computeMetrics().first;
      if (serialSignalProgress != null) {
        _drawSignal(canvas, metric, serialSignalProgress!, false);
      }
      if (tcpSignalProgress != null) {
        _drawSignal(canvas, metric, tcpSignalProgress!, true);
      }
    }
    if (showPoints) {
      canvas.drawCircle(const Offset(17, 52), 5, Paint()..color = firstPoint);
      canvas.drawCircle(const Offset(26, 37), 5, Paint()..color = secondPoint);
    }
    canvas.restore();
  }

  void _drawSignal(
    Canvas canvas,
    PathMetric metric,
    double progress,
    bool reverse,
  ) {
    final head = reverse ? 1 - progress : progress;
    for (var index = 2; index >= 0; index--) {
      final offset = head + (reverse ? 1 : -1) * index * 0.045;
      if (offset < 0 || offset > 1) continue;
      final tangent = metric.getTangentForOffset(metric.length * offset);
      if (tangent == null) continue;
      canvas.drawCircle(
        tangent.position,
        index == 0 ? 1.7 : 1.2,
        Paint()
          ..color = const Color(0xFFFFFFFF)
              .withValues(alpha: index == 0 ? 0.95 : 0.38 - index * 0.1),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MarkPainter oldDelegate) =>
      oldDelegate.ink != ink ||
      oldDelegate.firstPoint != firstPoint ||
      oldDelegate.secondPoint != secondPoint ||
      oldDelegate.activeInk != activeInk ||
      oldDelegate.activeProgress != activeProgress ||
      oldDelegate.serialSignalProgress != serialSignalProgress ||
      oldDelegate.tcpSignalProgress != tcpSignalProgress ||
      oldDelegate.showPoints != showPoints;
}
