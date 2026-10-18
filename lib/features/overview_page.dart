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
    required this.state,
    required this.onAction,
    this.previewMode = true,
    this.configured = true,
    this.serialValue,
    this.tcpValue,
  });

  final BridgeViewState state;
  final VoidCallback onAction;
  final bool previewMode, configured;
  final String? serialValue, tcpValue;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final colors = paletteOf(context);
    final copy = StateCopy.of(state, l);
    final busy =
        state == BridgeViewState.starting || state == BridgeViewState.stopping;
    final active =
        state == BridgeViewState.listening ||
        state == BridgeViewState.connected;
    final actionLabel = state == BridgeViewState.stopped && !configured
        ? l.configureBridge
        : copy.action;

    return LayoutBuilder(
      builder: (context, box) {
        final narrow = box.maxWidth < 480;
        final padding = narrow ? 22.0 : 36.0;
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(padding, 28, padding, 32),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: (box.maxHeight - 60).clamp(0, double.infinity),
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 530),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (previewMode) ...[
                      Center(child: PreviewNotice(label: l.previewNotice)),
                      const SizedBox(height: 18),
                    ],
                    ConnectionDiagram(state: state),
                    const SizedBox(height: 18),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        copy.title,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: state == BridgeViewState.error
                              ? colors.error
                              : colors.foreground,
                          fontSize: narrow ? 28 : 32,
                          height: 1.15,
                          letterSpacing: -0.8,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      copy.description,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: colors.muted,
                        fontSize: 14,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 28),
                    Center(
                      child: SizedBox(
                        width: 224,
                        height: 50,
                        child: active || state == BridgeViewState.error
                            ? shad.OutlineButton(
                                onPressed: busy ? null : onAction,
                                child: Center(child: Text(actionLabel)),
                              )
                            : shad.PrimaryButton(
                                onPressed: busy ? null : onAction,
                                child: Center(child: Text(actionLabel)),
                              ),
                      ),
                    ),
                    const SizedBox(height: 42),
                    _EndpointSummary(
                      serialLabel: l.serialLabel,
                      serialValue: serialValue ?? l.serialValue,
                      tcpLabel: l.tcpListener,
                      tcpValue: tcpValue ?? l.tcpValue,
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

class _EndpointSummary extends StatelessWidget {
  const _EndpointSummary({
    required this.serialLabel,
    required this.serialValue,
    required this.tcpLabel,
    required this.tcpValue,
  });

  final String serialLabel, serialValue, tcpLabel, tcpValue;

  @override
  Widget build(BuildContext context) {
    final colors = paletteOf(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
        child: Row(
          children: [
            Expanded(
              child: _Endpoint(
                icon: shad.LucideIcons.usb,
                label: serialLabel,
                value: serialValue,
              ),
            ),
            Container(
              width: 1,
              height: 38,
              margin: const EdgeInsets.symmetric(horizontal: 14),
              color: colors.border,
            ),
            Expanded(
              child: _Endpoint(
                icon: shad.LucideIcons.globe,
                label: tcpLabel,
                value: tcpValue,
              ),
            ),
          ],
        ),
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
        Icon(icon, size: 18, color: colors.muted),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: colors.muted, fontSize: 11),
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

  factory StateCopy.of(BridgeViewState state, AppLocalizations l) =>
      switch (state) {
        BridgeViewState.stopped => StateCopy(
          l.stopped,
          l.stoppedTitle,
          l.stoppedDescription,
          l.startBridge,
        ),
        BridgeViewState.starting => StateCopy(
          l.starting,
          l.startingTitle,
          l.startingDescription,
          l.startingAction,
        ),
        BridgeViewState.listening => StateCopy(
          l.listening,
          l.listeningTitle,
          l.listeningDescription,
          l.stopBridge,
        ),
        BridgeViewState.connected => StateCopy(
          l.connected,
          l.connectedTitle,
          l.connectedDescription,
          l.stopBridge,
        ),
        BridgeViewState.stopping => StateCopy(
          l.stopping,
          l.stoppingTitle,
          l.stoppingDescription,
          l.stoppingAction,
        ),
        BridgeViewState.error => StateCopy(
          l.error,
          l.errorTitle,
          l.errorDescription,
          l.reviewDetails,
        ),
      };
}
