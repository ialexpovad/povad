import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shad;

import '../domain/bridge_view_state.dart';
import 'povad_theme.dart';

/// Top-aligned scrolling frame shared by the secondary destinations.
class PageFrame extends StatelessWidget {
  const PageFrame({
    super.key,
    required this.title,
    this.subtitle,
    required this.children,
    this.maxWidth = 640,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final colors = paletteOf(context);
    return LayoutBuilder(
      builder: (context, box) {
        final narrow = box.maxWidth < 520;
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            narrow ? 18 : 40,
            narrow ? 22 : 40,
            narrow ? 18 : 40,
            40,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: narrow ? 26 : 28,
                        height: 1.15,
                        letterSpacing: -0.7,
                        fontWeight: FontWeight.w700,
                        color: colors.foreground,
                      ),
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      subtitle!,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.45,
                        color: colors.muted,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  ...children,
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// A titled group of rows on a bordered card.
class Section extends StatelessWidget {
  const Section({
    super.key,
    this.title,
    this.icon,
    required this.children,
    this.footer,
    this.padded = false,
  });

  final String? title;
  final IconData? icon;
  final List<Widget> children;
  final Widget? footer;

  /// Pads free-form content instead of edge-to-edge rows.
  final bool padded;

  @override
  Widget build(BuildContext context) {
    final colors = paletteOf(context);
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0 && !padded) {
        rows.add(Container(height: 1, color: colors.border));
      }
      rows.add(children[i]);
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.only(left: 2, bottom: 9),
              child: Row(
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 15, color: colors.muted),
                    const SizedBox(width: 7),
                  ],
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        title!,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.1,
                          color: colors.muted,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          DecoratedBox(
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: colors.border),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(13),
              child: Padding(
                padding: padded ? const EdgeInsets.all(18) : EdgeInsets.zero,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: rows,
                ),
              ),
            ),
          ),
          if (footer != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(2, 9, 2, 0),
              child: DefaultTextStyle.merge(
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.45,
                  color: colors.muted,
                ),
                child: footer!,
              ),
            ),
        ],
      ),
    );
  }
}

/// A label and optional description beside a trailing control. Narrow
/// layouts stack the control below the label so it keeps its full width.
class SectionRow extends StatelessWidget {
  const SectionRow({
    super.key,
    required this.label,
    this.description,
    this.leading,
    this.trailing,
    this.below,
    this.stackBelow = 440,
    this.onTap,
    this.semanticLabel,
  });

  final String label;
  final String? description;
  final Widget? leading;
  final Widget? trailing;
  final Widget? below;
  final double stackBelow;
  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final colors = paletteOf(context);
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: colors.foreground,
          ),
        ),
        if (description != null) ...[
          const SizedBox(height: 3),
          Text(
            description!,
            style: TextStyle(fontSize: 12.5, height: 1.4, color: colors.muted),
          ),
        ],
      ],
    );
    final content = LayoutBuilder(
      builder: (context, box) {
        final stacked = trailing != null && box.maxWidth < stackBelow;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  if (leading != null) ...[leading!, const SizedBox(width: 12)],
                  Expanded(child: text),
                  if (trailing != null && !stacked) ...[
                    const SizedBox(width: 14),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: (box.maxWidth - 32) * 0.62,
                      ),
                      child: trailing!,
                    ),
                  ],
                ],
              ),
              if (stacked) ...[
                const SizedBox(height: 11),
                Align(alignment: Alignment.centerLeft, child: trailing!),
              ],
              if (below != null) ...[const SizedBox(height: 12), below!],
            ],
          ),
        );
      },
    );
    if (onTap == null) return content;
    return Semantics(
      button: true,
      label: semanticLabel,
      child: shad.Clickable(
        onPressed: onTap,
        mouseCursor: const WidgetStatePropertyAll(SystemMouseCursors.click),
        decoration: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.hovered) ||
                  states.contains(WidgetState.focused)
              ? BoxDecoration(color: colors.subtle)
              : null,
        ),
        child: content,
      ),
    );
  }
}

