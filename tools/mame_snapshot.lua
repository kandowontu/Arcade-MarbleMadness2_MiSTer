-- Capture a deterministic native MAME reference frame after four seconds.
-- Run with the command documented in docs/BUILD.md.

emu.wait(4.0)
emu.wait_next_frame()

local screen = manager.machine.screens[":screen"]
assert(screen, "Marble Madness II screen device was not found")

local error_code = screen:snapshot("mame_reference.png")
assert(not error_code, "MAME reference snapshot failed")

manager.machine:exit()
