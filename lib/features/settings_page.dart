import 'package:flutter/widgets.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shad;

import '../app/release_updates.dart';
import '../app/login_startup.dart';
import '../app/update_installer.dart';
import '../design/povad_components.dart';
import '../design/povad_mark.dart';
import '../design/povad_theme.dart';
import '../l10n/generated/app_localizations.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
    this.loginStartup,
    required this.locale,
    required this.onLocaleChanged,
    required this.appearance,
    required this.onAppearanceChanged,
    required this.animateConnection,
    required this.onAnimateConnectionChanged,
    this.interfaceScale = 100,
    this.onInterfaceScaleChanged,
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
    this.updateStage = UpdateStage.none,
    this.updateProgress = 0,
    this.updateBlocked = false,
    this.autoDownload,
    this.onAutoDownloadChanged,
    this.onDownloadUpdate,
    this.onInstallUpdate,
    this.installLabel,
    this.installsOnQuit = false,
    this.updateNotice,
    this.updateNoticeError = false,
  });
  final LoginStartup? loginStartup;
  final Locale locale;
  final ValueChanged<Locale> onLocaleChanged;
  final PovadAppearance appearance;
  final ValueChanged<PovadAppearance> onAppearanceChanged;
  final bool animateConnection;
  final ValueChanged<bool> onAnimateConnectionChanged;
  final int interfaceScale;
  final ValueChanged<int>? onInterfaceScaleChanged;
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
  final UpdateStage updateStage;
  final double updateProgress;

  /// The bridge must stop before a staged update can install.
  final bool updateBlocked;

  /// Null hides the automatic-download switch (no in-app installer).
  final bool? autoDownload;
  final ValueChanged<bool>? onAutoDownloadChanged;
  final VoidCallback? onDownloadUpdate, onInstallUpdate;
  final String? installLabel;
  final bool installsOnQuit;
  final String? updateNotice;
  final bool updateNoticeError;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final colors = paletteOf(context);
    final release = availableRelease;
    final percent = (updateProgress * 100).clamp(0, 100).round();
    final (statusIcon, statusColor, statusText) = switch (updateStage) {
      UpdateStage.downloading when release != null => (
        shad.LucideIcons.download,
        colors.primary,
        l.updateDownloading(release.version, percent),
      ),
      UpdateStage.ready || UpdateStage.needsPermission when release != null => (
        shad.LucideIcons.circleArrowUp,
        colors.primary,
        l.updateReady(release.version),
      ),
      UpdateStage.installing => (
        shad.LucideIcons.loader,
        colors.primary,
        l.updateInstalling,
      ),
      _ when updateChecking => (
        shad.LucideIcons.refreshCw,
        colors.muted,
        l.checkingForUpdates,
      ),
      _ when updateCheckFailed => (
        shad.LucideIcons.cloudOff,
        colors.error,
        l.updateCheckFailed,
      ),
      _ when release != null => (
        shad.LucideIcons.circleArrowUp,
        colors.primary,
        l.updateAvailableVersion(release.version),
      ),
      _ when updateChecked => (
        shad.LucideIcons.circleCheck,
        colors.primary,
        l.upToDate,
      ),
      _ => (shad.LucideIcons.circleDashed, colors.muted, l.updateNotChecked),
    };
    final String? statusDetail = switch (updateStage) {
      UpdateStage.ready when updateBlocked => l.updateWaitsForBridge,
      UpdateStage.ready when installsOnQuit => l.updateInstallsOnQuit,
      UpdateStage.needsPermission => l.androidInstallPermission,
      UpdateStage.failed => l.updateDownloadFailed,
      UpdateStage.manual => l.updateManualOnly,
      UpdateStage.notWritable => l.updateNotWritable,
      _ => versionLabel == null ? null : '${l.versionLabel} $versionLabel',
    };
    Widget viewRelease() => shad.OutlineButton(
      onPressed: onOpenRelease,
      density: shad.ButtonDensity.dense,
      trailing: const Icon(shad.LucideIcons.arrowUpRight, size: 14),
      child: Text(l.viewRelease),
    );
    final Widget? updateAction = switch (updateStage) {
      UpdateStage.downloading || UpdateStage.installing => null,
      UpdateStage.ready || UpdateStage.needsPermission => shad.PrimaryButton(
        key: const ValueKey('install-update'),
        onPressed: onInstallUpdate,
        density: shad.ButtonDensity.dense,
        child: Text(installLabel ?? l.installUpdate),
      ),
      UpdateStage.available || UpdateStage.failed => shad.PrimaryButton(
        onPressed: onDownloadUpdate,
        density: shad.ButtonDensity.dense,
        child: Text(l.downloadUpdate),
      ),
      UpdateStage.manual ||
      UpdateStage.notWritable when release != null => viewRelease(),
      _ when release != null && onOpenRelease != null => viewRelease(),
      _ => shad.OutlineButton(
        onPressed: updateChecking ? null : onCheckUpdates,
        density: shad.ButtonDensity.dense,
        child: Text(l.checkForUpdates),
      ),
    };

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
            SectionRow(
              label: l.interfaceScale,
              description: l.interfaceScaleDescription,
              stackBelow: 0,
              trailing: shad.Select<int>(
                key: const ValueKey('interface-scale'),
                value: interfaceScale,
                enabled: onInterfaceScaleChanged != null,
                onChanged: onInterfaceScaleChanged == null
                    ? null
                    : (selected) {
                        if (selected != null) {
                          onInterfaceScaleChanged!(selected);
                        }
                      },
                theme: const shad.SelectTheme(adaptiveOverlay: false),
                itemBuilder: (context, selected) => Text('$selected%'),
                popup: (context) => shad.SelectPopup<int>(
                  items: shad.SelectItemList(
                    children: [
                      for (var percent = 75; percent <= 125; percent += 5)
                        shad.SelectItemButton<int>(
                          value: percent,
                          child: Text('$percent%'),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            SectionRow(
              label: l.connectionAnimation,
              description: l.connectionAnimationDescription,
              stackBelow: 0,
              trailing: shad.Switch(
                key: const ValueKey('connection-animation'),
                value: animateConnection,
                onChanged: onAnimateConnectionChanged,
              ),
            ),
          ],
        ),
        if (loginStartup case final startup?)
          Section(
            title: l.startupSection,
            icon: shad.LucideIcons.power,
            children: [
              SectionRow(
                label: l.startAtLogin,
                description: startup.failed
                    ? l.startAtLoginFailed
                    : switch (startup.status) {
                        LoginStartupStatus.approvalRequired =>
                          l.startAtLoginApproval,
                        LoginStartupStatus.unavailable =>
                          l.startAtLoginUnavailable,
                        _ => l.startAtLoginDescription,
                      },
                stackBelow: 0,
                trailing: Semantics(
                  label: l.startAtLogin,
                  child: shad.Switch(
                    key: const ValueKey('start-at-login'),
                    value:
                        startup.status == LoginStartupStatus.enabled ||
                        startup.status == LoginStartupStatus.approvalRequired,
                    onChanged:
                        startup.busy ||
                            startup.status == LoginStartupStatus.unavailable
                        ? null
                        : (value) => startup.change(value),
                  ),
                ),
              ),
            ],
          ),
        if (updateNotice != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Callout(
              icon: updateNoticeError
                  ? shad.LucideIcons.circleAlert
                  : shad.LucideIcons.partyPopper,
              tone: updateNoticeError ? CalloutTone.error : CalloutTone.info,
              text: updateNotice!,
            ),
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
              description: statusDetail,
              trailing: updateAction,
              below: updateStage == UpdateStage.downloading
                  ? _Progress(value: updateProgress)
                  : null,
            ),
            if (autoDownload != null)
              SectionRow(
                label: l.autoUpdateTitle,
                description: l.autoUpdateBody,
                stackBelow: 0,
                trailing: shad.Switch(
                  value: autoDownload!,
                  onChanged: onAutoDownloadChanged,
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

class _Progress extends StatelessWidget {
  const _Progress({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    final colors = paletteOf(context);
    return Semantics(
      value: '${(value * 100).round()}%',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(99),
        child: Container(
          height: 6,
          color: colors.subtle,
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: value.clamp(0.0, 1.0),
            child: Container(color: colors.primary),
          ),
        ),
      ),
    );
  }
}
