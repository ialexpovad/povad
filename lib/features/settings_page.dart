import 'package:flutter/widgets.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shad;

import '../app/release_updates.dart';
import '../design/povad_components.dart';
import '../design/povad_mark.dart';
import '../design/povad_theme.dart';
import '../l10n/generated/app_localizations.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
    required this.locale,
    required this.onLocaleChanged,
    required this.appearance,
    required this.onAppearanceChanged,
    this.feedbackError,
    this.versionLabel,
    this.updateChecking = false,
    this.updateChecked = false,
    this.updateCheckFailed = false,
    this.projectLinkFailed = false,
    this.availableRelease,
    this.onCheckUpdates,
    this.onOpenRelease,
    this.onOpenSource,
    this.onOpenLicense,
    this.onOpenAuthor,
    this.onSendFeedback,
  });
  final Locale locale;
  final ValueChanged<Locale> onLocaleChanged;
  final PovadAppearance appearance;
  final ValueChanged<PovadAppearance> onAppearanceChanged;
  final String? feedbackError;
  final String? versionLabel;
  final bool updateChecking;
  final bool updateChecked;
  final bool updateCheckFailed;
  final bool projectLinkFailed;
  final AvailableRelease? availableRelease;
  final VoidCallback? onCheckUpdates;
  final VoidCallback? onOpenRelease;
  final VoidCallback? onOpenSource;
  final VoidCallback? onOpenLicense;
  final VoidCallback? onOpenAuthor;
  final VoidCallback? onSendFeedback;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final colors = paletteOf(context);
    final release = availableRelease;
    final (statusIcon, statusColor, statusText) = updateChecking
        ? (shad.LucideIcons.refreshCw, colors.muted, l.checkingForUpdates)
        : updateCheckFailed
        ? (shad.LucideIcons.cloudOff, colors.error, l.updateCheckFailed)
        : release != null
        ? (
            shad.LucideIcons.circleArrowUp,
            colors.primary,
            l.updateAvailableVersion(release.version),
          )
        : updateChecked
        ? (shad.LucideIcons.circleCheck, colors.primary, l.upToDate)
        : (shad.LucideIcons.circleDashed, colors.muted, l.updateNotChecked);

    Widget link(IconData icon) => Icon(icon, size: 15, color: colors.muted);

    return PageFrame(
      title: l.settings,
      subtitle: l.settingsSubtitle,
      children: [
        Section(
          title: l.interfaceSection,
          icon: shad.LucideIcons.palette,
          children: [
            SectionRow(
              label: l.language,
              trailing: SegmentedChoice<String>(
                options: [('en', l.english), ('be', l.belarusian)],
                value: locale.languageCode,
                onChanged: (code) => onLocaleChanged(Locale(code)),
              ),
            ),
            SectionRow(
              label: l.appearance,
              trailing: SegmentedChoice<PovadAppearance>(
                options: [
                  (PovadAppearance.system, l.systemTheme),
                  (PovadAppearance.light, l.lightTheme),
                  (PovadAppearance.dark, l.darkTheme),
                ],
                value: appearance,
                onChanged: onAppearanceChanged,
              ),
            ),
          ],
        ),
        Section(
          title: l.updates,
          icon: shad.LucideIcons.download,
          footer: Text(l.updateCheckPrivacy),
          children: [
            SectionRow(
              leading: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: release != null ? colors.selection : colors.subtle,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(statusIcon, size: 17, color: statusColor),
              ),
              label: statusText,
              description: versionLabel == null
                  ? null
                  : '${l.versionLabel} $versionLabel',
              trailing: release != null && onOpenRelease != null
                  ? shad.PrimaryButton(
                      onPressed: onOpenRelease,
                      density: shad.ButtonDensity.dense,
                      trailing: const Icon(
                        shad.LucideIcons.arrowUpRight,
                        size: 14,
                      ),
                      child: Text(l.viewRelease),
                    )
                  : shad.OutlineButton(
                      onPressed: updateChecking ? null : onCheckUpdates,
                      density: shad.ButtonDensity.dense,
                      child: Text(l.checkForUpdates),
                    ),
            ),
          ],
        ),
        Section(
          title: l.about,
          icon: shad.LucideIcons.info,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ExcludeSemantics(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFFFF),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: colors.border),
                      ),
                      child: const PovadMark(
                        size: 46,
                        ink: Color(0xFF18181B),
                        firstPoint: Color(0xFF2563EB),
                        secondPoint: Color(0xFF2563EB),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Povad',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                            color: colors.foreground,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          l.aboutDescription,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.45,
                            color: colors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SectionRow(
              label: l.versionLabel,
              stackBelow: 0,
              trailing: _Value(versionLabel ?? l.versionUnavailable),
            ),
            SectionRow(
              label: l.authorLabel,
              stackBelow: 0,
              onTap: onOpenAuthor,
              semanticLabel: l.authorProfile,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Flexible(child: _Value('Aliaksandr Povad')),
                  const SizedBox(width: 8),
                  link(shad.LucideIcons.arrowUpRight),
                ],
              ),
            ),
            SectionRow(
              label: l.licenseDetails,
              stackBelow: 0,
              onTap: onOpenLicense,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(child: _Value(l.licenseValue)),
                  const SizedBox(width: 8),
                  link(shad.LucideIcons.arrowUpRight),
                ],
              ),
            ),
            SectionRow(
              label: l.sourceCode,
              stackBelow: 0,
              onTap: onOpenSource,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Flexible(child: _Value('GitHub')),
                  const SizedBox(width: 8),
                  link(shad.LucideIcons.arrowUpRight),
                ],
              ),
            ),
            if (onSendFeedback != null)
              SectionRow(
                label: l.sendFeedback,
                stackBelow: 0,
                onTap: onSendFeedback,
                trailing: link(shad.LucideIcons.messageSquare),
              ),
          ],
        ),
        if (projectLinkFailed)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Callout(
              icon: shad.LucideIcons.circleAlert,
              tone: CalloutTone.error,
              text: l.projectLinkFailed,
            ),
          ),
        if (feedbackError != null)
          Callout(
            icon: shad.LucideIcons.circleAlert,
            tone: CalloutTone.error,
            text: feedbackError!,
          ),
      ],
    );
  }
}

class _Value extends StatelessWidget {
  const _Value(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 220),
    child: Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 13.5,
        fontWeight: FontWeight.w500,
        color: paletteOf(context).foreground,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    ),
  );
}
