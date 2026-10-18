# Security policy

This project has no published security-supported release yet. Please avoid posting
secrets, captured device payloads, or host inventories in public issues.

For a suspected vulnerability, use GitHub's private vulnerability reporting for
this repository once it is enabled. Until then, contact the maintainer through the
profile linked in the README and request a private channel before sharing details.

The Serial ↔ TCP bridge does not add authentication or encryption to the device
protocol. A listener bound to a LAN address must be explicitly enabled and used on
a trusted network.
