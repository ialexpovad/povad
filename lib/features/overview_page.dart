import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shad;

import '../design/povad_theme.dart';
import '../design/preview_notice.dart';
import '../domain/bridge_view_state.dart';
import '../l10n/generated/app_localizations.dart';
import 'connection_diagram.dart';

class OverviewPage extends StatelessWidget {
  const OverviewPage({
    super.key,
    this.notice,
    required this.state,
    required this.onAction,
    this.previewMode = true,
    this.configured = true,
    this.serialValue,
    this.tcpValue,
    this.tcpReceived = 0,
    this.bleMode = false,
    this.blePaired = true,
    this.serialReceived = 0,
    this.animateConnection = true,
    this.detail,
    this.onDetails,
    this.onEditSetup,
    this.onHelp,
    this.onCopyEndpoint,
    this.endpointCopied = false,
  });

  /// An optional one-line notice above the mark, such as a ready update.
  final Widget? notice;
  final BridgeViewState state;
  final VoidCallback onAction;
  final bool previewMode, configured;
  final String? serialValue, tcpValue;
  final int tcpReceived, serialReceived;
  final bool bleMode;

  /// A BLE bridge that requires pairing (the words say "paired").
  final bool blePaired;
  final bool animateConnection;

  /// The worker's own explanation for an error or ended session.
  final String? detail;
  final VoidCallback? onDetails, onEditSetup, onCopyEndpoint, onHelp;
  final bool endpointCopied;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final colors = paletteOf(context);
    final copy = StateCopy.of(state, l, bleMode: bleMode, blePaired: blePaired);
    final busy =
        state == BridgeViewState.starting || state == BridgeViewState.stopping;
    final active =
        state == BridgeViewState.listening ||
        state == BridgeViewState.connected;
    final ended =
        state == BridgeViewState.error || state == BridgeViewState.interrupted;
    final actionLabel =
        !configured && (state == BridgeViewState.stopped || ended)
        ? l.configureBridge
        : copy.action;
    final context0 = ended && detail?.isNotEmpty == true
        ? detail!
        : state == BridgeViewState.stopped && !configured
        ? l.stoppedUnconfigured
        : copy.description;
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    const actionStyle = TextStyle(fontSize: 15, fontWeight: FontWeight.w600);
    final swap = reduce ? Duration.zero : const Duration(milliseconds: 260);

