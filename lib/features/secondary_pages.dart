import 'package:flutter/widgets.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shad;

import '../design/povad_theme.dart';
import '../design/preview_notice.dart';
import '../l10n/generated/app_localizations.dart';

class EmptyPage extends StatelessWidget {
  const EmptyPage({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
  });
  final IconData icon;
  final String title, body;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final colors = paletteOf(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Column(
            children: [
              Icon(icon, size: 52, color: colors.primary),
              const SizedBox(height: 20),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: colors.foreground,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                body,
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.muted),
              ),
              const SizedBox(height: 30),
              PreviewNotice(label: l.previewNotice),
            ],
          ),
        ),
      ),
    );
  }
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
    required this.locale,
    required this.onLocaleChanged,
    required this.skin,
    required this.onSkinChanged,
  });
  final Locale locale;
  final ValueChanged<Locale> onLocaleChanged;
  final PovadSkin skin;
  final ValueChanged<PovadSkin> onSkinChanged;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final colors = paletteOf(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 580),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l.settings,
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                  color: colors.foreground,
                ),
              ),
              const SizedBox(height: 28),
              Text(
                l.language,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: colors.foreground,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final (code, label) in [
                    ('en', l.english),
                    ('be', l.belarusian),
                  ])
                    code == locale.languageCode
                        ? shad.PrimaryButton(
                            onPressed: () => onLocaleChanged(Locale(code)),
                            child: Text(label),
                          )
                        : shad.OutlineButton(
                            onPressed: () => onLocaleChanged(Locale(code)),
                            child: Text(label),
                          ),
                ],
              ),
              const SizedBox(height: 34),
              Text(
                l.appearance,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: colors.foreground,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                l.appearanceSystem,
                style: TextStyle(color: colors.muted),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final (option, label) in [
                    (PovadSkin.copper, l.copperTheme),
                    (PovadSkin.classicBlue, l.classicBlueTheme),
                  ])
                    option == skin
                        ? shad.PrimaryButton(
                            onPressed: () => onSkinChanged(option),
                            child: Text(label),
                          )
                        : shad.OutlineButton(
                            onPressed: () => onSkinChanged(option),
                            child: Text(label),
                          ),
                ],
              ),
              const SizedBox(height: 34),
              Text(
                l.about,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: colors.foreground,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                l.aboutDescription,
                style: TextStyle(color: colors.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
