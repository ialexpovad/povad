<p align="center">
  <img src="assets/brand/icon-256.png" width="88" alt="Povad icon">
</p>

<h1 align="center">Povad</h1>

<p align="center">A simple way to connect a serial device to a TCP client.</p>

<p align="center">
  <a href="https://github.com/ialexpovad/povad/releases"><img alt="Latest release" src="https://img.shields.io/github/v/release/ialexpovad/povad?include_prereleases&label=release"></a>
  <a href="https://github.com/ialexpovad/povad/actions/workflows/ui.yml"><img alt="Build and UI checks" src="https://github.com/ialexpovad/povad/actions/workflows/ui.yml/badge.svg"></a>
  <a href="LICENSE"><img alt="MIT license" src="https://img.shields.io/badge/license-MIT-18181b"></a>
</p>

<p align="center">
  <a href="https://github.com/ialexpovad/povad/releases">Download</a> ·
  <a href="https://github.com/ialexpovad/povad/issues/new/choose">Feedback</a> ·
  <a href="PRIVACY.md">Privacy</a>
</p>

![Povad running a serial to TCP bridge](assets/preview/connection_activity.gif)

Povad's first module is a **transparent Serial ↔ TCP bridge**. It forwards the
bytes it receives in both directions, shows the actual connection state, and
keeps an active desktop session reachable from the system tray. The interface
is available in English and Belarusian, with light and dark themes.

## Get started

1. Download the package for your platform from [Releases](https://github.com/ialexpovad/povad/releases).
2. Connect a serial device. In **Bridge**, choose its port, baud rate, and parity.
3. Select **Start bridge**. Povad listens on `127.0.0.1:9268` by default.
4. Point a TCP client at the displayed endpoint. To accept clients on your
   local network, explicitly enable **Allow LAN clients** and copy a listed
   LAN address.

Povad accepts one TCP client at a time and immediately rejects a second.
By default, a disconnect ends the session. **Wait for next client** can keep
the listener open for reconnection; a late device response could reach a later
client, so use it only when your device protocol makes that acceptable.
LAN clients can send bytes directly to the serial device. The bridge has no
authentication; use LAN access on a trusted network and optionally restrict it
to exact client IPv4 addresses.

| Platform | Release package | Notes |
| --- | --- | --- |
| Windows | x64 ZIP | Extract the entire folder before launching. |
| Linux | x64 tar.xz | Extract the bundle before launching. |
| Android | arm64 APK | The phone hosts a USB–Serial adapter through USB-OTG. |
| macOS | unsigned QA ZIP | Developer testing only; public distribution needs signing and notarization. |

The current [release candidate](https://github.com/ialexpovad/povad/releases)
includes SHA-256 checksums. Povad can check GitHub Releases for updates and
download matching Windows, Linux, and Android packages. It verifies downloaded
packages before offering installation; installing on Android also requires
system confirmation. An active bridge is stopped before an update is installed.

## What the bridge does

- Relays serial and TCP bytes without changing their contents or order.
- Shows whether the serial port is open, a client is waiting or connected, and
  whether bytes have actually arrived in each direction.
- Remembers local bridge settings; LAN access resets to off on every launch.
- Lets a running desktop bridge remain active when its window is closed.
- Advertises an active LAN bridge as `_povad-bridge._tcp` with its port, serial
  name, and busy state. The Bridge page shows a QR code for each LAN address.

Povad does **not** interpret Modbus, choose a device address, recalculate a
CRC, or swap CRC bytes. A frame such as `01 07 41 E2` passes through exactly as
received. Protocol-aware tools may come later as a separate, explicit mode.
Povad is currently a bridge host, not a TCP client for another Povad host.

Automated checks cover UI behavior, native bridge contracts, simulated binary
traffic, desktop builds, and an Android emulator. Physical USB–Serial adapters
and instruments still require validation. The macOS package is an unsigned QA
build.

## Contribute

See [CONTRIBUTING.md](CONTRIBUTING.md) for development and testing. Use
[GitHub Issues](https://github.com/ialexpovad/povad/issues/new/choose) for
feedback, and [SECURITY.md](SECURITY.md) for security reports. Povad does not
attach device data or local logs when opening the feedback page.

Povad is released under the [MIT License](LICENSE).
