# Credits, modeled devices, and third-party notices

## Port and integration

- **kandowontu** — project maintainer, hardware bring-up, testing, and release.
- **OpenAI Codex** — collaborative HDL implementation, debugging, verification,
  documentation, and release engineering.

Project-authored HDL is GPL-2.0-or-later. Copyright notices that do not name an
individual refer to the project maintainer and contributors.

## FPGA CPU and sound cores

| Modeled IC | FPGA implementation | Credit | License |
|---|---|---|---|
| Motorola MC68000 | [fx68k](https://github.com/jtfpga/fx68k) | Jorge Cwik; jtfpga repository maintainers | GPL-3.0 |
| MOS 6502 family | [T65](https://github.com/mist-devel/T65) | Daniel Wallner, Mike Johnson, Wolfgang Scherr, Morten Leikvoll, SzGy, and contributors | BSD-3-Clause |
| Yamaha YM2151 | [JT51](https://github.com/jotego/jt51) | José Tejada (Jotego) | GPL-3.0-or-later |
| OKI MSM6295 | [JT6295](https://github.com/jotego/jt6295) | José Tejada (Jotego) | GPL-3.0-or-later |

Exact source revisions are recorded in [UPSTREAM.md](UPSTREAM.md). Original
license texts and copyright notices remain beside each vendored component.

## MiSTer framework and target FPGA

- MiSTer framework by Till Harbaum, Alexey Melnikov, Sorgelig, and the
  MiSTer-devel contributors.
- Target board: Terasic DE10-Nano.
- Target SoC FPGA: Intel/Altera Cyclone V SE `5CSEBA6U23I7`.
- Quartus-generated PLL, block-RAM (`altsyncram`), hard processor system,
  clocking, and I/O primitives are Intel/Altera device components.

Intel, Altera, Cyclone, Quartus, Terasic, and DE10-Nano are trademarks of
their respective owners. Their names identify compatibility and do not imply
endorsement.

## Project-native hardware blocks

The following are independent HDL implementations informed by public hardware
behavior and the MAME driver; no MAME C++ source is compiled into the core:

- Atari VAD control, scrolling, scanline IRQ, playfield, SLIP, and
  motion-object behavior;
- Atari JSA III address decode, banking, interrupts, command/response latches,
  and mixer controls;
- 2816-compatible EEPROM behavior;
- MiSTer SDRAM controller, ROM-stream loader, memory arbiter, video timing,
  palette conversion, and trackball/mouse compatibility adapter.

The currently dumped Marble Madness II prototype uses three digital joysticks.
The earlier native-trackball program mentioned by MAME is not dumped, so this
project's trackball mode deliberately translates relative mouse motion into
Player-1 joystick motion.

## Behavioral and integration references

- MAME `marblmd2` driver by David Haywood and MAME contributors,
  BSD-3-Clause. It supplied interoperability facts such as memory maps, ROM
  metadata, clocks, input polarity, graphics layouts, and device behavior.
- MiSTer Template framework and other credited MiSTer cores were inspected for
  current framework, SDRAM, and mouse-packet conventions.

## Game and hardware rights

Marble Madness II and the original arcade hardware are properties of Atari
Games and their successors. No game ROM, artwork, manual, or other copyrighted
game asset is distributed here. Users must supply a legally obtained
`marblmd2.zip`.

This preservation project is unofficial and is not affiliated with or
endorsed by Atari, MAME, MiSTer-devel, any chip manufacturer, or any upstream
FPGA-core author.