/// A compact single-choice control styled after a segmented picker.
class SegmentedChoice<T> extends StatelessWidget {
  const SegmentedChoice({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  final List<(T, String)> options;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = paletteOf(context);
    return LayoutBuilder(
      builder: (context, box) {
        // Beside a label the control keeps its natural width; stacked under
        // one it spans the row and shares the width evenly.
        final fill = box.maxWidth.isFinite;
        return Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: colors.subtle,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            mainAxisSize: fill ? MainAxisSize.max : MainAxisSize.min,
            children: [
              for (final (option, label) in options)
                if (fill)
                  Expanded(
                    child: _Segment(
                      label: label,
                      selected: option == value,
                      onTap: () => onChanged(option),
                    ),
                  )
                else
                  _Segment(
                    label: label,
                    selected: option == value,
                    onTap: () => onChanged(option),
                  ),
            ],
          ),
        );
      },
    );
  }
}

class _Segment extends StatefulWidget {
  const _Segment({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_Segment> createState() => _SegmentState();
}

class _SegmentState extends State<_Segment> {
  bool focused = false;
  bool hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = paletteOf(context);
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return Semantics(
      button: true,
      selected: widget.selected,
      inMutuallyExclusiveGroup: true,
      child: FocusableActionDetector(
        mouseCursor: SystemMouseCursors.click,
        onShowFocusHighlight: (value) => setState(() => focused = value),
        onShowHoverHighlight: (value) => setState(() => hovered = value),
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onTap();
              return null;
            },
          ),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: reduce
                ? Duration.zero
                : const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            constraints: const BoxConstraints(minHeight: 34, minWidth: 44),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: widget.selected
                  ? colors.background
                  : hovered
                  ? colors.background.withValues(alpha: 0.5)
                  : const Color(0x00000000),
              borderRadius: BorderRadius.circular(7),
              border: Border.all(
                color: focused
                    ? colors.primary
                    : widget.selected
                    ? colors.border
                    : const Color(0x00000000),
                width: focused ? 1.5 : 1,
              ),
              boxShadow: [
                if (widget.selected)
                  const BoxShadow(
                    color: Color(0x14000000),
                    blurRadius: 3,
                    offset: Offset(0, 1),
                  ),
              ],
            ),
            alignment: Alignment.center,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                widget.label,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: widget.selected
                      ? FontWeight.w600
                      : FontWeight.w500,
                  color: widget.selected ? colors.foreground : colors.muted,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum CalloutTone { info, warning, error }

class Callout extends StatelessWidget {
  const Callout({
    super.key,
    required this.icon,
    required this.text,
    this.tone = CalloutTone.info,
    this.action,
  });

  final IconData icon;
  final String text;
  final CalloutTone tone;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final colors = paletteOf(context);
    final (background, border, foreground) = switch (tone) {
      CalloutTone.info => (
        colors.selection,
        colors.selection,
        colors.foreground,
      ),
      CalloutTone.warning => (
        colors.warningSurface,
        colors.warningBorder,
        colors.warning,
      ),
      CalloutTone.error => (
        colors.errorSurface,
        colors.error.withValues(alpha: 0.3),
        colors.error,
      ),
    };
    final accent = tone == CalloutTone.info ? colors.primary : foreground;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, size: 16, color: accent),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  text,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    color: foreground,
                  ),
                ),
                if (action != null) ...[const SizedBox(height: 10), action!],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Status color for a bridge state. Text always accompanies it.
Color bridgeTone(BridgeViewState state, PovadPalette colors) => switch (state) {
  BridgeViewState.listening ||
  BridgeViewState.connected ||
  BridgeViewState.starting ||
  BridgeViewState.stopping => colors.primary,
  BridgeViewState.error => colors.error,
  BridgeViewState.stopped || BridgeViewState.interrupted => colors.inactive,
};

class StatusDot extends StatelessWidget {
  const StatusDot({super.key, required this.color, this.size = 8, this.ring});

