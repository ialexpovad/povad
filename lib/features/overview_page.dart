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
    required this.state,
    required this.onAction,
    required this.onPreviewState,
  });
  final BridgeViewState state;
  final VoidCallback onAction;
  final ValueChanged<BridgeViewState> onPreviewState;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final colors = paletteOf(context);
    final copy = StateCopy.of(state, l);
    final active = [
      BridgeViewState.starting,
      BridgeViewState.listening,
      BridgeViewState.connected,
      BridgeViewState.stopping,
    ].contains(state);
    final statusColor = state == BridgeViewState.error
        ? colors.error
        : active
        ? colors.primary
        : colors.muted;
    final canAct =
        kDebugMode &&
        state != BridgeViewState.starting &&
        state != BridgeViewState.stopping;
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 480;
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            narrow ? 16 : 32,
            28,
            narrow ? 16 : 32,
            40,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l.moduleName.toUpperCase(),
                    style: TextStyle(
                      fontSize: 12,
                      letterSpacing: 1.6,
                      fontWeight: FontWeight.w700,
                      color: colors.primary,
                    ),
                  ),
                  const SizedBox(height: 9),
                  Text(
                    l.pageTitle,
                    style: TextStyle(
                      fontSize: narrow ? 26 : 30,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.6,
                      color: colors.foreground,
                    ),
                  ),
                  const SizedBox(height: 20),
                  PreviewNotice(label: l.previewNotice),
                  const SizedBox(height: 16),
                  shad.Card(
                    padding: EdgeInsets.zero,
                    borderColor: colors.border,
                    borderRadius: BorderRadius.circular(14),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                            narrow ? 18 : 28,
                            24,
                            narrow ? 18 : 28,
                            0,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  l.connectionStatus.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.2,
                                    color: colors.muted,
                                  ),
                                ),
                              ),
                              DecoratedBox(
                                decoration: BoxDecoration(
                                  border: Border.all(color: statusColor),
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 11,
                                    vertical: 6,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 9,
                                        height: 9,
                                        decoration: BoxDecoration(
                                          color: statusColor,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 7),
                                      Text(
                                        copy.badge,
                                        style: TextStyle(
                                          color: statusColor,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: narrow ? 8 : 30,
                          ),
                          child: ConnectionDiagram(state: state),
                        ),
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                            narrow ? 18 : 32,
                            0,
                            narrow ? 18 : 32,
                            26,
                          ),
                          child: Column(
                            children: [
                              Semantics(
                                liveRegion: true,
                                child: Text(
                                  copy.title,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w700,
                                    color: colors.foreground,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 9),
                              Text(
                                copy.description,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: colors.muted,
                                  height: 1.45,
                                ),
                              ),
                              const SizedBox(height: 25),
                              SizedBox(
                                width: 190,
                                height: 48,
                                child:
                                    state == BridgeViewState.listening ||
                                        state == BridgeViewState.connected
                                    ? shad.OutlineButton(
                                        onPressed: canAct ? onAction : null,
                                        child: Center(child: Text(copy.action)),
                                      )
                                    : shad.PrimaryButton(
                                        onPressed: canAct ? onAction : null,
                                        child: Center(child: Text(copy.action)),
                                      ),
                              ),
                            ],
                          ),
                        ),
                        Container(height: 1, color: colors.border),
                        if (narrow)
                          Column(
                            children: [
                              Endpoint(
                                icon: shad.LucideIcons.usb,
                                label: l.serialDevice,
                                value: l.serialValue,
                              ),
                              Container(height: 1, color: colors.border),
                              Endpoint(
                                icon: shad.LucideIcons.globe,
                                label: l.tcpListener,
                                value: l.tcpValue,
                              ),
                            ],
                          )
                        else
                          Row(
                            children: [
                              Expanded(
                                child: Endpoint(
                                  icon: shad.LucideIcons.usb,
                                  label: l.serialDevice,
                                  value: l.serialValue,
                                ),
                              ),
                              Container(
                                height: 72,
                                width: 1,
                                color: colors.border,
                              ),
                              Expanded(
                                child: Endpoint(
                                  icon: shad.LucideIcons.globe,
                                  label: l.tcpListener,
                                  value: l.tcpValue,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  if (kDebugMode) ...[
                    const SizedBox(height: 24),
                    Text(
                      l.previewStates,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: colors.muted,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final candidate in BridgeViewState.values)
                          candidate == state
                              ? shad.PrimaryButton(
                                  onPressed: () => onPreviewState(candidate),
                                  child: Text(StateCopy.of(candidate, l).badge),
                                )
                              : shad.OutlineButton(
                                  onPressed: () => onPreviewState(candidate),
                                  child: Text(StateCopy.of(candidate, l).badge),
                                ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 18),
                  Text(
                    l.stateDisclaimer,
                    style: TextStyle(fontSize: 12, color: colors.muted),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class Endpoint extends StatelessWidget {
  const Endpoint({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label, value;
  @override
  Widget build(BuildContext context) {
    final colors = paletteOf(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 23, vertical: 16),
      child: Row(
        children: [
          Icon(icon, size: 26, color: colors.foreground),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 0.7,
                    color: colors.muted,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
