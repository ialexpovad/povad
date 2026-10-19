import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shad;

import '../design/povad_mark.dart';
import '../design/povad_theme.dart';
import '../domain/bridge_view_state.dart';
import '../l10n/generated/app_localizations.dart';

const _box = 212.0;
const _markSize = 192.0;
const _markScale = _markSize / 64;
const _markOrigin = (_box - _markSize) / 2;

Offset _onBox(Offset markPoint) =>
    Offset(_markOrigin, _markOrigin) + markPoint * _markScale;

/// The brand mark shows confirmed connection stages, never inferred data flow.
///
/// Motion is tied to native facts: the confirmed path grows when the worker
/// reports a stage, a comet runs only while it starts or stops, and a pulse
/// travels only when a received-byte counter increases. A settled session is
/// still. Reduced-motion preferences remove every animation.
class ConnectionDiagram extends StatefulWidget {
  const ConnectionDiagram({
    super.key,
    required this.state,
    this.animateConnection = true,
    this.tcpReceived = 0,
    this.serialReceived = 0,
  });

  final BridgeViewState state;
  final bool animateConnection;
  final int tcpReceived, serialReceived;

  @override
  State<ConnectionDiagram> createState() => _ConnectionDiagramState();
}

enum _RippleSite { serial, tcp, both }

