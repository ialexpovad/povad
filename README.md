<p align="center"><img src="assets/brand/icon-256.png" width="88" alt="Povad icon"></p>

# Povad

**Device connectivity, starting with a transparent Serial ↔ TCP bridge.**

Povad is an open-source application in development for connecting devices and
network clients. Its first module is planned to relay bytes between a serial
port and TCP in both directions without changing the byte stream.

`Serial device ↔ Povad ↔ TCP client`

The platform is designed to grow with other transports, protocols, and virtual
ports as each capability is specified and tested.

![Povad interface preview](assets/preview/overview.png)

## Current status

The repository contains a working macOS Flutter **interface preview** and
project runners for Windows, Linux, and Android. It shows connection states, a single primary action,
compact endpoints, and English and Belarusian UI. The preview does **not** open a
serial port or TCP listener. Its state controls are for design review only.
There is no public product release or verified hardware support yet.

An embedded C++17 transport core and typed Dart FFI package are under
development in `packages/povad_core`. Native contract tests exercise a
transparent serial ↔ TCP session with a pseudo-terminal and loopback socket
on desktop platforms. The app is not wired to the core yet; Android USB-OTG
hosting remains unimplemented.

Android USB-OTG hosting and GitHub-based update delivery are planned. Platform
support will be published after each implementation passes build, UI, and real
hardware validation.

## Run the interface preview

With Flutter installed, run:

```sh
flutter pub get
flutter run -d macos
```

The macOS build was checked with Flutter 3.47.1. Run `flutter analyze` and
`flutter test` before submitting a change. UI tests use
[Alchemist](https://pub.dev/packages/alchemist) to compare the overview with
committed reference images in English and Belarusian at desktop and narrow
screen sizes. A widget test checks the primary action's label alignment.
GitHub Actions runs formatting, analysis, widget, visual, and accessibility
checks on every push and pull request. It also runs a macOS app smoke test and
builds interface previews for macOS, Linux, Windows, and Android. A successful
build does not establish serial hardware support. After an intentional visual
change, inspect the generated images and update the references with
`flutter test --update-goldens`.

## Feedback

Use [GitHub Issues](https://github.com/ialexpovad/povad/issues/new/choose) for
feature requests and reproducible problems. Please follow the
[security policy](SECURITY.md) for suspected vulnerabilities.

## License

Povad is available under the [MIT License](LICENSE).
