import 'package:flutter/widgets.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shad;

enum PovadSkin { copper, classicBlue }

@immutable
final class PovadPalette {
  const PovadPalette(this.skin, this.dark);

  final PovadSkin skin;
  final bool dark;

  bool get classic => skin == PovadSkin.classicBlue;

  Color get background => classic
      ? (dark ? const Color(0xFF09090B) : const Color(0xFFFFFFFF))
      : (dark ? const Color(0xFF0E1117) : const Color(0xFFF6F7F8));
  Color get surface => classic
      ? (dark ? const Color(0xFF141417) : const Color(0xFFFAFAFB))
      : (dark ? const Color(0xFF171B21) : const Color(0xFFFFFFFF));
  Color get border => classic
      ? (dark ? const Color(0xFF2C2C31) : const Color(0xFFE4E4E7))
      : (dark ? const Color(0xFF313842) : const Color(0xFFDEE2E7));
  Color get foreground => classic
      ? (dark ? const Color(0xFFFAFAFA) : const Color(0xFF18181B))
      : (dark ? const Color(0xFFF3F4F6) : const Color(0xFF171B21));
  Color get muted => classic
      ? (dark ? const Color(0xFFA1A1AA) : const Color(0xFF60606C))
      : (dark ? const Color(0xFFABB3BE) : const Color(0xFF626A73));
  Color get primary => classic
      ? (dark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB))
      : (dark ? const Color(0xFFFF8C6B) : const Color(0xFFB94D32));
  Color get onPrimary => classic && dark
      ? const Color(0xFF09090B)
      : dark
      ? const Color(0xFF171B21)
      : const Color(0xFFFFFFFF);
  Color get selection => classic
      ? (dark ? const Color(0xFF15233A) : const Color(0xFFEFF6FF))
      : (dark ? const Color(0xFF33231F) : const Color(0xFFF9E9E3));
  Color get inactive => classic
      ? (dark ? const Color(0xFF71717A) : const Color(0xFFA1A1AA))
      : (dark ? const Color(0xFF66717F) : const Color(0xFFAAB3BD));
  Color get error => classic
      ? (dark ? const Color(0xFFF87171) : const Color(0xFFB91C1C))
      : (dark ? const Color(0xFFFF7B8A) : const Color(0xFFB32636));

  shad.ThemeData toShadcn() => shad.ThemeData(
    radius: 0.55,
    typography: const shad.Typography.geist(
      sans: TextStyle(fontFamily: 'Inter'),
      base: TextStyle(fontFamily: 'Inter', fontSize: 16),
    ),
    colorScheme: shad.ColorScheme(
      brightness: dark ? Brightness.dark : Brightness.light,
      background: background,
      foreground: foreground,
      card: surface,
      cardForeground: foreground,
      popover: surface,
      popoverForeground: foreground,
      primary: primary,
      primaryForeground: onPrimary,
      secondary: surface,
      secondaryForeground: foreground,
      muted: surface,
      mutedForeground: muted,
      accent: selection,
      accentForeground: foreground,
      destructive: error,
      destructiveForeground: const Color(0xFFFFFFFF),
      border: border,
      input: border,
      ring: primary,
      chart1: primary,
      chart2: muted,
      chart3: inactive,
      chart4: selection,
      chart5: error,
    ),
  );
}

class PovadSkinScope extends InheritedWidget {
  const PovadSkinScope({super.key, required this.skin, required super.child});

  final PovadSkin skin;

  static PovadSkin of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PovadSkinScope>()!.skin;

  @override
  bool updateShouldNotify(PovadSkinScope oldWidget) => skin != oldWidget.skin;
}

PovadPalette paletteOf(BuildContext context) => PovadPalette(
  PovadSkinScope.of(context),
  shad.Theme.of(context).colorScheme.brightness == Brightness.dark,
);
