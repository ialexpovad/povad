import 'package:flutter/widgets.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shad;

import 'povad_theme.dart';

class PreviewNotice extends StatelessWidget {
  const PreviewNotice({super.key, required this.label});
  final String label;
  @override
  Widget build(BuildContext context) {
    final color = paletteOf(context).muted;
    return Row(
      children: [
        Icon(shad.LucideIcons.eye, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}
