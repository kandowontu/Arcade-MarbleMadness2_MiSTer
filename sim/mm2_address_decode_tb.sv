`timescale 1ns/1ps

module mm2_address_decode_tb;

logic [23:0] address;
logic cs_program;
logic cs_p1_buttons;
logic cs_p2_buttons;
logic cs_status;
logic cs_joysticks;
logic cs_sound_response;
logic cs_sound_command;
logic cs_latch;
logic cs_eeprom_unlock;
logic cs_eeprom;
logic cs_watchdog;
logic cs_palette;
logic cs_vad_control;
logic cs_workram;
logic cs_playfield;
logic cs_motion;
logic cs_eof;
logic cs_slip;

wire [17:0] selects = {
	cs_slip,
	cs_eof,
	cs_motion,
	cs_playfield,
	cs_workram,
	cs_vad_control,
	cs_palette,
	cs_watchdog,
	cs_eeprom,
	cs_eeprom_unlock,
	cs_latch,
	cs_sound_command,
	cs_sound_response,
	cs_joysticks,
	cs_status,
	cs_p2_buttons,
	cs_p1_buttons,
	cs_program
};

mm2_address_decode dut(.*);

task automatic check(input logic [23:0] test_address, input integer select_index);
	logic [17:0] expected;
	begin
		address = test_address;
		#1;
		expected = (select_index < 0) ? 18'd0 : (18'd1 << select_index);
		if (selects !== expected) begin
			$display("address=%06x expected=%05x actual=%05x",
			         test_address, expected, selects);
			$fatal(1, "address decode mismatch");
		end
	end
endtask

initial begin
	check(24'h000000, 0);
	check(24'h07ffff, 0);
	check(24'h080000, -1);
	check(24'h600000, 1);
	check(24'h600003, 2);
	check(24'h600010, 3);
	check(24'h600013, 3);
	check(24'h600020, 4);
	check(24'h600030, 5);
	check(24'h600031, 5);
	check(24'h600040, 6);
	check(24'h600041, 6);
	check(24'h600050, 7);
	check(24'h600061, 8);
	check(24'h601000, 9);
	check(24'h601fff, 9);
	check(24'h607001, 10);
	check(24'h7c0000, 11);
	check(24'h7c03ff, 11);
	check(24'h7cffc0, 12);
	check(24'h7cffff, 12);
	check(24'h7d0000, 13);
	check(24'h7d7fff, 13);
	check(24'h7d8000, 14);
	check(24'h7d9fff, 14);
	check(24'h7da000, 15);
	check(24'h7dbeff, 15);
	check(24'h7dbf00, 16);
	check(24'h7dbf7f, 16);
	check(24'h7dbf80, 17);
	check(24'h7dbfff, 17);
	check(24'h7f8000, 13);
	check(24'h7fbfff, 13);
	check(24'h7fc000, -1);

	$display("mm2_address_decode_tb: PASS");
	$finish;
end

endmodule
