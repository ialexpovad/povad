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
  });

  final double size;
  final Color ink, firstPoint, secondPoint;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(painter: _MarkPainter(ink, firstPoint, secondPoint)),
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
  const _MarkPainter(this.ink, this.firstPoint, this.secondPoint);

  final Color ink, firstPoint, secondPoint;

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
    canvas.drawCircle(const Offset(17, 52), 5, Paint()..color = firstPoint);
    canvas.drawCircle(const Offset(26, 37), 5, Paint()..color = secondPoint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _MarkPainter oldDelegate) =>
      oldDelegate.ink != ink ||
      oldDelegate.firstPoint != firstPoint ||
      oldDelegate.secondPoint != secondPoint;
}
