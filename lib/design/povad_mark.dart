import 'package:flutter/widgets.dart';

import 'povad_theme.dart';

class PovadBrandLockup extends StatelessWidget {
  const PovadBrandLockup({super.key, this.compact = false, this.caption});

  final bool compact;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final palette = paletteOf(context);
    final fontSize = compact ? 19.0 : 23.0;
    final markHeight = fontSize * 1.22;
    final markWidth = markHeight * 0.66;
    return Semantics(
      label: 'Povad',
      child: ExcludeSemantics(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRect(
                  child: SizedBox(
                    width: markWidth,
                    height: markHeight,
                    child: CustomPaint(
                      painter: WordmarkPainter(
                        palette.foreground,
                        palette.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 2),
                Text(
                  'ovad',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: fontSize,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                    color: palette.foreground,
                  ),
                ),
              ],
            ),
            if (caption != null) ...[
              const SizedBox(height: 2),
              Padding(
                padding: EdgeInsets.only(left: markWidth + 2),
                child: Text(
                  caption!,
                  style: TextStyle(fontSize: 11, color: palette.muted),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class WordmarkPainter extends CustomPainter {
  const WordmarkPainter(this.foreground, this.primary);

  final Color foreground, primary;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.height / 64, size.height / 64);
    canvas.translate(-12, 0);
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
        ..color = foreground
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7.3
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    for (final point in [const Offset(17, 52), const Offset(26, 37)]) {
      canvas.drawCircle(point, 5, Paint()..color = primary);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant WordmarkPainter oldDelegate) =>
      oldDelegate.foreground != foreground || oldDelegate.primary != primary;
}
