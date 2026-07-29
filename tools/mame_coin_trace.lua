local maincpu = manager.machine.devices[":maincpu"]
local soundcpu = manager.machine.devices[":jsa:cpu"]
assert(maincpu and soundcpu, "CPU devices were not found")

local main = maincpu.spaces["program"]
local sound = soundcpu.spaces["program"]
assert(main and sound, "program spaces were not found")

local taps = {}
taps[#taps + 1] = main:install_read_tap(
	0x600030, 0x600031, "main_sound_response",
	function(offset, data, mask)
		print(string.format("MAIN response read data=%02x", data & 0xff))
		return data
	end)
taps[#taps + 1] = main:install_write_tap(
	0x600040, 0x600041, "main_sound_command",
	function(offset, data, mask)
		print(string.format("MAIN command write data=%02x", data & 0xff))
	end)
taps[#taps + 1] = sound:install_read_tap(
	0x2802, 0x2802, "sound_command",
	function(offset, data, mask)
		print(string.format("JSA command read data=%02x", data & 0xff))
		return data
	end)
taps[#taps + 1] = sound:install_read_tap(
	0x2804, 0x2804, "sound_inputs",
	function(offset, data, mask)
		print(string.format("JSA input read data=%02x", data & 0xff))
		return data
	end)
taps[#taps + 1] = sound:install_write_tap(
	0x2a02, 0x2a02, "sound_response",
	function(offset, data, mask)
		print(string.format("JSA response write data=%02x", data & 0xff))
	end)

emu.wait(5.0)

local port = manager.machine.ioport.ports[":jsa:JSAIII"]
assert(port, "JSA III input port was not found")
local coin = port.fields["Coin 1"]
assert(coin, "Coin 1 field was not found")

print(string.format("COIN before port=%02x", port:read()))
coin:set_value(1)
emu.wait(0.15)
print(string.format("COIN pressed port=%02x", port:read()))
coin:set_value(0)
emu.wait(2.0)
print(string.format("COIN released port=%02x", port:read()))

manager.machine:exit()
