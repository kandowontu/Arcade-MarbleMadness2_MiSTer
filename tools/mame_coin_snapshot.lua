emu.wait(5.0)

local port = manager.machine.ioport.ports[":jsa:JSAIII"]
assert(port, "JSA III input port was not found")
local coin = port.fields["Coin 1"]
assert(coin, "Coin 1 field was not found")

print(string.format("COIN before=%d", port:read() & 0x01))
coin:set_value(1)
emu.wait(0.15)
print(string.format("COIN pressed=%d", port:read() & 0x01))
coin:set_value(0)
emu.wait(1.0)
print(string.format("COIN released=%d", port:read() & 0x01))

local screen = manager.machine.screens[":screen"]
assert(screen, "screen was not found")
local error_code = screen:snapshot("mame_coin_reference.png")
assert(not error_code, "snapshot failed")

manager.machine:exit()
