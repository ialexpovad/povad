# Povad 0.1.0-rc.2

This candidate improves the bridge setup and desktop experience while keeping
Serial ↔ TCP traffic byte-transparent.

- The compact header keeps Help and Menu at the right edge. Select the Povad
  brand to return to Overview from any page.
- Windows now discovers current COM ports and lets you refresh the list,
  alongside existing macOS and Linux port discovery.
- Serial setup exposes None, Even, and Odd parity with standard 8N1, 8E1,
  and 8O1 framing. The selection is remembered locally.
- Desktop starts in a compact window and restores its saved size and position.
  When a bridge is active, closing the window offers to keep it running in the
  tray, stop and quit, or cancel.
- Monochrome tray icons show stopped, listening, connected, and error states.
- Optional **Wait for next client** accepts three or more sequential clients
  without reopening the serial port. It is off by default because late device
  responses can be ambiguous across clients.
- A second client is closed immediately and counted as a busy rejection.
- Optional exact IPv4 allowlist restricts LAN clients. The Bridge page shows
  QR codes with `povad-bridge://` addresses.
- When LAN access is enabled and the bridge is listening, DNS-SD advertises
  `_povad-bridge._tcp` with `v`, `mode`, `port`, `serial`, and `busy` TXT fields.

## Download

- Android: signed arm64 APK. USB Host permission and a supported USB–Serial
  adapter are required for a bridge session.
- Windows: x64 ZIP. Extract the full directory before starting Povad.
- Linux: x64 tar.xz bundle. Extract it before starting Povad.
- macOS: unsigned QA ZIP for developer testing only. Public macOS distribution
  requires Developer ID signing and notarization.

Povad checks GitHub for newer releases. On Windows, Linux, and Android it can
download a matching package, verify it against `SHA256SUMS.txt`, and install it
after the active bridge stops. Android installation needs system confirmation.
The macOS QA bundle is excluded from update offers.

## Validation status

Automated checks cover the Flutter UI, native C ABI, simulated binary traffic,
desktop builds, Android packaging, and an emulator smoke test. A real
USB–Serial adapter and instrument have not yet been tested. Raw bridge mode
does not interpret Modbus, choose a bus address, or change CRC byte order.

Use the attached `SHA256SUMS.txt` to verify downloaded assets.
