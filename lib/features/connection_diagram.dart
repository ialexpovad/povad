import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shad;

import '../design/povad_mark.dart';
import '../design/povad_theme.dart';
import '../domain/bridge_view_state.dart';
import '../l10n/generated/app_localizations.dart';

/// The brand mark shows confirmed connection stages, never inferred data flow.
class ConnectionDiagram extends StatefulWidget {
  const ConnectionDiagram({
    super.key,
    required this.state,
    this.tcpReceived = 0,
    this.serialReceived = 0,
  });

  final BridgeViewState state;
  final int tcpReceived, serialReceived;

  @override
  State<ConnectionDiagram> createState() => _ConnectionDiagramState();
}

class _ConnectionDiagramState extends State<ConnectionDiagram>
    with TickerProviderStateMixin {
  late final AnimationController pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );
  late final AnimationController serialSignal =
      AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 900),
      )..addStatusListener((status) {
        if (status == AnimationStatus.completed && serialPending) {
          serialPending = false;
          serialSignal.forward(from: 0);
        }
      });
  late final AnimationController tcpSignal =
      AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 900),
      )..addStatusListener((status) {
        if (status == AnimationStatus.completed && tcpPending) {
          tcpPending = false;
          tcpSignal.forward(from: 0);
        }
      });
  bool serialPending = false;
  bool tcpPending = false;

  void _queueSerialSignal() {
    if (reduceMotion || widget.state != BridgeViewState.connected) return;
    if (serialSignal.isAnimating) {
      serialPending = true;
    } else {
      serialSignal.forward(from: 0);
    }
  }

  void _queueTcpSignal() {
    if (reduceMotion || widget.state != BridgeViewState.connected) return;
    if (tcpSignal.isAnimating) {
      tcpPending = true;
    } else {
      tcpSignal.forward(from: 0);
    }
  }

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
    if (widget.serialReceived > oldWidget.serialReceived) {
      _queueSerialSignal();
    }
    if (widget.tcpReceived > oldWidget.tcpReceived) {
      _queueTcpSignal();
    }
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
    if (reduceMotion || widget.state != BridgeViewState.connected) {
      serialSignal.stop();
      tcpSignal.stop();
      serialPending = false;
      tcpPending = false;
    }
  }

  @override
  void dispose() {
    pulse.dispose();
    serialSignal.dispose();
    tcpSignal.dispose();
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
            dimension: 212,
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
                      animation: Listenable.merge([
                        pulse,
                        serialSignal,
                        tcpSignal,
                      ]),
                      builder: (context, child) => CustomPaint(
                        painter: _TerminalPulse(
                          color: colors.primary,
                          progress: pulse.value,
                          first: widget.state == BridgeViewState.starting,
                          second: widget.state == BridgeViewState.stopping,
                        ),
                        child: Stack(
                          children: [
                            Center(
                              child: PovadMark(
                                size: 192,
                                showPoints: false,
                                ink: colors.foreground,
                                activeInk: colors.primary,
                                activeProgress:
                                    0.54 * serialProgress +
                                    0.46 * clientProgress,
                                serialSignalProgress: serialSignal.isAnimating
                                    ? serialSignal.value
                                    : null,
                                tcpSignalProgress: tcpSignal.isAnimating
                                    ? tcpSignal.value
                                    : null,
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
                            Positioned(
                              left: 48,
                              top: 153,
                              child: _TerminalBadge(
                                icon: shad.LucideIcons.usb,
                                color: fault
                                    ? colors.error
                                    : serialReady
                                    ? colors.primary
                                    : colors.inactive,
                              ),
                            ),
                            Positioned(
                              left: 75,
                              top: 108,
                              child: _TerminalBadge(
                                icon: shad.LucideIcons.network,
                                color: fault
                                    ? colors.error
                                    : clientReady
                                    ? colors.primary
                                    : colors.inactive,
                              ),
                            ),
                          ],
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
    final markOrigin = (size.width - 192) / 2;
    final center = first
        ? Offset(markOrigin + 51, markOrigin + 156)
        : Offset(markOrigin + 78, markOrigin + 111);
    canvas.drawCircle(
      center,
      ui.lerpDouble(20, 29, progress)!,
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

class _TerminalBadge extends StatelessWidget {
  const _TerminalBadge({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = paletteOf(context);
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: colors.background,
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 1.5),
      ),
      child: Center(child: Icon(icon, size: 14, color: color)),
    );
  }
}
