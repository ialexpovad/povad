import 'package:flutter/widgets.dart';

/// Scales the complete app surface, including routes and overlays. The child
/// gets a matching logical viewport so layout and hit testing agree.
class AppSurfaceScale extends StatelessWidget {
  const AppSurfaceScale({super.key, required this.scale, required this.child});

  final double scale;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (scale == 1) return child;
    final media = MediaQuery.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewport = constraints.biggest / scale;
        return FittedBox(
          fit: BoxFit.fill,
          alignment: Alignment.topLeft,
          child: SizedBox.fromSize(
            size: viewport,
            child: MediaQuery(
              data: media.copyWith(
                size: viewport,
                devicePixelRatio: media.devicePixelRatio * scale,
                padding: media.padding / scale,
                viewPadding: media.viewPadding / scale,
                viewInsets: media.viewInsets / scale,
                systemGestureInsets: media.systemGestureInsets / scale,
              ),
              child: child,
            ),
          ),
        );
      },
    );
  }
}
