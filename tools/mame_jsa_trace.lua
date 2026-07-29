local maincpu = manager.machine.devices[":maincpu"]
local soundcpu = manager.machine.devices[":jsa:cpu"]
assert(maincpu and soundcpu, "CPU devices were not found")

local main = maincpu.spaces["program"]
local sound = soundcpu.spaces["program"]
assert(main and sound, "program spaces were not found")

local taps = {}
local io_reads = 0
local io_writes = 0

taps[#taps + 1] = sound:install_read_tap(
	0x2800, 0x2dff, "jsa_io_read",
	function(offset, data, mask)
		if io_reads < 160 then
			print(string.format(
				"JSA R %04x=%02x PC=%04x",
				offset, data & 0xff, soundcpu.state["PC"].value))
			io_reads = io_reads + 1
		end
		return data
	end)

taps[#taps + 1] = sound:install_write_tap(
	0x2800, 0x2fff, "jsa_io_write",
	function(offset, data, mask)
		if io_writes < 160 then
			print(string.format(
				"JSA W %04x=%02x PC=%04x",
				offset, data & 0xff, soundcpu.state["PC"].value))
			io_writes = io_writes + 1
		end
	end)

emu.wait(1.0)
print(string.format("JSA PC after 1s=%04x", soundcpu.state["PC"].value))

local port = manager.machine.ioport.ports[":jsa:JSAIII"]
assert(port, "JSA III input port was not found")
local coin = port.fields["Coin 1"]
assert(coin, "Coin 1 field was not found")

print(string.format("COIN before port=%02x", port:read()))
coin:set_value(1)
emu.wait(0.20)
print(string.format("COIN pressed port=%02x", port:read()))
coin:set_value(0)
emu.wait(0.50)
print(string.format(
	"COIN released port=%02x JSA_PC=%04x reads=%d writes=%d",
	port:read(), soundcpu.state["PC"].value, io_reads, io_writes))

manager.machine:exit()