    return LayoutBuilder(
      builder: (context, box) {
        final narrow = box.maxWidth < 480;
        final padding = narrow ? 20.0 : 36.0;
        // A WARP-sized window keeps the whole view visible by giving up
        // some of the mark's size instead of scrolling the action away.
        final markScale = box.maxHeight < 580
            ? 0.72
            : box.maxHeight < 680
            ? 0.84
            : 1.0;
        final compact = markScale < 1;
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            padding,
            compact ? 12 : 24,
            padding,
            compact ? 16 : 32,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: (box.maxHeight - (compact ? 28 : 56)).clamp(
                0,
                double.infinity,
              ),
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (notice != null) ...[
                      Center(child: notice!),
                      SizedBox(height: compact ? 12 : 20),
                    ],
                    if (previewMode) ...[
                      Center(child: PreviewNotice(label: l.previewNotice)),
                      const SizedBox(height: 18),
                    ],
                    SizedBox(
                      height: 212 * markScale,
                      child: FittedBox(
                        child: SizedBox.square(
                          dimension: 212,
                          child: ConnectionDiagram(
                            animateConnection: animateConnection,
                            state: state,
                            tcpReceived: tcpReceived,
                            serialReceived: serialReceived,
                            bleMode: bleMode,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Semantics(
                      liveRegion: true,
                      child: _Swap(
                        duration: swap,
                        child: Text(
                          copy.title,
                          key: ValueKey(copy.title),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: state == BridgeViewState.error
                                ? colors.error
                                : colors.foreground,
                            fontSize: narrow ? 28 : 32,
                            height: 1.15,
                            letterSpacing: -0.9,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _Swap(
                      duration: swap,
                      child: Text(
                        context0,
                        key: ValueKey(context0),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.muted,
                          fontSize: 14,
                          height: 1.45,
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    Center(
                      child: SizedBox(
                        width: 224,
                        height: 50,
                        child: active
                            ? shad.OutlineButton(
                                onPressed: onAction,
                                child: Center(
                                  child: Text(actionLabel, style: actionStyle),
                                ),
                              )
                            : shad.PrimaryButton(
                                onPressed: busy ? null : onAction,
                                child: Center(
                                  child: Text(actionLabel, style: actionStyle),
                                ),
                              ),
                      ),
                    ),
                    if (state == BridgeViewState.error) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        alignment: WrapAlignment.center,
                        children: [
                          if (onHelp != null)
                            shad.GhostButton(
                              onPressed: onHelp,
                              leading: const Icon(
                                shad.LucideIcons.lifeBuoy,
                                size: 15,
                              ),
                              child: Text(l.howToFix),
                            ),
                          if (onDetails != null)
                            shad.GhostButton(
                              onPressed: onDetails,
                              child: Text(l.reviewDetails),
                            ),
                        ],
                      ),
                    ],
                    SizedBox(
                      height: state == BridgeViewState.error || compact
                          ? 24
                          : 40,
                    ),
                    _EndpointSummary(
                      serialLabel: l.serialLabel,
                      serialValue: serialValue ?? l.serialValue,
                      tcpLabel: bleMode ? l.blePeripheral : l.tcpListener,
                      tcpValue:
                          tcpValue ??
                          (bleMode
                              ? defaultTargetPlatform == TargetPlatform.windows
                                    ? l.bleWindowsComputerName
                                    : 'Povad BLE'
                              : l.tcpValue),
                      bleMode: bleMode,
                      onEdit: active || busy ? null : onEditSetup,
                      editLabel: l.editSetup,
                      onCopy: bleMode ? null : onCopyEndpoint,
                      copyLabel: l.copyTcpEndpoint,
                      copied: endpointCopied,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Cross-fades a status line with a short rise.
class _Swap extends StatelessWidget {
  const _Swap({required this.duration, required this.child});

  final Duration duration;
  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: duration,
    switchInCurve: Curves.easeOutCubic,
    switchOutCurve: Curves.easeInCubic,
    layoutBuilder: (current, previous) => Stack(
      alignment: Alignment.topCenter,
      children: [...previous, ?current],
    ),
    transitionBuilder: (child, animation) => FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween(
          begin: const Offset(0, 0.25),
          end: Offset.zero,
        ).animate(animation),
        child: child,
      ),
    ),
    child: child,
  );
}

class _EndpointSummary extends StatelessWidget {
  const _EndpointSummary({
    required this.serialLabel,
    required this.serialValue,
    required this.tcpLabel,
    required this.tcpValue,
    required this.bleMode,
    required this.editLabel,
    required this.copyLabel,
    this.onEdit,
    this.onCopy,
    this.copied = false,
  });

  final String serialLabel, serialValue, tcpLabel, tcpValue;
  final bool bleMode;
  final String editLabel, copyLabel;
  final VoidCallback? onEdit, onCopy;
  final bool copied;

  @override
  Widget build(BuildContext context) {
    final colors = paletteOf(context);
    final serial = _Endpoint(
      icon: shad.LucideIcons.usb,
      label: serialLabel,
      value: serialValue,
    );
    final tcp = _Endpoint(
      icon: bleMode ? shad.LucideIcons.radio : shad.LucideIcons.network,
      label: tcpLabel,
      value: tcpValue,
    );
    final Widget accessory = onCopy != null
        ? Semantics(
            label: copyLabel,
            button: true,
            child: shad.GhostButton(
              onPressed: onCopy,
              density: shad.ButtonDensity.icon,
              child: SizedBox.square(
                dimension: 22,
                child: Icon(
                  copied ? shad.LucideIcons.check : shad.LucideIcons.copy,
                  size: 16,
                  color: copied ? colors.primary : colors.muted,
                ),
              ),
            ),
          )
        : onEdit != null
        ? Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Icon(
              shad.LucideIcons.chevronRight,
              size: 18,
              color: colors.muted,
            ),
          )
        : const SizedBox(width: 6);
    final body = LayoutBuilder(
      builder: (context, box) {
        // Side by side when both values fit; stacked on phones so neither
        // the port nor the address is cut short.
        if (box.maxWidth >= 440) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
            child: Row(
              children: [
                Expanded(child: serial),
                Container(
                  width: 1,
                  height: 36,
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  color: colors.border,
                ),
                Expanded(child: tcp),
                accessory,
              ],
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    serial,
                    Container(
                      height: 1,
                      margin: const EdgeInsets.symmetric(vertical: 10),
                      color: colors.border,
                    ),
                    tcp,
                  ],
                ),
              ),
              const SizedBox(width: 4),
              accessory,
            ],
          ),
        );
      },
    );
    final decoration = BoxDecoration(
      color: colors.surface,
      border: Border.all(color: colors.border),
      borderRadius: BorderRadius.circular(14),
    );
    if (onEdit == null) {
      return DecoratedBox(decoration: decoration, child: body);
    }
    return Semantics(
      button: true,
      label: editLabel,
      child: shad.Clickable(
        onPressed: onEdit,
        mouseCursor: const WidgetStatePropertyAll(SystemMouseCursors.click),
        decoration: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.hovered) ||
                  states.contains(WidgetState.focused)
              ? decoration.copyWith(color: colors.subtle)
              : decoration,
        ),
        child: body,
      ),
    );
  }
}

