# Povad 0.2.0-rc.2

This is a test candidate for the Serial ↔ Bluetooth LE bridge. It also keeps
the existing transparent Serial ↔ TCP bridge.

This build replaces `0.2.0-rc.1`. Do not use the `rc.1` Android APK; its
release optimizer removed JNI classes needed to start the USB and BLE worker.

## What to test

- Select **BLE** in Bridge setup, choose a serial device, and configure the
  service, write, and notify UUIDs. Defaults are `FFE0`, `FFE2`, and `FFE1`.
- The serial settings include one or two stop bits. For BDKG-11M, use
  `115200 8N2`.
- Set **Interface scale** in Settings from 75% to 125%. The default 100% keeps
  the existing size; the choice is saved on the device.
- A client can write with or without response and receive notifications. The
  bridge forwards bytes unchanged and serves one BLE client at a time.
- **Require pairing** is on by default. Turn it off only when testing a
  BT24-style client that does not pair. In that mode, a nearby device can
  connect and send bytes to the serial device.
- Test disconnects, serial removal, restarting, and stopping during traffic.
  Report any error or uncertain-delivery message, with the OS and adapter
  model. Do not include device payloads or serial numbers in public reports.

## Platform status

- **macOS and Android:** the BLE bridge has been exercised with real serial
  hardware in both directions. The Android release keeps the JNI classes needed
  by the USB and BLE native worker. Android targets Android 8 (API 26) and
  later; API 26 and current Android emulator checks are part of CI.
- **Linux:** the BlueZ backend builds and passes native tests in Ubuntu 24.04,
  but has not been tested with a Bluetooth adapter and serial device.
- **Windows:** the C++/WinRT GATT backend builds and passes native tests in CI,
  and the Windows application builds. Bluetooth hardware and serial operation
  still need testing. Windows advertises under the computer's Bluetooth name,
  not the editable name used on other platforms; clients can search for service
  UUID `FFE0`.

Windows and Linux BLE are experimental in this candidate. Their hardware
results are required before claiming working platform support. The release
remains a draft while those results and the other release gates are gathered.

## Install and report

- Windows: extract the complete x64 ZIP and run `povad.exe`.
- Linux: extract the x64 tar.xz bundle and run `povad` on a system with BlueZ.
- Android: install the signed arm64 APK and connect a compatible USB–Serial
  adapter through USB-OTG. Existing profiles are preserved.
- macOS: the unsigned QA ZIP is for manual testing. Public distribution still
  needs Developer ID signing and notarization.

This prerelease does not appear as an update to installations of stable
`0.1.0`; install it manually. Check the attached `SHA256SUMS.txt` before use.
Report findings at https://github.com/ialexpovad/povad/issues.
