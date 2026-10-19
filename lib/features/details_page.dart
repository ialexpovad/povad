import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shad;

import '../design/povad_components.dart';
import '../design/povad_theme.dart';
import '../domain/bridge_view_state.dart';
import '../l10n/generated/app_localizations.dart';
import 'overview_page.dart';

/// Native facts about the current or last session. Counters describe bytes
/// the worker received, not confirmed delivery or device health.
class DetailsPage extends StatefulWidget {
  const DetailsPage({
    super.key,
    required this.state,
    required this.previewMode,
    this.detail,
    this.hint,
    this.serialValue,
    this.baud,
    this.parity,
    this.endpoint,
    this.serialReceived = 0,
    this.tcpReceived = 0,
    this.sessionStartedAt,
    this.onStartAgain,
    this.onEditSetup,
    this.onPreviewState,
  });

  final BridgeViewState state;
  final bool previewMode;
  final String? detail, hint, serialValue, baud, parity, endpoint;
  final int serialReceived, tcpReceived;
  final DateTime? sessionStartedAt;
  final VoidCallback? onStartAgain, onEditSetup;
  final ValueChanged<BridgeViewState>? onPreviewState;

  @override
  State<DetailsPage> createState() => _DetailsPageState();
}

class _DetailsPageState extends State<DetailsPage> {
  Timer? ticker;

  bool get live =>
      widget.state == BridgeViewState.listening ||
      widget.state == BridgeViewState.connected;

  @override
  void initState() {
    super.initState();
    _syncTicker();
  }

  @override
  void didUpdateWidget(covariant DetailsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncTicker();
  }

  void _syncTicker() {
    final wanted = live && widget.sessionStartedAt != null;
    if (wanted && ticker == null) {
      ticker = Timer.periodic(
        const Duration(seconds: 1),
        (_) => setState(() {}),
      );
    } else if (!wanted) {
      ticker?.cancel();
      ticker = null;
    }
  }

  @override
  void dispose() {
    ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final colors = paletteOf(context);
    final copy = StateCopy.of(widget.state, l);
    final language = Localizations.localeOf(context).languageCode;
    final ended =
        widget.state == BridgeViewState.error ||
        widget.state == BridgeViewState.interrupted;
    const dash = '—';
    final started = widget.sessionStartedAt;

    return PageFrame(
      title: l.diagnosticsNav,
      subtitle: l.detailsSubtitle,
      children: [
        if (widget.previewMode) ...[
          Callout(icon: shad.LucideIcons.eye, text: l.previewNotice),
          const SizedBox(height: 18),
        ],
        if (widget.onPreviewState != null)
          Section(
            title: l.previewStates,
            icon: shad.LucideIcons.eye,
            padded: true,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final candidate in BridgeViewState.values)
                    candidate == widget.state
                        ? shad.PrimaryButton(
                            onPressed: () => widget.onPreviewState!(candidate),
                            density: shad.ButtonDensity.dense,
                            child: Text(StateCopy.of(candidate, l).badge),
                          )
                        : shad.OutlineButton(
                            onPressed: () => widget.onPreviewState!(candidate),
                            density: shad.ButtonDensity.dense,
                            child: Text(StateCopy.of(candidate, l).badge),
                          ),
                ],
              ),
            ],
          ),
        Section(
          padded: true,
          children: [
            Row(
              children: [
                StatusPill(state: widget.state, label: copy.badge),
                const Spacer(),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              copy.title,
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.3,
                color: widget.state == BridgeViewState.error
                    ? colors.error
                    : colors.foreground,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              copy.description,
              style: TextStyle(fontSize: 13.5, color: colors.muted),
            ),
            if (widget.detail?.isNotEmpty == true) ...[
              const SizedBox(height: 14),
              Callout(
                icon: widget.state == BridgeViewState.error
                    ? shad.LucideIcons.circleAlert
                    : shad.LucideIcons.info,
                tone: widget.state == BridgeViewState.error
                    ? CalloutTone.error
                    : CalloutTone.info,
                text: widget.detail!,
              ),
            ],
            if (widget.hint != null) ...[
              const SizedBox(height: 10),
              Callout(icon: shad.LucideIcons.lightbulb, text: widget.hint!),
            ],
            if (ended && widget.onStartAgain != null) ...[
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  shad.PrimaryButton(
                    onPressed: widget.onStartAgain,
                    leading: const Icon(shad.LucideIcons.rotateCw, size: 15),
                    child: Text(l.startAgain),
                  ),
                  if (widget.onEditSetup != null)
                    shad.OutlineButton(
                      onPressed: widget.onEditSetup,
                      child: Text(l.editSetup),
                    ),
                ],
              ),
            ],
          ],
        ),
        Section(
          title: l.sessionSection,
          icon: shad.LucideIcons.cable,
          children: [
            _Fact(l.serialPortPath, widget.serialValue ?? dash),
            _Fact(l.baudRate, widget.baud ?? dash),
            _Fact(l.parity, switch (widget.parity) {
              'E' => l.parityEven,
              'O' => l.parityOdd,
              'N' => l.parityNone,
              _ => dash,
            }),
            _Fact(l.endpointLabel, widget.endpoint ?? dash),
            _Fact(
              l.clientLabel,
              widget.state == BridgeViewState.connected
                  ? l.connected
                  : widget.state == BridgeViewState.listening
                  ? l.clientWaiting
                  : l.clientNone,
            ),
            _Fact(
              l.sessionTime,
              live && started != null
                  ? formatDuration(DateTime.now().difference(started))
                  : dash,
            ),
          ],
        ),
        Section(
          title: l.trafficSection,
          icon: shad.LucideIcons.arrowLeftRight,
          footer: Text(l.trafficNote),
          children: [
            _Fact(
              l.fromSerial,
              formatBytes(widget.serialReceived, language),
              icon: shad.LucideIcons.arrowRight,
            ),
            _Fact(
              l.fromTcp,
              formatBytes(widget.tcpReceived, language),
              icon: shad.LucideIcons.arrowLeft,
            ),
          ],
        ),
      ],
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact(this.label, this.value, {this.icon});

  final String label, value;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colors = paletteOf(context);
    return SectionRow(
      label: label,
      stackBelow: 0,
      leading: icon == null ? null : Icon(icon, size: 15, color: colors.muted),
      trailing: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 260),
        child: Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.end,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: colors.foreground,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }
}
