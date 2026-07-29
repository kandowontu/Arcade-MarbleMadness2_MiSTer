emu.wait(1.0)

for tag, port in pairs(manager.machine.ioport.ports) do
	print("PORT " .. tag)
	for name, field in pairs(port.fields) do
		print(string.format("  FIELD %s mask=%04x",
			name, field.mask))
	end
end

manager.machine:exit()
