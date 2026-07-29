# Upstream provenance

## MiSTer framework

- Repository: `https://github.com/MiSTer-devel/Template_MiSTer.git`
- Commit: `69b8a2acc6d84dd313b5abcba6a17155287ed3d8`
- Retrieved: 2026-07-27
- Local remote: `template-upstream`

The framework is pinned to this revision. A small set of Quartus 17
compatibility edits is carried in `sys/hq2x.sv`, `sys/video_mixer.sv`,
`sys/osd.v`, `sys/iir_filter.v`, `sys/f2sdram_safe_terminator.sv`,
`sys/ddr_svc.sv`, `sys/hps_io.sv`, and `sys/sys_top.v`. These preserve
framework behavior while avoiding constructs rejected by the older Standard
Edition parser.

## MAME hardware reference

- Repository: `https://github.com/mamedev/mame.git`
- Commit inspected: `c1b0c8ddacae2a5890461d0b4ca165fe011fea6c`
- Driver: `src/mame/atari/marblmd2.cpp`
- Driver license: BSD-3-Clause
- Retrieved: 2026-07-27

No MAME source code or game ROM data is copied into this repository. Hardware
addresses, timing constants, graphics layouts, and ROM metadata are recorded
as interoperability facts and independently expressed in HDL and XML.

MAME 0.287 was also used locally only as an independent executable reference.
It verified the supplied ROM set and produced instruction and memory-watchpoint
traces. Generated traces and ROM-derived data stay below the ignored `roms`
directory and are not project source.

## 68000 core

- Repository: `https://github.com/jtfpga/fx68k.git`
- Commit: `1217ab8dc600de070c6adb71ea6fe69de8855362`
- Path: `rtl/fx68k` (vendored, self-contained snapshot)
- License: GPL-3.0
- Retrieved: 2026-07-27

The project-authored HDL is GPL-2.0-or-later, so it may be distributed with
this GPL-3.0 dependency under GPL-3.0-compatible terms.

## JSA III FPGA components

- T65: `https://github.com/mist-devel/T65.git`
  at `7027ad169553911b1d55ce6d220364e7c8595b94`
- JT51: `https://github.com/jotego/jt51.git`
  at `4a47f666b67b52b9016f390bcfe3255da0128762`
- JT6295: `https://github.com/jotego/jt6295.git`
  at `65a5fe118c89173350ce0fc20aa9d06927f46676`

The pinned source snapshots are vendored below `rtl/vendor`. T65 retains its
permissive license; JT51 and JT6295 retain GPL-3.0-or-later notices and license
files. JT6295 is built with interpolation disabled, so its optional JTFRAME FIR
dependency is not required.

## MiSTer SDRAM implementation reference

- Repository: `https://github.com/MiSTer-devel/Arcade-TaitoF2_MiSTer.git`
- Commit inspected: `9438df98f1ea826c5398db43587992def0124603`
- File inspected: `rtl/sdram.sv`
- Retrieved: 2026-07-27

This was used to confirm MiSTer SDRAM interface conventions. The controller in
`rtl/mm2_sdram.sv` is a project-native implementation rather than copied code.

## MiSTer mouse/trackball interface reference

- Repository:
  `https://github.com/MiSTer-devel/Arcade-QBert_MiSTer.git`
- Commit inspected: `100303616014441cf1c74549456333b95a05dfc2`
- Retrieved: 2026-07-29

The core was inspected only to confirm the current `hps_io.ps2_mouse` packet
layout. `rtl/mm2_trackball_to_joystick.sv` is a project-native implementation
for the joystick-based Marble Madness II prototype.
