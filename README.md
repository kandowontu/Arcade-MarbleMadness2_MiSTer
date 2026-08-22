# Marble Madness II (prototype) for MiSTer FPGA

A hardware implementation of Atari Games' unreleased 1991 **Marble Madness
II** prototype for the MiSTer DE10-Nano.

The core is hardware-validated: the MRA loads the complete ROM set, the
prototype reaches attract mode, Coin and Start work, gameplay controls work,
and the Atari JSA III music and effects run on a physical MiSTer.

No game ROMs are included.

## Features

- Cycle-compatible Motorola 68000 execution through the `fx68k` FPGA core.
- Atari VAD playfield, scanline IRQ, scrolling, palette, SLIP-linked motion
  objects, and playfield/object priority mixing.
- Atari JSA III audio with a T65 6502, JT51 YM2151, and JT6295 OKI MSM6295.
- Three-player digital controls, Coin, Start/Action, Service/Test, DIP
  switches, and 2816-compatible EEPROM persistence.
- Default-on USB trackball/mouse compatibility for Player 1.
- MiSTer SDRAM ROM storage and a validated 19-file MRA packing layout.
- Focused simulations plus real-ROM 68000 and JSA reset regressions.

## Install

The ROM-free updater artifacts are kept in `releases/` using the standard
MiSTer arcade-core naming convention. For a manual installation, copy the
release files and your legally obtained MAME ROM set to these exact paths:

```text
/media/fat/_Arcade/Marble Madness II (prototype).mra
/media/fat/_Arcade/cores/MarbleMadness2.rbf
/media/fat/games/mame/marblmd2.zip
```

Launch **Marble Madness II (prototype)** from the Arcade menu. The MRA is
required: it verifies and combines the 19 ROM files into the byte stream
expected by the core. Do not launch the RBF directly from `_Other`.

## Controls

| Input | Function |
|---|---|
| D-pad / stick | Move |
| Action / A | Action and player Start |
| Start | Player Start |
| Coin / Select | Insert coin |
| Service/Test | Momentary service input |

The game labels each player's action button as that player's Start input.

USB trackballs and mice control Player 1 through a mouse-to-joystick adapter
because the dumped prototype program is the later joystick revision. The
earlier native-trackball program is not dumped. Trackball/mouse mode is on by
default:

- motion controls Player 1;
- left button is Action/Start;
- right button is Coin;
- 25%, 50%, 100%, and 200% sensitivity are available under **Controls**.

Digital controllers continue to work while trackball/mouse support is on.

## Service and test menus

Open the MiSTer OSD, choose **Controls**, and set **Service/Test mode** to
**On**. Use directions to navigate and Action/Start to select. Set the option
back to **Off** to return to ordinary operation.

The Service/Test control can also be assigned in MiSTer's controller remap
screen. This is a momentary input; the OSD toggle is more convenient for
extended testing. MAME documents that the prototype itself can report service
RAM-test issues, so a reported RAM failure is not necessarily an FPGA fault.

## EEPROM

Load a 2048-byte `.EEP` file from the OSD when desired. After changing
bookkeeping or test settings, choose **Save EEPROM** to write it back.

## Build and test

Use Quartus Prime Lite 17.0.x with Cyclone V device support:

```powershell
C:\intelFPGA_lite\17.0\quartus\bin64\quartus_sh.exe --flow compile MarbleMadness2
```

Run the focused simulations with Icarus Verilog:

```powershell
powershell -ExecutionPolicy Bypass -File tools\test.ps1
```

Real-ROM tests require a local, legally obtained `marblmd2.zip` and are kept
out of source control:

```powershell
powershell -ExecutionPolicy Bypass -File tools\test_real_rom.ps1
```

The generated MiSTer image is
`output_files\MarbleMadness2.rbf`.

For an updater release, copy the generated image to `releases/` as
`Arcade-MarbleMadness2_YYYYMMDD.rbf`. Keep the primary MRA directly in that
same directory. The repository intentionally does not contain game ROMs.

## ROM layout

The MRA sends a packed `0x250000`-byte stream:

- `0x000000-0x07ffff`: interleaved 68000 program;
- `0x080000-0x08ffff`: JSA III 6502 program;
- `0x090000-0x18ffff`: playfield graphics;
- `0x190000-0x20ffff`: motion-object graphics;
- `0x210000-0x24ffff`: the two populated OKI sample sockets.

The HDL restores the OKI data to its original logical windows.

## Credits and licensing

This port is maintained by
[kandowontu](https://github.com/kandowontu) and was developed collaboratively
with OpenAI Codex. See [CREDITS.md](CREDITS.md) for the complete list of
authors, upstream FPGA cores, modeled ICs, reference projects, and device
acknowledgements.

Project-authored HDL is licensed under GPL-2.0-or-later. The combined build
contains GPL-3.0 FPGA components, so this repository and its compiled release
are distributed under GPL-3.0-compatible terms; the root `LICENSE` contains
GPL-3.0. Every vendored component retains its own copyright and license notice.

Atari, Marble Madness, Motorola, MOS Technology, Yamaha, OKI, Intel, Altera,
Terasic, and MiSTer names are used only to identify compatible hardware.
This project is unofficial and is not affiliated with or endorsed by those
rights holders.
