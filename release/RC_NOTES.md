# Povad 0.1.0-rc.4

This candidate adds independent Serial ↔ TCP bridges in one application.

- Use **+** beside the bridge selector to add a connection. Each bridge has its
  own serial port, baud rate, parity, TCP port, client policy, and saved name.
  The previous configuration migrates to **Bridge 1**. The collection can grow
  beyond two connections.
- Switch bridges without stopping them. Each native worker owns its serial
  device, TCP listener, queues, and counters; a fault or stop in one bridge
  does not stop another.
- Serial devices and overlapping TCP listener addresses are reserved before
  startup. Conflicts identify the bridge already using the endpoint.
- Each LAN bridge has its own QR endpoint and `_povad-bridge._tcp` service,
  including an independent busy state. LAN access still starts off after an
  application restart.
- The desktop tray and Android foreground notification aggregate all workers.
  Quitting and updates require confirmed shutdown of every bridge, including
  a bridge still starting. Stopping the selected bridge leaves others running.
- Saved profiles and the last selection survive an application restart.
  Android USB selections and permissions must be renewed; reconnecting a
  different physical device never silently starts a saved session.

## Try two connections

1. Configure **Bridge 1**, for example `COM3` with TCP port `9268`.
2. Add another bridge, for example `COM7` with TCP port `9269`.
3. Start each bridge. To connect over the local network, enable **Allow LAN
   clients** separately and use each bridge's displayed address.
4. Connect one TCP client to each endpoint. Each bridge accepts one client;
   **Wait for next client** applies independently to each bridge.

## Downloads and updates

- Android: signed arm64 APK. Multiple adapters require a USB host hub and
  compatible USB–Serial devices.
- Windows: x64 ZIP. Extract the entire directory before launching.
- Linux: x64 tar.xz bundle. Extract the bundle before launching.
- macOS: unsigned QA ZIP; manual installation for developer testing only.
  Public macOS distribution still requires signing and notarization.

RC3 can check for this candidate and download the matching Windows, Linux,
or Android package once it is published. Android installation needs system
confirmation. Users of RC1 or RC2 should install the new package manually
because those updaters may fail. Android signing identity is unchanged.
Use `SHA256SUMS.txt` to verify the downloaded assets.

## Qualification

Two-device physical acceptance is pending. The owner will test the candidate
with their own equipment. Automated tests cover separate profiles, migration,
endpoint reservations, lifecycle races, update blocking, notifications, and
parallel binary streams through two native workers using virtual serial ports.
These tests do not qualify a physical USB hub, adapter, or instrument. macOS
Bonjour and Android NSD have separate integration checks.

This release stays a draft while automated candidate gates and physical
acceptance are outstanding. Raw mode remains byte-transparent: Povad does
not choose Modbus unit addresses, reinterpret frames, or modify CRC bytes.
