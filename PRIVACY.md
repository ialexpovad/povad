# Privacy

Povad runs serial bridges locally. It relays bytes between the selected serial
device and a TCP or Bluetooth LE client. The operator chooses whether a TCP
listener is available only on the host or to the local network. LAN mode does
not authenticate clients; use it only on a trusted network. A BLE bridge
advertises to nearby devices. Pairing is required by default for an encrypted
connection. If pairing is disabled for BT24-style clients, nearby devices can
connect and send bytes to the serial device.

At startup, and when **Check for updates** is selected, Povad requests the
public release list from GitHub. The request does not include serial payloads,
port paths, or device identifiers. GitHub can receive ordinary network
metadata such as the connection's IP address.

**Send feedback** opens GitHub Issues in a browser. Povad does not attach
logs, payloads, local paths, or device identifiers to a report. The user
chooses what to submit.

Language, appearance, and animation preferences remain on the device, as do
bridge profiles and their serial, TCP, and BLE settings. Desktop login startup uses
the current user’s operating-system settings and a local initialization marker.
No startup or bridge preferences are sent to GitHub. On macOS
and Linux, bridge setup lists serial device names from `/dev` to suggest a
port; the list is not stored or sent anywhere. Povad has no analytics or
advertising SDK.
