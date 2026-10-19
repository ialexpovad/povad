import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shad;

import '../design/povad_components.dart';
import '../design/povad_theme.dart';
import '../domain/trouble_hint.dart';
import '../l10n/generated/app_localizations.dart';

/// Topics in the order they appear in the FAQ.
enum HelpTopic { client, port, ended, bytes, lan, privacy }

HelpTopic? helpTopicFor(TroubleHint? hint) => switch (hint) {
  TroubleHint.serialAccess ||
  TroubleHint.settings ||
  TroubleHint.disconnected => HelpTopic.port,
  TroubleHint.tcpPort => HelpTopic.client,
  TroubleHint.clientLeft || TroubleHint.delivery => HelpTopic.ended,
  null => null,
};

bool get _desktop => switch (defaultTargetPlatform) {
  TargetPlatform.macOS ||
  TargetPlatform.windows ||
  TargetPlatform.linux => true,
  _ => false,
};

/// Opens help beside the current screen. It is an overlay, not a fifth
/// destination, so the four-section navigation stays unchanged.
Future<void> showHelpPanel(
  BuildContext context, {
  required VoidCallback onReportProblem,
  HelpTopic? topic,
}) {
  final l = AppLocalizations.of(context)!;
  final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: l.closeHelp,
    barrierColor: const Color(0x59000000),
    transitionDuration: reduce
        ? Duration.zero
        : const Duration(milliseconds: 280),
    pageBuilder: (context, _, _) =>
        HelpPanel(onReportProblem: onReportProblem, topic: topic),
    transitionBuilder: (context, animation, _, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return SlideTransition(
        position: Tween(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      );
    },
  );
}

class HelpPanel extends StatelessWidget {
  const HelpPanel({super.key, required this.onReportProblem, this.topic});

