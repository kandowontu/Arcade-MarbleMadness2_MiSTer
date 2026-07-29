# Bring-up roadmap

## Phase 1: framework and specification

- [x] Create an independent MiSTer project from the current template.
- [x] Pin the MAME driver and template revisions.
- [x] Encode and simulate the 68000 address map.
- [x] Define the complete MRA ROM ordering and logical-region mapper.
- [x] Generate the documented raster totals and visible area.
- [x] Validate the integrated RBF on a DE10-Nano.

## Phase 2: main CPU and memory

- [x] Integrate a cycle-compatible 68000 core at 14.318181 MHz.
- [x] Add SDRAM storage for program and graphics ROMs.
- [x] Add on-chip RAM for work RAM, palette, playfield, motion objects,
  EOF data, and SLIP data.
- [x] Verify reset vectors, opcode fetch, and continued execution with a
  synthetic CPU simulation.
- [x] Execute 100,000 real-ROM FPGA bus cycles with zero unmapped accesses.
- [x] Match all 99,994 post-reset comparable cycles against an independent
  MAME trace by address, direction, and write data.

Exit criterion met: repeatable execution into the game's initialization code
with zero unexpected unmapped accesses and an exact MAME bus-trace match.

## Phase 3: Atari VAD playfield

- [x] Implement VAD control registers, scroll latches, and scanline IRQ4.
- [x] Decode the eight-bit playfield graphics format.
- [x] Render the 64 by 64 column-scanned tilemap into dual line buffers.
- [x] Verify scrolling, horizontal flip, and priority-bit behavior in focused
  simulation.
- [x] Add an integrated real-ROM 336x240 framebuffer capture regression.
- [ ] Compare an attract-mode FPGA frame at a matched emulation timestamp.
- [x] Validate attract-mode backgrounds on a DE10-Nano.

Exit criterion met: complete attract-mode backgrounds and motion objects render
on hardware.

## Phase 4: motion objects and mixer

- [x] Traverse SLIP-linked object lists every eight scanlines.
- [x] Fetch and decode four-bit motion-object graphics.
- [x] Implement size, position, horizontal flip, palette, and priority fields.
- [x] Reproduce MAME's object/playfield priority rules.
- [x] Recover at scanline boundaries from an invalid or overlong startup list.

Exit criterion: complete attract-mode video with stable priorities.

## Phase 5: Atari JSA III sound

- [x] Integrate the 6502 audio CPU and its 64 KiB program ROM.
- [x] Add main/audio command latches, NMI, and IRQ6 signaling.
- [x] Integrate YM2151 and OKI M6295-compatible HDL.
- [x] Recreate the two populated OKI socket address windows and banking.
- [x] Implement JSA clock ratios, timed IRQ, reset, and volume controls.

Exit criterion: music, samples, and command handshakes match MAME traces.

## Phase 6: persistence and hardware validation

- [x] Implement 2816 unlock/write behavior.
- [x] Map three players, service input, action/start buttons, and DIP switches.
- [x] Validate Coin, Start, directions, gameplay, music, and effects on MiSTer.
- [x] Expose Service/Test through the OSD and controller remapping.
- [x] Add default-on Player-1 USB trackball/mouse compatibility.
- [x] Add MiSTer `.EEP` load and explicit save-back plumbing.
- [x] Implement the sound-reset latch; retain MAME's deliberate watchdog NOP.
- [x] Fix 68000 byte-strobe acceptance so the JSA reset latch is reliable.
- [ ] Test analog/direct video and perform a matched long-run frame comparison.

Hardware exit criterion met for ordinary HDMI operation: the prototype boots,
coins, starts, plays, and produces JSA III audio on a physical MiSTer.
