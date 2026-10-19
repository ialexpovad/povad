# Povad 0.1.0-rc.3

This candidate repairs update delivery and refines the compact interface.

- Android release builds use the last working `shared_preferences_android`
  implementation. The newer 2.5.0 version fails after R8 optimization, which
  prevented settings from loading and left the in-app update action stuck.
- The Android updater continues to the system installer if saving the pending
  update state fails, and reports an installer error instead of waiting forever.
- Android release builds preserve the JNI entry points used by the USB worker.
  This restores USB–Serial discovery and opening, including the STM32 Virtual
  ComPort tested on a physical phone.
- Windows waits for its PowerShell update helper to start before closing Povad.
  If the helper cannot start, the application stays open and shows the failure.
- macOS QA builds now detect new releases and provide the release-page link.
  The unsigned QA ZIP still requires manual installation.
- The compact header places a single Menu button at the right edge. Help is
  available from that menu, and the Povad brand returns to Overview.
- Windows tray icons now include size-specific 16–256 px frames and clearer
  status shapes at small taskbar sizes.
- Settings offers a persistent **Connection animation** switch. When off, the
  active bridge and observed byte counts remain visible without moving
  signals in the Overview mark. System reduced-motion settings still apply.

## Download

- Android: signed arm64 APK. USB Host permission and a supported USB–Serial
  adapter are required for a bridge session.
- Windows: x64 ZIP. Extract the full directory before starting Povad.
- Linux: x64 tar.xz bundle. Extract it before starting Povad.
- macOS: unsigned QA ZIP for developer testing only. Public macOS distribution
  requires Developer ID signing and notarization.

**Upgrading from rc.1 or rc.2:** The Android and Windows in-app updaters in
those candidates may fail. Install rc.3 from this release page once; the
release is signed with the same Android certificate, so it can replace an
existing Android installation without clearing its data. On macOS, install
the new QA ZIP manually.

Povad checks GitHub for newer releases. On Windows, Linux, and Android it can
download a matching package and verify it against `SHA256SUMS.txt` before
installation. Android installation needs system confirmation. An active bridge
must stop before installation.

## Validation status

Automated checks cover Flutter UI and accessibility, native C ABI, simulated
binary traffic, desktop builds, Android packaging, an emulator smoke test,
and Android release-mode preference/JNI access. A physical Android phone was
used to verify that the signed APK replaces rc.1 without clearing app data,
discovers an STM32 USB Virtual ComPort, opens it, and reaches TCP listening.
Instrument byte exchange has not yet been validated. Raw bridge mode does not
interpret Modbus, choose a bus address, or change CRC byte order.

Use the attached `SHA256SUMS.txt` to verify downloaded assets.