  final VoidCallback onReportProblem;
  final HelpTopic? topic;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final colors = paletteOf(context);
    final size = MediaQuery.sizeOf(context);
    final width = math.min(440.0, size.width);
    final modifier =
        defaultTargetPlatform == TargetPlatform.macOS ||
            defaultTargetPlatform == TargetPlatform.iOS
        ? '⌘'
        : 'Ctrl';
    final faq = [
      (HelpTopic.client, l.faqClientQ, l.faqClientA),
      (HelpTopic.port, l.faqPortQ, l.faqPortA),
      (HelpTopic.ended, l.faqEndedQ, l.faqEndedA),
      (HelpTopic.bytes, l.faqBytesQ, l.faqBytesA),
      (HelpTopic.lan, l.faqLanQ, l.faqLanA),
      (HelpTopic.privacy, l.faqPrivacyQ, l.faqPrivacyA),
    ];

    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        width: width,
        height: double.infinity,
        decoration: BoxDecoration(
          color: colors.background,
          border: Border(left: BorderSide(color: colors.border)),
          boxShadow: const [
            BoxShadow(color: Color(0x33000000), blurRadius: 32),
          ],
        ),
        child: SafeArea(
          left: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 14, 14),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: colors.selection,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        shad.LucideIcons.lifeBuoy,
                        size: 20,
                        color: colors.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Semantics(
                            header: true,
                            child: Text(
                              l.help,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.3,
                                color: colors.foreground,
                              ),
                            ),
                          ),
                          Text(
                            l.helpSubtitle,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: colors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ToolbarIconButton(
                      key: const ValueKey('help-close'),
                      icon: shad.LucideIcons.x,
                      label: l.closeHelp,
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                  ],
                ),
              ),
              Container(height: 1, color: colors.border),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(18, 20, 18, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Section(
                        title: l.quickStartTitle,
                        icon: shad.LucideIcons.rocket,
                        children: [
                          _Step(1, l.step1Title, l.step1Body),
                          _Step(2, l.step2Title, l.step2Body),
                          _Step(3, l.step3Title, l.step3Body),
                        ],
                      ),
                      Section(
                        title: l.faqTitle,
                        icon: shad.LucideIcons.messageCircleQuestion,
                        children: [
                          for (final (key, question, answer) in faq)
                            _FaqItem(
                              key: ValueKey('faq-${key.name}'),
                              question: question,
                              answer: answer,
                              initiallyOpen: key == topic,
                            ),
                        ],
                      ),
                      if (_desktop)
                        Section(
                          title: l.shortcutsTitle,
                          icon: shad.LucideIcons.keyboard,
                          children: [
                            _Shortcut(l.shortcutToggle, [modifier, '↵']),
                            _Shortcut(l.shortcutNavigate, [modifier, '1–4']),
                            _Shortcut(l.shortcutHelp, ['F1']),
                          ],
                        ),
                      Section(
                        padded: true,
                        children: [
                          Text(
                            l.stillStuck,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: colors.foreground,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            l.stillStuckBody,
                            style: TextStyle(
                              fontSize: 12.5,
                              height: 1.45,
                              color: colors.muted,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: shad.OutlineButton(
                              onPressed: onReportProblem,
                              leading: const Icon(
                                shad.LucideIcons.messageSquare,
                                size: 15,
                              ),
                              trailing: const Icon(
                                shad.LucideIcons.arrowUpRight,
                                size: 14,
                              ),
                              child: Text(l.reportProblem),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step(this.number, this.title, this.body);

  final int number;
  final String title, body;

  @override
  Widget build(BuildContext context) {
    final colors = paletteOf(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colors.selection,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$number',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: colors.primary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: colors.foreground,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.45,
                    color: colors.muted,
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

class _FaqItem extends StatefulWidget {
  const _FaqItem({
    super.key,
    required this.question,
    required this.answer,
    this.initiallyOpen = false,
  });

  final String question, answer;
  final bool initiallyOpen;

  @override
  State<_FaqItem> createState() => _FaqItemState();
}

class _FaqItemState extends State<_FaqItem> {
  late bool open = widget.initiallyOpen;

  @override
  Widget build(BuildContext context) {
    final colors = paletteOf(context);
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final duration = reduce ? Duration.zero : const Duration(milliseconds: 200);
    return Semantics(
      expanded: open,
      child: shad.Clickable(
        onPressed: () => setState(() => open = !open),
        mouseCursor: const WidgetStatePropertyAll(SystemMouseCursors.click),
        decoration: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.hovered) ||
                  states.contains(WidgetState.focused)
              ? BoxDecoration(color: colors.subtle)
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 13, 14, 13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.question,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: colors.foreground,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  AnimatedRotation(
                    turns: open ? 0.5 : 0,
                    duration: duration,
                    child: Icon(
                      shad.LucideIcons.chevronDown,
                      size: 17,
                      color: colors.muted,
                    ),
                  ),
                ],
              ),
              AnimatedSize(
                duration: duration,
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: open
                    ? Padding(
                        padding: const EdgeInsets.only(top: 8, right: 24),
                        child: Text(
                          widget.answer,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.5,
                            color: colors.muted,
                          ),
                        ),
                      )
                    : const SizedBox(width: double.infinity),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Shortcut extends StatelessWidget {
  const _Shortcut(this.label, this.keys);

  final String label;
  final List<String> keys;

  @override
  Widget build(BuildContext context) {
    final colors = paletteOf(context);
    return SectionRow(
      label: label,
      stackBelow: 300,
      trailing: Wrap(
        runSpacing: 4,
        children: [
          for (final key in keys)
            Container(
              margin: const EdgeInsets.only(left: 4),
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: colors.subtle,
                borderRadius: BorderRadius.circular(6),
                border: Border(
                  top: BorderSide(color: colors.border),
                  left: BorderSide(color: colors.border),
                  right: BorderSide(color: colors.border),
                  bottom: BorderSide(color: colors.border, width: 2),
                ),
              ),
              child: Text(
                key,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colors.foreground,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

String? troubleHintText(TroubleHint? hint, AppLocalizations l) =>
    switch (hint) {
      TroubleHint.serialAccess => l.hintSerialAccess,
      TroubleHint.tcpPort => l.hintTcpPort,
      TroubleHint.disconnected => l.hintDisconnected,
      TroubleHint.settings => l.hintSettings,
      TroubleHint.delivery => l.hintDelivery,
      TroubleHint.clientLeft => l.hintClientLeft,
      null => null,
    };
