# Marble Madness II MiSTer v1.0.2

Updater-submission release of the hardware-validated Marble Madness II
prototype core for MiSTer. The FPGA image is unchanged from v1.0.1.

## Distribution changes

- Added the standard `releases/` directory required for MiSTer integration.
- Added the dated `Arcade-MarbleMadness2_20260730.rbf` release image.
- Placed the primary MRA directly in `releases/`.
- Packaged the install ZIP with `_Arcade` at the archive root so it can be
  extracted directly to `/media/fat`.

## Fixes

- Corrected the Player-1 USB trackball/mouse Y-axis direction so upward
  physical motion generates Up and downward physical motion generates Down.

## Included features

- Working attract mode, Coin, Start, gameplay controls, music, and effects on
  a physical MiSTer DE10-Nano.
- Clean release video with all bring-up overlays removed.
- Atari VAD playfield, motion objects, priority mixer, scanline IRQ, and
  scrolling.
- Atari JSA III audio using T65, JT51, and JT6295.
- Service/Test exposed in the Controls OSD page and as a remappable input.
- Default-on Player-1 USB trackball/mouse compatibility with four sensitivity
  levels.
- EEPROM load and explicit save-back support.
- Exact 100,000-cycle real-ROM/MAME bus-trace regression and focused JSA reset
  regression.

## Install

Copy:

```text
Marble Madness II (prototype).mra
    -> /media/fat/_Arcade/Marble Madness II (prototype).mra
MarbleMadness2.rbf
    -> /media/fat/_Arcade/cores/MarbleMadness2.rbf
your legally obtained marblmd2.zip
    -> /media/fat/games/mame/marblmd2.zip
```

Launch the MRA from the Arcade menu. Do not launch the RBF directly.

## Trackball note

The dumped prototype program is the later three-joystick revision. MAME notes
that an earlier native-trackball program existed but is not dumped. This
release therefore translates MiSTer relative mouse/trackball motion into the
Player-1 digital directions expected by the available program; it is not
native analog trackball emulation.

No game ROMs are included. See `CREDITS.md` and `UPSTREAM.md` for authors,
modeled ICs, exact upstream revisions, licenses, and acknowledgements.
