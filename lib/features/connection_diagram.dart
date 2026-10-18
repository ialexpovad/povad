import 'package:flutter/widgets.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shad;

import '../design/povad_theme.dart';
import '../domain/bridge_view_state.dart';
import '../l10n/generated/app_localizations.dart';

class ConnectionDiagram extends StatelessWidget {
  const ConnectionDiagram({super.key, required this.state});
  final BridgeViewState state;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final colors = paletteOf(context);
    final left = [
      BridgeViewState.listening,
      BridgeViewState.connected,
      BridgeViewState.stopping,
    ].contains(state);
    final right = state == BridgeViewState.connected;
    final middle = state == BridgeViewState.starting || left;
    final labels = [l.serialLabel, l.bridgeLabel, l.clientLabel];
    const icons = [
      shad.LucideIcons.usb,
      shad.LucideIcons.cable,
      shad.LucideIcons.computer,
    ];
    final labelSize = MediaQuery.textScalerOf(context).scale(11);
    return Semantics(
      label: l.connectionDiagram,
      child: SizedBox(
        height: 122 + labelSize * 2,
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: WirePainter(
                  active: colors.primary,
                  inactive: colors.border,
                  left: left,
                  right: right,
                ),
              ),
            ),
            Row(
              children: [
                for (var i = 0; i < 3; i++)
                  Expanded(
                    child: Column(
                      children: [
                        const SizedBox(height: 22),
                        Container(
                          width: 66,
                          height: 66,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: colors.surface,
                            border: Border.all(
                              width: 2,
                              color: state == BridgeViewState.error && i == 1
                                  ? colors.error
                                  : (i == 0 && left ||
                                        i == 1 && middle ||
                                        i == 2 && right)
                                  ? colors.primary
                                  : colors.inactive,
                            ),
                          ),
                          child: Icon(
                            icons[i],
                            size: 26,
                            color: state == BridgeViewState.error && i == 1
                                ? colors.error
                                : (i == 0 && left ||
                                      i == 1 && middle ||
                                      i == 2 && right)
                                ? colors.primary
                                : colors.muted,
                          ),
                        ),
                        const SizedBox(height: 13),
                        Text(
                          labels[i],
                          maxLines: 2,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: colors.muted,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class WirePainter extends CustomPainter {
  const WirePainter({
    required this.active,
    required this.inactive,
    required this.left,
    required this.right,
  });
  final Color active, inactive;
  final bool left, right;
  @override
  void paint(Canvas canvas, Size size) {
    final third = size.width / 3;
    final paint = Paint()
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(third / 2 + 34, 55),
      Offset(size.width / 2 - 34, 55),
      paint..color = left ? active : inactive,
    );
    canvas.drawLine(
      Offset(size.width / 2 + 34, 55),
      Offset(size.width - third / 2 - 34, 55),
      paint..color = right ? active : inactive,
    );
  }

  @override
  bool shouldRepaint(covariant WirePainter old) =>
      old.active != active ||
      old.inactive != inactive ||
      old.left != left ||
      old.right != right;
}
