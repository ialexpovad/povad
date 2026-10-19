# Povad release candidate

The first Povad release candidate introduces the transparent Serial ↔ TCP
bridge, a compact connection view, English and Belarusian interfaces, and
GitHub release checks.

- An animated status mark follows confirmed bridge stages and observed
  traffic, and respects reduced-motion settings.
- After an error or a client disconnect, the bridge restarts from Overview
  or Details. The worker's reason is shown directly.
- Bridge setup validates each field, suggests detected serial ports on macOS
  and Linux, and remembers the last port, baud rate, and TCP port on this
  device. LAN access is never remembered.
- Details shows session facts and received-byte counts.

## Download

- Android: signed arm64 APK. USB Host permission and a supported USB–Serial
  adapter are required for a bridge session.
- Windows: x64 ZIP. Extract the full directory before starting Povad.
- Linux: x64 tar.xz bundle. Extract it before starting Povad.
- macOS: unsigned QA ZIP for developer testing only. Public macOS distribution
  requires Developer ID signing and notarization.

Povad checks GitHub for a newer release at startup. On Windows, Linux, and
Android it can download the update in the background, verify it against
SHA256SUMS.txt, and install it when you choose Restart to update (on Android,
the system installer asks for confirmation). Installation never starts while
the bridge is running. On Windows and Linux a downloaded update is also
installed when Povad quits. Automatic download can be turned off in Settings.
The macOS QA bundle is excluded from update offers.

## Validation status

Automated checks cover native C ABI contracts, binary bridge exchange through
simulated serial endpoints, Flutter UI, desktop builds, Android native-library
packaging and an emulator smoke test. A real USB–Serial adapter and instrument
have not yet been tested. No Modbus protocol handling is claimed.

Use the attached SHA256SUMS.txt to verify downloaded assets.
