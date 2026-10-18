# Contributing

Povad has no public release yet. Feature proposals and feedback on hardware
support are welcome through the GitHub issue templates. If you tested a
development build, include its commit ID, operating system, serial adapter,
and clear reproduction steps.

Please discuss a new transport or protocol module in an issue before opening a
pull request. Its data handling, ownership, and acceptance tests need to be
specified first.

For interface changes, use Flutter 3.47.1 and run:

```sh
flutter pub get
dart format lib test integration_test
flutter analyze
flutter test --concurrency=1
```

On macOS, run `flutter test integration_test/app_test.dart -d macos` to check
the application in its desktop runner. Review changed golden images before
updating their references. CI also compiles the other platform runners; a
successful build does not prove hardware behavior.

For changes under `packages/povad_core`, run the standalone native contract
tests as well:

```sh
cmake -S packages/povad_core -B build/native -DCMAKE_BUILD_TYPE=Debug
cmake --build build/native --config Debug
ctest --test-dir build/native --build-config Debug --output-on-failure
cd packages/povad_core
dart format --output=none --set-exit-if-changed hook lib test
dart analyze --fatal-infos
dart test
```

The native C ABI is versioned. Changes to its structs or ownership rules need
matching native and Dart regression tests before they are used by the app.
Regenerate the committed bindings with `dart run ffigen --config ffigen.yaml`
when the public C header changes, and review the resulting diff.

Keep issue reports and pull requests in English. Do not post device payloads,
secrets, serial numbers, or absolute local paths in public reports.