  final Color color;
  final double size;

  /// Draws a soft ring for an active state; the dot itself never animates.
  final bool? ring;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: color,
      shape: BoxShape.circle,
      boxShadow: [
        if (ring ?? false)
          BoxShadow(color: color.withValues(alpha: 0.28), spreadRadius: 3),
      ],
    ),
  );
}

/// The state name next to its color, for headers and the sidebar.
class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.state, required this.label});

  final BridgeViewState state;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = paletteOf(context);
    final tone = bridgeTone(state, colors);
    final live =
        state == BridgeViewState.listening ||
        state == BridgeViewState.connected;
    return Container(
      padding: const EdgeInsets.fromLTRB(9, 5, 11, 5),
      decoration: BoxDecoration(
        color: live
            ? colors.selection
            : state == BridgeViewState.error
            ? colors.errorSurface
            : colors.subtle,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          StatusDot(color: tone, size: 7, ring: live),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: state == BridgeViewState.error
                    ? colors.error
                    : live
                    ? colors.primary
                    : colors.foreground,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Digits only; keeps numeric settings free of stray characters.
final digitsOnly = <TextInputFormatter>[
  FilteringTextInputFormatter.digitsOnly,
  LengthLimitingTextInputFormatter(7),
];

String formatBytes(int bytes, String languageCode) {
  String fixed(double value) {
    final text = value >= 100
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(1);
    return languageCode == 'be' ? text.replaceAll('.', ',') : text;
  }

  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${fixed(bytes / 1024)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${fixed(bytes / (1024 * 1024))} MB';
  }
  return '${fixed(bytes / (1024 * 1024 * 1024))} GB';
}

String formatDuration(Duration value) {
  String two(int n) => n.toString().padLeft(2, '0');
  final hours = value.inHours;
  final minutes = value.inMinutes.remainder(60);
  final seconds = value.inSeconds.remainder(60);
  return hours > 0
      ? '$hours:${two(minutes)}:${two(seconds)}'
      : '${two(minutes)}:${two(seconds)}';
}

/// A square toolbar control for the compact header, sized for touch and
/// legible beside the brand lockup. Desktop pointers get a tooltip.
class ToolbarIconButton extends StatelessWidget {
  const ToolbarIconButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.badge = false,
    this.quiet = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  /// Shows a small accent dot, for example when an update is available.
  final bool badge;
  final bool quiet;

  @override
  Widget build(BuildContext context) {
    final colors = paletteOf(context);
    final button = Semantics(
      label: label,
      button: true,
      excludeSemantics: true,
      child: shad.Clickable(
        onPressed: onPressed,
        mouseCursor: const WidgetStatePropertyAll(SystemMouseCursors.click),
        decoration: WidgetStateProperty.resolveWith(
          (states) => BoxDecoration(
            color:
                states.contains(WidgetState.hovered) ||
                    states.contains(WidgetState.pressed)
                ? colors.subtle
                : quiet
                ? const Color(0x00000000)
                : colors.background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: states.contains(WidgetState.focused)
                  ? colors.primary
                  : quiet
                  ? const Color(0x00000000)
                  : colors.border,
              width: states.contains(WidgetState.focused) ? 1.5 : 1,
            ),
          ),
        ),
        child: SizedBox.square(
          // Touch platforms need a 48 dp target; pointers are fine at 44.
          dimension:
              defaultTargetPlatform == TargetPlatform.android ||
                  defaultTargetPlatform == TargetPlatform.iOS
              ? 48
              : 44,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(icon, size: 21, color: colors.foreground),
              if (badge)
                Positioned(
                  top: 8,
                  right: 8,
                  child: StatusDot(color: colors.primary, size: 8),
                ),
            ],
          ),
        ),
      ),
    );
    if (quiet) return button;
    return shad.Tooltip(
      tooltip: (context) => shad.TooltipContainer(child: Text(label)),
      child: button,
    );
  }
}
