# Povad

**Device connectivity, starting with a transparent Serial ↔ TCP bridge.**

Povad is an open-source application in development for connecting devices and
network clients. Its first module will relay data between a serial port and TCP
in both directions while preserving the byte stream.

`Serial device ↔ Povad ↔ TCP client`

The project is designed to grow with other transports, protocols, and virtual
ports as each capability is defined and tested.

## Project status

There is no public release yet. Windows, macOS, Linux, and Android are target
platforms; live support will be listed after validation on real hardware. On
Android, Povad is planned to act as a USB-OTG host for a serial adapter.

The interface will use English by default and offer Belarusian as a second
language.

## Feedback

Use [GitHub Issues](https://github.com/ialexpovad/povad/issues/new/choose) for
feature requests and reproducible problems. Please follow the
[security policy](SECURITY.md) for suspected vulnerabilities.

## License

Povad is available under the [MIT License](LICENSE).