class _Endpoint extends StatelessWidget {
  const _Endpoint({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label, value;

  @override
  Widget build(BuildContext context) {
    final colors = paletteOf(context);
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: colors.subtle,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, size: 16, color: colors.muted),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: colors.muted, fontSize: 11.5),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.foreground,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class StateCopy {
  const StateCopy(this.badge, this.title, this.description, this.action);

  final String badge, title, description, action;

  factory StateCopy.of(
    BridgeViewState state,
    AppLocalizations l, {
    bool bleMode = false,
    bool blePaired = true,
  }) => switch (state) {
    BridgeViewState.stopped => StateCopy(
      l.stopped,
      l.stoppedTitle,
      bleMode ? l.bleStoppedDescription : l.stoppedDescription,
      l.startBridge,
    ),
    BridgeViewState.starting => StateCopy(
      l.starting,
      l.startingTitle,
      bleMode ? l.bleStartingDescription : l.startingDescription,
      l.startingAction,
    ),
    BridgeViewState.listening => StateCopy(
      l.listening,
      l.listeningTitle,
      !bleMode
          ? l.listeningDescription
          : blePaired
          ? l.bleListeningDescription
          : l.bleOpenListeningDescription,
      l.stopBridge,
    ),
    BridgeViewState.connected => StateCopy(
      l.connected,
      l.connectedTitle,
      !bleMode
          ? l.connectedDescription
          : blePaired
          ? l.bleConnectedDescription
          : l.bleOpenConnectedDescription,
      l.stopBridge,
    ),
    BridgeViewState.stopping => StateCopy(
      l.stopping,
      l.stoppingTitle,
      l.stoppingDescription,
      l.stoppingAction,
    ),
    BridgeViewState.interrupted => StateCopy(
      l.interrupted,
      l.interruptedTitle,
      l.interruptedDescription,
      l.startAgain,
    ),
    BridgeViewState.error => StateCopy(
      l.error,
      l.errorTitle,
      l.errorDescription,
      l.startAgain,
    ),
  };
}

/// A compact pill with one action, used for update news on Overview.
class UpdateNotice extends StatelessWidget {
  const UpdateNotice({
    super.key,
    required this.icon,
    required this.text,
    required this.actionLabel,
    required this.onAction,
    this.error = false,
  });

  final IconData icon;
  final String text, actionLabel;
  final VoidCallback onAction;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final colors = paletteOf(context);
    final accent = error ? colors.error : colors.primary;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 5, 5, 5),
      decoration: BoxDecoration(
        color: error ? colors.errorSurface : colors.selection,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: accent),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: colors.foreground,
              ),
            ),
          ),
          const SizedBox(width: 8),
          shad.PrimaryButton(
            onPressed: onAction,
            density: shad.ButtonDensity.dense,
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}
