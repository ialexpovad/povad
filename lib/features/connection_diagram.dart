import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../design/povad_mark.dart';
import '../design/povad_theme.dart';
import '../domain/bridge_view_state.dart';
import '../l10n/generated/app_localizations.dart';

/// A quiet connection signal with the Povad core at its centre.
/// Lines light up only after the worker confirms each connection stage.
class ConnectionDiagram extends StatefulWidget {
  const ConnectionDiagram({super.key, required this.state});

  final BridgeViewState state;

  @override
  State<ConnectionDiagram> createState() => _ConnectionDiagramState();
}

class _ConnectionDiagramState extends State<ConnectionDiagram>
    with SingleTickerProviderStateMixin {
  late final AnimationController pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1150),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncMotion();
  }

  @override
  void didUpdateWidget(covariant ConnectionDiagram oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state) _syncMotion();
  }

  void _syncMotion() {
    final platformMotion = WidgetsBinding
        .instance
        .platformDispatcher
        .accessibilityFeatures
        .reduceMotion;
    final noMotion =
        (MediaQuery.maybeOf(context)?.disableAnimations ?? false) ||
        platformMotion;
    final transitional =
        widget.state == BridgeViewState.starting ||
        widget.state == BridgeViewState.stopping;
    if (transitional && !noMotion) {
      if (!pulse.isAnimating) pulse.repeat(reverse: true);
    } else {
      pulse.stop();
      pulse.value = 0;
    }
  }

  @override
  void dispose() {
    pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = paletteOf(context);
    final label = AppLocalizations.of(context)!.connectionDiagram;
    final serialReady =
        widget.state == BridgeViewState.listening ||
        widget.state == BridgeViewState.connected;
    final clientReady = widget.state == BridgeViewState.connected;
    final fault = widget.state == BridgeViewState.error;
    final pointColor = fault ? colors.error : colors.primary;
    return Semantics(
      label: label,
      child: ExcludeSemantics(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 340),
            child: SizedBox(
              width: 340,
              height: 126,
              child: AnimatedBuilder(
                animation: pulse,
                builder: (context, child) => Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _ConnectionLines(
                          inactive: colors.border,
                          active: colors.primary,
                          serialReady: serialReady,
                          clientReady: clientReady,
                        ),
                      ),
                    ),
                    Positioned(
                      left: 7,
                      child: _EndpointDot(
                        color: serialReady ? colors.primary : colors.inactive,
                        background: colors.background,
                      ),
                    ),
                    Positioned(
                      right: 7,
                      child: _EndpointDot(
                        color: clientReady ? colors.primary : colors.inactive,
                        background: colors.background,
                      ),
                    ),
                    Container(
                      width: 108,
                      height: 108,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFFFF),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: fault
                              ? colors.error
                              : serialReady || clientReady
                              ? colors.primary
                              : colors.border,
                          width: 1.5,
                        ),
                        boxShadow: [
                          if (pulse.isAnimating)
                            BoxShadow(
                              color: pointColor.withValues(
                                alpha: ui.lerpDouble(0.04, 0.16, pulse.value)!,
                              ),
                              blurRadius: ui.lerpDouble(12, 24, pulse.value)!,
                              spreadRadius: ui.lerpDouble(1, 4, pulse.value)!,
                            ),
                        ],
                      ),
                      child: Center(
                        child: PovadMark(
                          size: 76,
                          ink: const Color(0xFF18181B),
                          firstPoint: fault
                              ? colors.error
                              : serialReady || pulse.isAnimating
                              ? colors.primary
                              : colors.inactive,
                          secondPoint: fault
                              ? colors.error
                              : clientReady || pulse.isAnimating
                              ? colors.primary
                              : colors.inactive,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EndpointDot extends StatelessWidget {
  const _EndpointDot({required this.color, required this.background});

  final Color color, background;

  @override
  Widget build(BuildContext context) => Container(
    width: 21,
    height: 21,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: background,
      border: Border.all(color: color, width: 2.5),
    ),
    child: Center(
      child: Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    ),
  );
}

class _ConnectionLines extends CustomPainter {
  const _ConnectionLines({
    required this.inactive,
    required this.active,
    required this.serialReady,
    required this.clientReady,
  });

  final Color inactive, active;
  final bool serialReady, clientReady;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    final line = Paint()
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(27, y),
      Offset(size.width / 2 - 54, y),
      line..color = serialReady ? active : inactive,
    );
    canvas.drawLine(
      Offset(size.width / 2 + 54, y),
      Offset(size.width - 27, y),
      line..color = clientReady ? active : inactive,
    );
  }

  @override
  bool shouldRepaint(covariant _ConnectionLines oldDelegate) =>
      oldDelegate.inactive != inactive ||
      oldDelegate.active != active ||
      oldDelegate.serialReady != serialReady ||
      oldDelegate.clientReady != clientReady;
}
