import 'package:flutter/widgets.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shad;

enum PovadAppearance { system, light, dark }

@immutable
final class PovadPalette {
  const PovadPalette(this.dark);

  final bool dark;

  Color get background =>
      dark ? const Color(0xFF0B0B0D) : const Color(0xFFFFFFFF);
  Color get surface => dark ? const Color(0xFF141417) : const Color(0xFFFFFFFF);
  Color get border => dark ? const Color(0xFF2C2C31) : const Color(0xFFE4E4E7);
  Color get foreground =>
      dark ? const Color(0xFFFAFAFA) : const Color(0xFF18181B);
  Color get muted => dark ? const Color(0xFFA1A1AA) : const Color(0xFF60606C);
  Color get primary => dark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB);
  Color get onPrimary =>
      dark ? const Color(0xFF0B0B0D) : const Color(0xFFFFFFFF);
  Color get selection =>
      dark ? const Color(0xFF15233A) : const Color(0xFFEFF6FF);
  Color get inactive =>
      dark ? const Color(0xFF71717A) : const Color(0xFFA1A1AA);
  Color get error => dark ? const Color(0xFFF87171) : const Color(0xFFB91C1C);

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

PovadPalette paletteOf(BuildContext context) => PovadPalette(
  shad.Theme.of(context).colorScheme.brightness == Brightness.dark,
);
