# Phase 3: Atari VAD primary playfield

Phase 3 replaces the diagnostic-only raster with the first game-video path.
It implements the subset of Atari's VAD device used by the Marble Madness II
primary playfield while leaving motion objects and the final priority mixer for
Phase 4.

## VAD control path

`rtl/mm2_vad.sv` implements the 32-word control array and the 28-word
end-of-frame shadow used by the game. Nonzero EOF words are replayed in
ascending address order at the start of scanline zero.

Indexed control words use the same selectors as the pinned MAME VAD device:

| Selector | Function |
|---:|---|
| `0xA` | PF1 horizontal scroll |
| `0xB` | PF0 horizontal scroll |
| `0xF` | PF0 vertical scroll |

The displayed playfield horizontal position is PF0 plus the low three bits of
PF1 plus the four-pixel board offset configured by the driver. The vertical
position comes from PF0.

Control word 3 supplies the scanline IRQ target. IRQ4 asserts at the selected
line and remains asserted until the CPU writes control word `0x1e`. Reading
control word zero returns the current scanline, clamped to 255, with the
vertical-blank indication added above visible line 239.

## Tile and graphics decode

The playfield is a 64 by 64 array of 8 by 8 tiles. RAM is column scanned, so
the 12-bit word address is:

```text
tile_address = column * 64 + row
```

Tile-word bits 13:0 select the graphics code and bit 15 selects horizontal
flip. Each eight-bit graphics pixel is split across the two 0x80000-byte
halves of the playfield ROM region. Four 16-bit SDRAM reads reconstruct one
tile row:

```text
first half:  pixels 0/2, then 4/6
second half: pixels 1/3, then 5/7
```

Graphics bit 7 is retained as the playfield priority bit. Bits 6:0 select one
of 128 playfield palette entries.

## Scanline renderer

`rtl/mm2_playfield.sv` renders the following scanline during the current one.
It reads tile words through the second port of the 48 KiB work/video RAM and
graphics words through a third SDRAM-arbiter client. A registered-address
fetch stage models the physical M10K latency.

Even and odd output lines use separate 336-pixel buffers. At zero fine scroll,
42 tiles and exactly 168 SDRAM word reads produce one visible line. Nonzero
fine scroll fetches the partial tile required at the right edge. A sticky
underrun flag records any missed line deadline.

The ROM loader has highest SDRAM priority. After loading, CPU and video
requests alternate priority so neither client can starve.

## Palette

The palette device is eight bits wide on the 68000 upper byte lane. Consecutive
CPU words supply the high and low bytes of each of 256 IRGB1555 entries. A
true-dual-port M10K allows simultaneous CPU access and video lookup.

The intensity bit becomes the least significant bit of all three six-bit color
components:

```text
red6   = {raw[14:10], raw[15]}
green6 = {raw[9:5],   raw[15]}
blue6  = {raw[4:0],   raw[15]}
```

Each six-bit component expands to eight bits by repeating its two most
significant bits.

## Verification

Focused VAD simulation covers byte writes, all three indexed scroll selectors,
EOF replay, scanline/vblank reads, IRQ assertion, and explicit acknowledge.

Focused playfield simulation uses registered-latency tile RAM and a
request/acknowledge graphics-ROM model. It checks the exact eight-pixel decode,
horizontal flip, priority-bit retention, 42-tile line completion, and absence
of underrun.

The complete focused suite also covers address decoding, ROM layout/loading,
three-client arbitration, SDRAM, and CPU reset execution. The 100,000-access
real-ROM CPU trace remains identical to the independent MAME trace after the
six reset/prefetch accesses.

## Remaining Phase 3 validation

The integrated video path has synthesized and closes internal timing, but its
real-ROM framebuffer has not yet been automatically compared with a MAME
capture or tested on a DE10-Nano. Motion objects are intentionally absent, so
characters and marbles will not appear until Phase 4.