class _ConnectionDiagramState extends State<ConnectionDiagram>
    with TickerProviderStateMixin {
  late final AnimationController fill = AnimationController(
    vsync: this,
    value: _targetFill(widget.state),
  );
  late final AnimationController transit = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  );
  late final AnimationController ripple = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );
  late final AnimationController shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  );
  late final AnimationController serialSignal = _signalController(
    () => serialPending,
    () => serialPending = false,
  );
  late final AnimationController tcpSignal = _signalController(
    () => tcpPending,
    () => tcpPending = false,
  );
  bool serialPending = false;
  bool tcpPending = false;
  _RippleSite rippleSite = _RippleSite.serial;
  double rippleDelay = 0;

  AnimationController _signalController(
    bool Function() pending,
    VoidCallback clear,
  ) {
    late final AnimationController controller;
    controller =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 950),
        )..addStatusListener((status) {
          if (status == AnimationStatus.completed && pending()) {
            clear();
            controller.forward(from: 0);
          }
        });
    return controller;
  }

  static double _targetFill(BridgeViewState state) => switch (state) {
    BridgeViewState.listening => 0.54,
    BridgeViewState.connected => 1,
    _ => 0,
  };

  bool get reduceMotion =>
      !widget.animateConnection ||
      (MediaQuery.maybeOf(context)?.disableAnimations ?? false) ||
      WidgetsBinding
          .instance
          .platformDispatcher
          .accessibilityFeatures
          .reduceMotion;

  void _queueSignal(AnimationController controller, bool serial) {
    if (reduceMotion || widget.state != BridgeViewState.connected) return;
    if (controller.isAnimating) {
      if (serial) {
        serialPending = true;
      } else {
        tcpPending = true;
      }
    } else {
      controller.forward(from: 0);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncMotion();
  }

  @override
  void didUpdateWidget(covariant ConnectionDiagram oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state) {
      _onStage(oldWidget.state, widget.state);
      _syncMotion();
    }
    if (oldWidget.animateConnection != widget.animateConnection) {
      _syncMotion();
    }
    if (widget.serialReceived > oldWidget.serialReceived) {
      _queueSignal(serialSignal, true);
    }
    if (widget.tcpReceived > oldWidget.tcpReceived) {
      _queueSignal(tcpSignal, false);
    }
  }

  void _onStage(BridgeViewState from, BridgeViewState to) {
    final target = _targetFill(to);
    if (reduceMotion) {
      fill.value = target;
      return;
    }
    final growing = target > fill.value;
    fill.animateTo(
      target,
      duration: Duration(milliseconds: growing ? 820 : 620),
      curve: growing ? Curves.easeInOutCubic : Curves.easeInCubic,
    );
    switch (to) {
      case BridgeViewState.listening when from != BridgeViewState.connected:
        _ripple(_RippleSite.serial);
      case BridgeViewState.connected:
        _ripple(_RippleSite.tcp);
      case BridgeViewState.error:
        _ripple(_RippleSite.both);
        shake.forward(from: 0);
      default:
        break;
    }
  }

  void _ripple(_RippleSite site) {
    rippleSite = site;
    // A confirmation ring waits for the growing path to reach its terminal.
    rippleDelay = site == _RippleSite.both ? 0 : 0.34;
    ripple.forward(from: 0);
  }

  void _syncMotion() {
    final transitional =
        widget.state == BridgeViewState.starting ||
        widget.state == BridgeViewState.stopping;
    if (transitional && !reduceMotion) {
      if (!transit.isAnimating) transit.repeat();
    } else {
      transit.stop();
      transit.value = 0;
    }
    if (reduceMotion) {
      fill.value = _targetFill(widget.state);
      ripple.value = 0;
      shake.value = 0;
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
    fill.dispose();
    transit.dispose();
    ripple.dispose();
    shake.dispose();
    serialSignal.dispose();
    tcpSignal.dispose();
    super.dispose();
  }

  /// A short bell-shaped flash when a pulse reaches its destination terminal.
  static double _arrival(AnimationController signal) {
    if (!signal.isAnimating) return 0;
    final t = signal.value;
    if (t < 0.82) return 0;
    return math.sin(math.pi * ((t - 0.82) / 0.18).clamp(0.0, 1.0));
  }

  @override
  Widget build(BuildContext context) {
    final colors = paletteOf(context);
    final state = widget.state;
    final serialReady =
        state == BridgeViewState.listening ||
        state == BridgeViewState.connected;
    final clientReady = state == BridgeViewState.connected;
    final fault = state == BridgeViewState.error;
    final badgeDuration = reduceMotion
        ? Duration.zero
        : const Duration(milliseconds: 380);

    return Semantics(
      label: AppLocalizations.of(context)!.connectionDiagram,
      child: ExcludeSemantics(
        child: Center(
          child: SizedBox.square(
            dimension: _box,
            child: AnimatedBuilder(
              animation: Listenable.merge([
                fill,
                transit,
                ripple,
                shake,
                serialSignal,
                tcpSignal,
              ]),
              builder: (context, _) {
                final t = shake.value;
                final dx = shake.isAnimating
                    ? math.sin(t * math.pi * 7) * (1 - t) * 7
                    : 0.0;
                final transitional =
                    state == BridgeViewState.starting ||
                    state == BridgeViewState.stopping;
                return Transform.translate(
                  offset: Offset(dx, 0),
                  child: CustomPaint(
                    painter: _Backdrop(
                      primary: colors.primary,
                      error: colors.error,
                      halo: fill.value,
                      ripple: ripple.isAnimating
                          ? ((ripple.value - rippleDelay) / (1 - rippleDelay))
                          : null,
                      rippleSite: rippleSite,
                      fault: fault,
                    ),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Center(
                          child: PovadMark(
                            size: _markSize,
                            showPoints: false,
                            ink: colors.foreground,
                            activeInk: colors.primary,
                            activeProgress: fill.value,
                            glow: 1,
                            fillHead:
                                fill.isAnimating &&
                                    fill.status == AnimationStatus.forward
                                ? 1
                                : 0,
                            transitProgress: transitional && transit.isAnimating
                                ? Curves.easeInOutSine.transform(transit.value)
                                : null,
                            transitReverse: state == BridgeViewState.stopping,
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
                        _positioned(
                          povadSerialTerminal,
                          _TerminalBadge(
                            icon: shad.LucideIcons.usb,
                            duration: badgeDuration,
                            tone: fault
                                ? _Tone.fault
                                : serialReady
                                ? _Tone.active
                                : _Tone.idle,
                            flash: _arrival(tcpSignal),
                          ),
                        ),
                        _positioned(
                          povadTcpTerminal,
                          _TerminalBadge(
                            icon: shad.LucideIcons.network,
                            duration: badgeDuration,
                            tone: fault
                                ? _Tone.fault
                                : clientReady
                                ? _Tone.active
                                : _Tone.idle,
                            flash: _arrival(serialSignal),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _positioned(Offset markPoint, Widget badge) {
    final center = _onBox(markPoint);
    return Positioned(
      left: center.dx - _TerminalBadge.size / 2,
      top: center.dy - _TerminalBadge.size / 2,
      child: badge,
    );
  }
}

class _Backdrop extends CustomPainter {
  const _Backdrop({
    required this.primary,
    required this.error,
    required this.halo,
    required this.ripple,
    required this.rippleSite,
    required this.fault,
  });

  final Color primary, error;
  final double halo;
  final double? ripple;
  final _RippleSite rippleSite;
  final bool fault;

  @override
  void paint(Canvas canvas, Size size) {
    if (halo > 0) {
      final center = size.center(const Offset(4, 0));
      final radius = size.width * 0.62;
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..shader = ui.Gradient.radial(
            center,
            radius,
            [
              primary.withValues(alpha: 0.13 * halo),
              primary.withValues(alpha: 0.05 * halo),
              primary.withValues(alpha: 0),
            ],
            const [0, 0.55, 1],
          ),
      );
    }
    final progress = ripple;
    if (progress == null) return;
    final color = fault ? error : primary;
    final sites = switch (rippleSite) {
      _RippleSite.serial => [povadSerialTerminal],
      _RippleSite.tcp => [povadTcpTerminal],
      _RippleSite.both => [povadSerialTerminal, povadTcpTerminal],
    };
    for (final site in sites) {
      final center = _onBox(site);
      for (final lag in const [0.0, 0.22]) {
        final t = ((progress - lag) / (1 - lag)).clamp(0.0, 1.0);
        if (t <= 0 || t >= 1) continue;
        final eased = Curves.easeOutCubic.transform(t);
        canvas.drawCircle(
          center,
          ui.lerpDouble(14, 46, eased)!,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = ui.lerpDouble(2.4, 0.6, eased)!
            ..color = color.withValues(alpha: 0.55 * (1 - eased)),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _Backdrop old) =>
      old.primary != primary ||
      old.error != error ||
      old.halo != halo ||
      old.ripple != ripple ||
      old.rippleSite != rippleSite ||
      old.fault != fault;
}

enum _Tone { idle, active, fault }

class _TerminalBadge extends StatelessWidget {
  const _TerminalBadge({
    required this.icon,
    required this.tone,
    required this.duration,
    this.flash = 0,
  });

  static const size = 28.0;

  final IconData icon;
  final _Tone tone;
  final Duration duration;
  final double flash;

  @override
  Widget build(BuildContext context) {
    final colors = paletteOf(context);
    final accent = switch (tone) {
      _Tone.idle => colors.inactive,
      _Tone.active => colors.primary,
      _Tone.fault => colors.error,
    };
    final filled = tone == _Tone.active;
    return Transform.scale(
      scale: 1 + 0.2 * flash,
      child: AnimatedContainer(
        duration: duration,
        curve: Curves.easeOutCubic,
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: filled ? accent : colors.background,
          shape: BoxShape.circle,
          border: Border.all(
            color: filled ? colors.background : accent,
            width: filled ? 2.5 : 1.6,
          ),
          boxShadow: [
            if (filled)
              BoxShadow(
                color: accent.withValues(alpha: 0.35 + 0.4 * flash),
                blurRadius: 10 + 10 * flash,
              ),
          ],
        ),
        child: Center(
          child: Icon(
            icon,
            size: 14,
            color: filled ? colors.onPrimary : accent,
          ),
        ),
      ),
    );
  }
}
