# Povad 0.1.0

The first stable release: a focused Serial ↔ TCP bridge for everyday device connections.

## Highlights

- Run multiple independent bridges, each with its own saved serial settings and TCP port.
- Discover LAN bridges with Bonjour or share their addresses with QR codes.
- Keep active connections in the desktop tray or Android foreground notification.
- Choose English or Belarusian, light or dark themes, and optional traffic animation.
- **New: Open at login.** Enabled on the first launch of this desktop release; turn it off in Settings. Changes made in system startup settings are respected. macOS requires 13 or later. Bridges still start manually.
- Refreshed README with a light/dark screenshot and an animated interface preview.

## Install or update

Download the package for your platform. Extract the entire desktop bundle into
a permanent folder before opening Povad. Existing bridge profiles are preserved.
RC3 and RC4 can discover this stable release through the in-app updater; all
bridges must stop before installation. Android uses the same release signing
identity and a higher version code. Users of RC1 or RC2 should update manually.

Windows and Linux packages are x64; Android is arm64 and requires USB-OTG for
serial devices. Multiple Android adapters need a compatible USB hub.

**macOS remains an unsigned QA package for manual testing.** Developer ID signing
and notarization are not available; the stable version number does not change
that distribution limitation.

Use the attached `SHA256SUMS.txt` to verify downloads. Povad forwards bytes
unchanged. Enable LAN access only on a trusted network; it resets on launch.
