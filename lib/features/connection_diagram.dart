import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../design/povad_mark.dart';
import '../design/povad_theme.dart';
import '../domain/bridge_view_state.dart';
import '../l10n/generated/app_localizations.dart';

/// The brand mark shows confirmed connection stages, never inferred data flow.
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
    duration: const Duration(milliseconds: 1100),
  );

  bool get reduceMotion =>
      (MediaQuery.maybeOf(context)?.disableAnimations ?? false) ||
      WidgetsBinding
          .instance
          .platformDispatcher
          .accessibilityFeatures
          .reduceMotion;

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
    final transitional =
        widget.state == BridgeViewState.starting ||
        widget.state == BridgeViewState.stopping;
    if (transitional && !reduceMotion) {
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
    final serialReady =
        widget.state == BridgeViewState.listening ||
        widget.state == BridgeViewState.connected;
    final clientReady = widget.state == BridgeViewState.connected;
    final fault = widget.state == BridgeViewState.error;
    final transitionDuration = reduceMotion
        ? Duration.zero
        : const Duration(milliseconds: 420);

    return Semantics(
      label: AppLocalizations.of(context)!.connectionDiagram,
      child: ExcludeSemantics(
        child: Center(
          child: SizedBox.square(
            dimension: 148,
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: serialReady ? 1 : 0),
              duration: transitionDuration,
              curve: Curves.easeOutCubic,
              builder: (context, serialProgress, _) =>
                  TweenAnimationBuilder<double>(
                    tween: Tween(end: clientReady ? 1 : 0),
                    duration: transitionDuration,
                    curve: Curves.easeOutCubic,
                    builder: (context, clientProgress, _) => AnimatedBuilder(
                      animation: pulse,
                      builder: (context, child) => CustomPaint(
                        painter: _TerminalPulse(
                          color: colors.primary,
                          progress: pulse.value,
                          first: widget.state == BridgeViewState.starting,
                          second: widget.state == BridgeViewState.stopping,
                        ),
                        child: Center(
                          child: PovadMark(
                            size: 128,
                            ink: colors.foreground,
                            activeInk: colors.primary,
                            activeProgress:
                                0.54 * serialProgress + 0.46 * clientProgress,
                            firstPoint: fault
                                ? colors.error
                                : serialReady
                                ? colors.primary
                                : colors.inactive,
                            secondPoint: fault
                                ? colors.error
                                : clientReady
                                ? colors.primary
                                : colors.inactive,
                          ),
                        ),
                      ),
                    ),
                  ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TerminalPulse extends CustomPainter {
  const _TerminalPulse({
    required this.color,
    required this.progress,
    required this.first,
    required this.second,
  });

  final Color color;
  final double progress;
  final bool first, second;

  @override
  void paint(Canvas canvas, Size size) {
    if (!first && !second) return;
    final markOrigin = (size.width - 128) / 2;
    final center = first
        ? Offset(markOrigin + 34, markOrigin + 104)
        : Offset(markOrigin + 52, markOrigin + 74);
    canvas.drawCircle(
      center,
      ui.lerpDouble(14, 21, progress)!,
      Paint()
        ..color = color.withValues(alpha: ui.lerpDouble(0.16, 0.02, progress)!)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant _TerminalPulse old) =>
      old.color != color ||
      old.progress != progress ||
      old.first != first ||
      old.second != second;
}
