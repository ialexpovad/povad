import 'package:flutter/widgets.dart';

import 'povad_theme.dart';

class PreviewNotice extends StatelessWidget {
  const PreviewNotice({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Text(
    label,
    textAlign: TextAlign.center,
    style: TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.2,
      color: paletteOf(context).muted,
    ),
  );
}
