// Motorola 68000 byte-address decoder derived from MAME marblmd2_map().

module mm2_address_decode
(
	input  logic [23:0] address,

	output logic cs_program,
	output logic cs_p1_buttons,
	output logic cs_p2_buttons,
	output logic cs_status,
	output logic cs_joysticks,
	output logic cs_sound_response,
	output logic cs_sound_command,
	output logic cs_latch,
	output logic cs_eeprom_unlock,
	output logic cs_eeprom,
	output logic cs_watchdog,
	output logic cs_palette,
	output logic cs_vad_control,
	output logic cs_workram,
	output logic cs_playfield,
	output logic cs_motion,
	output logic cs_eof,
	output logic cs_slip
);

always_comb begin
	cs_program       = (address >= 24'h000000) && (address <= 24'h07ffff);
	cs_p1_buttons    = (address >= 24'h600000) && (address <= 24'h600001);
	cs_p2_buttons    = (address >= 24'h600002) && (address <= 24'h600003);
	cs_status        = (address >= 24'h600010) && (address <= 24'h600013);
	cs_joysticks     = (address >= 24'h600020) && (address <= 24'h600021);
	// The JSA register is physically connected to D7:0. Decode the complete
	// 68000 word and let LDS decide whether the low-byte device participates.
	cs_sound_response = (address >= 24'h600030)
	                  && (address <= 24'h600031);
	cs_sound_command = (address >= 24'h600040)
	                 && (address <= 24'h600041);
	cs_latch         = (address >= 24'h600050) && (address <= 24'h600051);
	cs_eeprom_unlock = (address >= 24'h600060) && (address <= 24'h600061);
	cs_eeprom        = (address >= 24'h601000) && (address <= 24'h601fff);
	cs_watchdog      = (address >= 24'h607000) && (address <= 24'h607001);
	cs_palette       = (address >= 24'h7c0000) && (address <= 24'h7c03ff);
	cs_vad_control   = (address >= 24'h7cffc0) && (address <= 24'h7cffff);
	cs_workram       = ((address >= 24'h7d0000) && (address <= 24'h7d7fff))
	                || ((address >= 24'h7f8000) && (address <= 24'h7fbfff));
	cs_playfield     = (address >= 24'h7d8000) && (address <= 24'h7d9fff);
	cs_motion        = (address >= 24'h7da000) && (address <= 24'h7dbeff);
	cs_eof           = (address >= 24'h7dbf00) && (address <= 24'h7dbf7f);
	cs_slip          = (address >= 24'h7dbf80) && (address <= 24'h7dbfff);
end

endmodule
