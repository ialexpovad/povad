import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shad;

import '../design/povad_mark.dart';
import '../design/povad_theme.dart';
import '../domain/bridge_view_state.dart';
import '../features/overview_page.dart';
import '../features/secondary_pages.dart';
import '../l10n/generated/app_localizations.dart';
import '../l10n/shadcn_localizations_be.dart';
import 'ui_preferences.dart';

class PovadApp extends StatefulWidget {
  const PovadApp({super.key, this.preferences});

  final UiPreferences? preferences;

  @override
  State<PovadApp> createState() => _PovadAppState();
}

class _PovadAppState extends State<PovadApp> {
  Locale locale = const Locale('en');
  PovadSkin skin = PovadSkin.copper;
  BridgeViewState state = BridgeViewState.stopped;
  int page = 0;
  late final UiPreferences preferences;
  bool settingsChanged = false;

  @override
  void initState() {
    super.initState();
    preferences = widget.preferences ?? DeviceUiPreferences();
    unawaited(loadPreferences());
  }

  Future<void> loadPreferences() async {
    try {
      final savedLanguage = await preferences.readLanguage();
      final savedSkin = await preferences.readSkin();
      if (!mounted || settingsChanged) return;
      setState(() {
        if (savedLanguage == 'en' || savedLanguage == 'be') {
          locale = Locale(savedLanguage!);
        }
        if (savedSkin != null) skin = savedSkin;
      });
    } catch (error) {
      debugPrint('Unable to load UI preferences: $error');
    }
  }

  void changeLocale(Locale value) {
    settingsChanged = true;
    setState(() => locale = value);
    unawaited(saveLanguage(value.languageCode));
  }

  void changeSkin(PovadSkin value) {
    settingsChanged = true;
    setState(() => skin = value);
    unawaited(saveSkin(value));
  }

  Future<void> saveLanguage(String languageCode) async {
    try {
      await preferences.saveLanguage(languageCode);
    } catch (error) {
      debugPrint('Unable to save UI language: $error');
    }
  }

  Future<void> saveSkin(PovadSkin value) async {
    try {
      await preferences.saveSkin(value);
    } catch (error) {
      debugPrint('Unable to save UI theme: $error');
    }
  }

  void act() {
    if (!kDebugMode) return;
    setState(() {
      if (state == BridgeViewState.stopped) {
        state = BridgeViewState.starting;
      } else if (state == BridgeViewState.listening ||
          state == BridgeViewState.connected) {
        state = BridgeViewState.stopping;
      } else if (state == BridgeViewState.error) {
        page = 2;
      }
    });
  }

  @override
  Widget build(BuildContext context) => shad.ShadcnApp(
    title: 'Povad',
    debugShowCheckedModeBanner: false,
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      PovadShadcnDelegate(),
    ],
    theme: PovadPalette(skin, false).toShadcn(),
    darkTheme: PovadPalette(skin, true).toShadcn(),
    home: PovadSkinScope(
      skin: skin,
      child: Builder(
        builder: (context) {
          final l = AppLocalizations.of(context)!;
          final p = paletteOf(context);
          final labels = [l.overview, l.bridge, l.diagnostics, l.settings];
          const icons = [
            shad.LucideIcons.layoutDashboard,
            shad.LucideIcons.cable,
            shad.LucideIcons.activity,
            shad.LucideIcons.settings,
          ];
          final content = switch (page) {
            0 => OverviewPage(
              state: state,
              onAction: act,
              onPreviewState: (value) => setState(() => state = value),
            ),
            1 => EmptyPage(
              icon: shad.LucideIcons.cable,
              title: l.bridgeSetupTitle,
              body: l.bridgeSetupBody,
            ),
            2 => EmptyPage(
              icon: shad.LucideIcons.activity,
              title: state == BridgeViewState.error
                  ? l.errorTitle
                  : l.diagnosticsTitle,
              body: state == BridgeViewState.error
                  ? l.errorDescription
                  : l.diagnosticsBody,
            ),
            _ => SettingsPage(
              locale: locale,
              onLocaleChanged: changeLocale,
              skin: skin,
              onSkinChanged: changeSkin,
            ),
          };
          return ColoredBox(
            color: p.background,
            child: SafeArea(
              child: LayoutBuilder(
                builder: (context, box) {
                  if (box.maxWidth < 760) {
                    return Column(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: p.surface,
                            border: Border(bottom: BorderSide(color: p.border)),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              const PovadBrandLockup(compact: true),
                            ],
                          ),
                        ),
                        Expanded(child: content),
                        Container(
                          decoration: BoxDecoration(
                            color: p.surface,
                            border: Border(top: BorderSide(color: p.border)),
                          ),
                          padding: const EdgeInsets.fromLTRB(6, 5, 6, 8),
                          child: Row(
                            children: [
                              for (var i = 0; i < 4; i++)
                                Expanded(
                                  child: _NavItem(
                                    key: ValueKey('nav-$i'),
                                    index: i,
                                    selected: page == i,
                                    compact: true,
                                    icon: icons[i],
                                    label: labels[i],
                                    onTap: () => setState(() => page = i),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }
                  return Row(
                    children: [
                      Container(
                        width: 220,
                        decoration: BoxDecoration(
                          color: p.surface,
                          border: Border(right: BorderSide(color: p.border)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                20,
                                30,
                                14,
                                36,
                              ),
                              child: PovadBrandLockup(caption: l.appCaption),
                            ),
                            for (var i = 0; i < 4; i++)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  12,
                                  0,
                                  12,
                                  5,
                                ),
                                child: _NavItem(
                                  key: ValueKey('nav-$i'),
                                  index: i,
                                  selected: page == i,
                                  compact: false,
                                  icon: icons[i],
                                  label: labels[i],
                                  onTap: () => setState(() => page = i),
                                ),
                              ),
                          ],
                        ),
                      ),
                      Expanded(child: content),
                    ],
                  );
                },
              ),
            ),
          );
        },
      ),
    ),
  );
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    super.key,
    required this.index,
    required this.selected,
    required this.compact,
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final int index;
  final bool selected, compact;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = paletteOf(context);
    return Semantics(
      label: label,
      selected: selected,
      button: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: selected ? p.selection : const Color(0x00000000),
          borderRadius: BorderRadius.circular(9),
        ),
        child: shad.GhostButton(
          onPressed: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: compact ? 3 : 7),
            child: compact
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        icon,
                        size: 19,
                        color: selected ? p.primary : p.muted,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: selected ? p.primary : p.muted,
                        ),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Icon(
                        icon,
                        size: 18,
                        color: selected ? p.primary : p.muted,
                      ),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: selected
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: selected ? p.primary : p.foreground,
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
