# Release build status

## Toolchain and target

- Quartus Prime Lite Edition 17.0.0 Build 595
- Cyclone V device support
- Icarus Verilog 11.0
- Target board: MiSTer DE10-Nano
- Target device: Intel/Altera Cyclone V SE `5CSEBA6U23I7`
- Release build date: 2026-07-30

## Verification

The focused simulation suite passes:

```text
mm2_storage_reset_wiring: PASS
mm2_address_decode_tb: PASS
mm2_rom_layout_tb: PASS
mm2_rom_loader_tb: PASS
mm2_memory_arbiter_tb: PASS
mm2_vad_tb: PASS
mm2_playfield_tb: PASS
mm2_motion_objects_tb: PASS
mm2_sdram_tb: PASS
mm2_sound_comm_tb: PASS
mm2_jsa_inputs_tb: PASS
mm2_trackball_to_joystick_tb: PASS
mm2_cpu_reset_tb: PASS (1,498 bus cycles)
```

All 19 ROM members match the CRCs pinned by the MRA. The local packer
produces the expected `0x250000`-byte stream:

```text
SHA-256: 4F2123930A5E5B1F19AB3211E6E30014B6F9DFBF3935CFF68B1E576DAAB6D30D
```

The real-ROM 68000 regression completes 100,000 bus cycles with zero
unmapped accesses. After the reset-vector accesses that precede MAME's
debugger hook, all 99,994 comparable cycles match the independent MAME trace
by address, direction, and write value.

The dedicated JSA startup regression also passes:

```text
REAL_ROM JSA reset released cycles=7892958 bus=420010 latch=00d0
mm2_sound_reset_realrom_tb: PASS
```

This specifically covers the byte-strobe timing fix that made Coin, Start,
gameplay input, music, and effects reliable on hardware.

## Quartus result

The release build completes with zero errors:

```powershell
C:\intelFPGA_lite\17.0\quartus\bin64\quartus_sh.exe `
  --flow compile MarbleMadness2 -c MarbleMadness2
```

| Resource | Used | Available | Utilization |
|---|---:|---:|---:|
| Logic utilization | 35,170 ALMs | 41,910 ALMs | 84% |
| Registers | 34,663 | | |
| Block memory bits | 1,752,767 | 5,662,720 | 31% |
| RAM blocks | 238 | 553 | 43% |
| DSP blocks | 40 | 112 | 36% |
| PLLs | 3 | 6 | 50% |

Quartus reports positive timing slack:

- setup: +0.252 ns overall;
- hold: +0.184 ns;
- recovery: +3.598 ns;
- removal: +0.640 ns;
- minimum pulse width: +0.396 ns.

The standard MiSTer framework constraints do not fully constrain every
board-level setup and hold path, so these results should not be interpreted as
complete external-I/O timing sign-off. The core's internal clocks close and
the release image has been validated on physical SDRAM and HDMI.

## Hardware result

The final RBF was loaded through the release MRA on a physical MiSTer. The ROM
stream completed, attract/gameplay video rendered without diagnostic overlays,
and the running core name was `marblmd2`. Earlier hardware validation on the
same implementation established working Coin, Start, directions, gameplay,
music, and effects.

Service/Test is exposed both as an OSD toggle and a remappable controller
input. Player-1 USB trackball/mouse compatibility is default-on and has a
focused simulation; it translates relative motion into the digital joystick
inputs used by the dumped prototype.

## Artifact

```text
output_files\MarbleMadness2.rbf
Size: 3,743,512 bytes
SHA-256: C6866118B50B4F59BBECC1DBC736705717D6EFBB0E102F68DDE83D38812D4832
```

No ROM data is present in the RBF, MRA, repository, or release package.

```text
output_files\MarbleMadness2_MiSTer_v1.0.2.zip
Size: 1,936,108 bytes
SHA-256: D8173EF41EB3B5CE5B90F276FF578862247A8E34DFB330B2B301C9BF10ABFD42
```
