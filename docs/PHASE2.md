# Phase 2 CPU and memory bring-up

## Data path

```text
MiSTer HPS ioctl
      |
      v
ROM layout validation and byte-lane packing
      |
      v
loader/CPU arbiter <------ fx68k program-ROM bus
      |
      v
114.545448 MHz SDR SDRAM controller
```

The loader holds `ioctl_wait` while a byte is pending, so the HPS cannot
overrun SDRAM. It tracks all expected ROM regions, validates the packed stream
layout, and only releases the CPU after the final write is acknowledged.

During execution, fx68k program reads use the same request/acknowledge path.
All non-ROM devices are local to the 57.272724 MHz core clock domain.

## Implemented 68000 behavior

- exact MAME address-range selection;
- big-endian upper/lower byte writes;
- program ROM reads from SDRAM;
- block-RAM-backed work and video memory;
- high-byte palette RAM and low-byte 2816 EEPROM;
- one-write EEPROM unlock semantics;
- VAD control-register storage;
- three-player action, start, and directional inputs;
- service, vblank, DIP, and sound-ready status;
- provisional vblank IRQ4 with auto-vector acknowledge;
- non-blocking open-bus completion and unmapped-cycle diagnostics.

The JSA command/response and reset addresses currently behave as safe main-side
stubs. They prevent the 68000 from hanging but are not an audio implementation.

## Verification performed

Six Icarus tests cover decoding, packed-ROM translation, loader
backpressure/byte lanes, memory arbitration, the SDRAM command/read/write
sequence, and the real fx68k reset sequence. The CPU test observes stack-pointer
and program-counter vector reads followed by a synthetic opcode fetch and
continued execution with no unmapped accesses.

Quartus 17 completes synthesis, placement, assembly, and TimeQuest with zero
errors. Internal setup and hold slacks are positive. See `BUILD.md` for exact
resource and artifact data.

## Real-program validation

The supplied ROM set passes every MRA CRC. fx68k executes the real reset vectors
and completes a 100,000-cycle bus trace with zero unmapped accesses. An
independent MAME watchpoint trace matches every address, transfer direction,
and write value for the 99,994 cycles after the FPGA-only reset/prefetch
prefix.

This trace found a lane-decoding defect at the low-byte JSA response word and
verified its correction. The Phase 2 CPU/memory functional exit criterion is
therefore complete.

Physical MiSTer testing is still required before the SDRAM controller can be
considered proven: the current SDC derives internal clocks but does not yet
model board-level SDRAM input/output delays. Quartus does confirm that every
SDRAM DQ output-enable copy is packed into its Cyclone V I/O cell.
