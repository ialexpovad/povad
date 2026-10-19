import 'package:flutter/widgets.dart';

import '../design/povad_theme.dart';
import '../design/preview_notice.dart';
import '../l10n/generated/app_localizations.dart';

export 'bridge_setup_page.dart';
export 'details_page.dart';
export 'settings_page.dart';

/// Placeholder used by the design preview, which has no native worker.
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
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: colors.selection,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(icon, size: 28, color: colors.primary),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4,
                  color: colors.foreground,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                body,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colors.muted,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 26),
              PreviewNotice(label: l.previewNotice),
            ],
          ),
        ),
      ),
    );
  }
}
