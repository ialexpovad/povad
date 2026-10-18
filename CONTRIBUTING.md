# Contributing

Povad is in a source migration phase. Please open an issue before building a new
protocol or transport module so its wire behavior, ownership, and acceptance tests
can be agreed first.

Changes to the transport ABI or handle lifetime require native and Flutter tests.
Raw bridging must preserve bytes exactly. Tests that need physical hardware should
state the adapter, OS, permissions, device, and observed result; a simulation is
identified as such. Never include payloads, host paths, or binaries without consent.

Use English for source comments, implementation docs, and issue reports. The application
interface uses English by default and offers Belarusian as a second language. Public
repository documentation remains in English.
