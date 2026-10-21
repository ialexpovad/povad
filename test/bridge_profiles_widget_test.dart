import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:povad/design/povad_theme.dart';
import 'package:povad/domain/bridge_fleet.dart';
import 'package:povad/domain/bridge_profiles.dart';
import 'package:povad/main.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shad;

import 'bridge_fleet_test.dart' show FakeBridgeSession;
import 'widget_test.dart' show MemoryUiPreferences;

class MemoryProfiles implements BridgeProfilesStore {
  BridgeProfiles value = BridgeProfiles(
    profiles: [const BridgeProfile(id: 'legacy', number: 1)],
    selectedId: 'legacy',
  );
  @override
  Future<BridgeProfiles> read() async => value;
  @override
  Future<void> save(BridgeProfiles profiles) async => value = profiles;
}

void main() {
  testWidgets(
    'add, configure, rename, switch and restore independent profiles',
    (tester) async {
      final store = MemoryProfiles();
      final fleet = BridgeFleet(sessionFactory: FakeBridgeSession.new);
      await tester.pumpWidget(
        PovadApp(
          fleet: fleet,
          bridgeProfiles: store,
          preferences: MemoryUiPreferences()..connectionAnimation = false,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Configure bridge'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(shad.TextField).first, 'COM3');
      await tester.tap(find.byKey(const ValueKey('bridge-add')));
      await tester.pumpAndSettle();
      expect(fleet.connections.length, 2);
      final second = fleet.selected.id;
      expect(fleet.selected.profile.settings.tcpPort, '9269');
      await tester.enterText(find.byType(shad.TextField).first, 'COM7');
      await tester.tap(find.byKey(const ValueKey('bridge-edit')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('bridge-name-field')),
        'Bench B',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(fleet.selected.profile.name, 'Bench B');
      await tester.tap(find.byKey(const ValueKey('bridge-selector')));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Bridge 1').last);
      await tester.pumpAndSettle();
      expect(fleet.selected.id, 'legacy');
      expect(find.text('COM3'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('nav-0')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start bridge'));
      await tester.pumpAndSettle();
      expect(fleet.activeCount, 1);
      await tester.tap(find.byKey(const ValueKey('bridge-selector')));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Bench B').last);
      await tester.pumpAndSettle();
      expect(fleet.activeCount, 1);
      await tester.tap(find.text('Start bridge'));
      await tester.pumpAndSettle();
      expect(fleet.activeCount, 2);
      expect(store.value.selectedId, second);
      expect(store.value.profiles.map((p) => p.settings.serialPort), [
        'COM3',
        'COM7',
      ]);
      await tester.pumpWidget(const SizedBox());
      final restored = BridgeFleet(sessionFactory: FakeBridgeSession.new);
      await tester.pumpWidget(
        PovadApp(
          fleet: restored,
          bridgeProfiles: store,
          preferences: MemoryUiPreferences(),
        ),
      );
      await tester.pumpAndSettle();
      expect(restored.selected.id, second);
      expect(restored.selected.profile.name, 'Bench B');
      expect(restored.active, false);
      expect(restored.connections.every((c) => !c.allowLan), true);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('remove needs confirmation and keeps the remaining profile', (
    tester,
  ) async {
    final fleet = BridgeFleet(sessionFactory: FakeBridgeSession.new)..add();
    final id = fleet.selected.id;
    await tester.pumpWidget(
      PovadApp(fleet: fleet, preferences: MemoryUiPreferences()),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('bridge-edit')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();
    expect(fleet.connections.length, 2);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(fleet.selected.id, id);
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove').last);
    await tester.pumpAndSettle();
    expect(fleet.connections.length, 1);
    expect(fleet.selected.id, isNot(id));
    expect(tester.takeException(), isNull);
  });

  for (final language in ['en', 'be']) {
    for (final appearance in [PovadAppearance.light, PovadAppearance.dark]) {
      testWidgets(
        'compact profile controls fit $language $appearance at 200% text',
        (tester) async {
          tester.view.physicalSize = const Size(360, 700);
          tester.view.devicePixelRatio = 1;
          tester.platformDispatcher.textScaleFactorTestValue = 2;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          final fleet = BridgeFleet(sessionFactory: FakeBridgeSession.new)
            ..add();
          fleet.updateProfile(
            fleet.selected.id,
            name: 'Laboratory connection with a longer name',
          );
          await tester.pumpWidget(
            PovadApp(
              fleet: fleet,
              preferences: MemoryUiPreferences()
                ..language = language
                ..appearance = appearance,
            ),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const ValueKey('bridge-selector')));
          await tester.pump(const Duration(milliseconds: 300));
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
