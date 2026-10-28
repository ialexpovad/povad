import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:povad/design/app_surface_scale.dart';

void main() {
  for (final scale in [0.75, 1.25]) {
    testWidgets('surface scale $scale changes geometry and hit testing', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1000, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      MediaQueryData? childMedia;
      var taps = 0;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(1000, 700),
            viewInsets: EdgeInsets.only(bottom: 100),
          ),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: AppSurfaceScale(
              scale: scale,
              child: Builder(
                builder: (context) {
                  childMedia = MediaQuery.of(context);
                  return Stack(
                    children: [
                      const Positioned(
                        left: 0,
                        top: 0,
                        child: SizedBox(
                          key: ValueKey('block'),
                          width: 200,
                          height: 40,
                          child: ColoredBox(color: Color(0xFF2563EB)),
                        ),
                      ),
                      Positioned(
                        right: 0,
                        top: 0,
                        child: GestureDetector(
                          key: const ValueKey('right-target'),
                          behavior: HitTestBehavior.opaque,
                          onTap: () => taps++,
                          child: const SizedBox(width: 40, height: 40),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      );

      expect(childMedia!.size.width, closeTo(1000 / scale, 0.01));
      expect(childMedia!.size.height, closeTo(700 / scale, 0.01));
      expect(childMedia!.devicePixelRatio, closeTo(scale, 0.001));
      expect(childMedia!.viewInsets.bottom, closeTo(100 / scale, 0.01));
      expect(
        tester.getRect(find.byKey(const ValueKey('block'))).width,
        closeTo(200 * scale, 0.1),
      );
      await tester.tapAt(Offset(1000 - 20 * scale, 20 * scale));
      expect(taps, 1);
      expect(tester.takeException(), isNull);
    });
  }
}
