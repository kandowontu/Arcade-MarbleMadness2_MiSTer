# Hardware reference

The MAME driver describes a prototype Atari design closest to the contemporary
Batman hardware, not the Atari System 1 board used by the original 1984
Marble Madness.

## Major devices

| Block | MAME model | FPGA status |
|---|---|---|
| Main CPU | Motorola 68000 at 14.318181 MHz | `fx68k` integrated at alternating clock enables |
| Program/graphics ROM | Board ROM sockets | Packed MRA stream stored in MiSTer SDRAM |
| Video | Atari VAD playfield and control | Scroll/EOF/IRQ control and scanline renderer integrated |
| Sprites | Atari motion objects | SLIP-linked scanline renderer and priority mixer integrated |
| Sound board | Atari JSA III | T65, JT51, JT6295, banking, IRQs, and mixer integrated |
| Nonvolatile data | Parallel 2816 EEPROM | Write unlock plus OSD load/save support |
| Screen | 456x262 total, 336x240 visible | 7.1590905 MHz pixel enable |
| Palette | 256 entries, IRGB 1:5:5:5 | Dual-port palette RAM and exact MAME mixer |

The MAME driver labels the crystals, clocks, and some board details as
unverified. Raster totals and visible dimensions are implemented; sync
positions remain provisional until measured against a PCB or a trusted trace.

## Clock and memory architecture

The core PLL generates 57.272724 MHz for core logic and 114.545448 MHz for
SDRAM. The 68000 receives alternating clock enables, giving the intended
14.318181 MHz processor rate while preserving fx68k's bus sequencing.

MiSTer's ioctl stream is backpressured until every byte is committed to SDRAM.
Even MRA bytes are written to the SDRAM high lane and odd bytes to the low lane,
matching the 68000's big-endian word view. A toggle-based arbiter gives the ROM
loader priority while downloading and round-robins main CPU, playfield,
motion-object, and OKI sample reads at runtime.

The mapped work, playfield, object, EOF, SLIP, palette, and EEPROM storage is
inferred as byte-enabled M10K RAM. CPU reads of program ROM cross to the SDRAM
clock domain; local mapped devices complete without using external memory.

## 68000 memory map

| Address | Function |
|---|---|
| `000000-07FFFF` | Main program ROM |
| `600000-600003` | Player action/start inputs |
| `600010-600013` | Sound-ready, service, vblank, and DIP status |
| `600020-600021` | Three players' joystick directions |
| `600030-600031` | JSA III response on the low byte lane |
| `600040-600041` | JSA III command on the low byte lane |
| `600050-600051` | Sound CPU reset latch |
| `600060-600061` | EEPROM write unlock |
| `601000-601FFF` | 2816 EEPROM, low byte |
| `607000-607001` | Watchdog |
| `7C0000-7C03FF` | Palette, high byte |
| `7CFFC0-7CFFFF` | VAD control registers |
| `7D0000-7D7FFF` | Work RAM |
| `7D8000-7D9FFF` | Playfield RAM |
| `7DA000-7DBEFF` | Motion-object RAM |
| `7DBF00-7DBF7F` | End-of-frame data |
| `7DBF80-7DBFFF` | SLIP table |
| `7F8000-7FBFFF` | Work RAM |

All listed ranges now complete bus cycles. The driver maps `607000` as a
deliberate no-op write, so no watchdog reset is synthesized. IRQ4 follows the
VAD scanline register and acknowledge behavior; sound responses assert IRQ6.

## Graphics format

The playfield is a 64 by 64 column-scanned tilemap of 8 by 8 tiles. Tile words
use bits 13:0 as the code and bit 15 as the priority flag. Graphics are eight
bits per pixel, assembled from two halves of the 1 MiB tile region.

Motion objects are four bits per pixel. Each entry is four 16-bit words with:

- 10-bit linked-list index;
- 15-bit graphics code plus horizontal flip;
- four-bit color, seven-bit X position, and three-bit priority;
- seven-bit Y position, three-bit width, and three-bit height.

The SLIP table selects a linked list every eight scanlines. Low-priority
playfield pixels yield to all opaque motion pixels; high-priority playfield
pixels yield only to motion colors whose palette bit 7 is set.

## JSA III sound map

The T65 runs at 1.7897725 MHz, JT51 at 3.579545 MHz, and JT6295 receives a
1.1931817 MHz enable. Its 6502 map implements 8 KiB RAM, mirrored YM2151 and
JSA I/O, four 4 KiB program banks, and the fixed `4000-FFFF` ROM window.
The 249.7 Hz periodic IRQ and YM timer IRQ share the 6502 IRQ input. Main
commands assert NMI until read; audio responses assert 68000 IRQ6 until read.
