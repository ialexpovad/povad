# Povad 0.2.0

Povad 0.2.0 adds a Serial ↔ Bluetooth LE bridge alongside the existing
Serial ↔ TCP bridge. Each bridge has separate serial and transport settings.

## Highlights

- BLE GATT write and notify characteristics use configurable UUIDs and forward
  bytes unchanged. The bridge serves one BLE client at a time.
- Serial settings support one or two stop bits. For BDKG-11M, use `115200 8N2`.
- Interface scale now resizes the complete application, including controls and
  overlays, from 75% to 125%. The setting persists across launches.
- Windows BLE startup waits for the system to confirm complete advertising and
  reports advertising failures. The Windows native build works from project
  paths containing spaces.

## BLE compatibility

- macOS and Android BLE have been exercised with real serial hardware in both
  directions. Android 8 (API 26) or later is required.
- Windows BLE requires an adapter and driver that report support for the BLE
  peripheral role. Building and native tests pass, but operation with a
  compatible Windows adapter has not been verified. Windows advertises under
  the computer's Bluetooth name; clients can search for the service UUID.
- Linux BLE builds and passes native tests, but has not been verified with a
  Bluetooth adapter and serial device.

Windows and Linux BLE remain experimental pending hardware verification.
**Require pairing** is enabled by default. Disable it only for a client that
cannot pair, such as BT24-compatible software; a nearby device may then write
to the connected serial device.

## Downloads

- **Windows x64:** extract the complete ZIP and run `povad.exe`.
- **Linux x64:** extract the tar.xz bundle and run `povad` on a system with
  BlueZ.
- **Android arm64:** install the signed APK and connect a compatible USB–Serial
  adapter through USB-OTG.
- **macOS:** the unsigned QA ZIP is for manual testing. Public distribution
  requires Developer ID signing and notarization.

Release assets include `SHA256SUMS.txt`. Stop active bridges before installing
an update. Report issues at https://github.com/ialexpovad/povad/issues.
