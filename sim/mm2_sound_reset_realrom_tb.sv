`timescale 1ns/1ps

// Focused real-ROM regression for the 68000/JSA reset-latch bus timing.
module mm2_sound_reset_realrom_tb;

logic clk = 1'b0;
always #5 clk = ~clk;

logic reset = 1'b1;
wire ce_pix;
wire [8:0] h_count;
wire [8:0] v_count;
wire hblank;
wire hsync;
wire vblank;
wire vsync;

mm2_video_timing video_timing
(
	.clk,
	.reset,
	.ce_pix,
	.h_count,
	.v_count,
	.hblank,
	.hsync,
	.vblank,
	.vsync
);

wire [24:0] rom_addr;
wire rom_req;
logic [15:0] rom_dout = 16'hffff;
logic rom_ack = 1'b0;
wire sound_reset_n;
wire [31:0] debug_bus_cycles;
wire [23:0] debug_address;
wire [15:0] debug_data;

mm2_cpu_subsystem dut
(
	.clk,
	.reset,
	.ce_pix,
	.h_count,
	.v_count,
	.vblank,
	.service(1'b0),
	.dip_switches(16'h00ff),
	.joystick_p1(16'd0),
	.joystick_p2(16'd0),
	.joystick_p3(16'd0),
	.rom_addr,
	.rom_req,
	.rom_dout,
	.rom_ack,
	.playfield_tile_address(12'd0),
	.playfield_tile_data(),
	.video_palette_address(8'd0),
	.video_palette_data(),
	.motion_ram_address(12'd0),
	.motion_ram_data(),
	.playfield_xscroll(),
	.playfield_yscroll(),
	.motion_xscroll(),
	.motion_yscroll(),
	.sound_command(),
	.sound_command_ready(),
	.sound_command_read(1'b0),
	.sound_response(8'd0),
	.sound_response_write(1'b0),
	.sound_response_ready(),
	.sound_nmi_n(),
	.sound_reset_n,
	.eeprom_host_write(1'b0),
	.eeprom_host_address(11'd0),
	.eeprom_host_data(8'd0),
	.eeprom_host_q(),
	.eeprom_dirty(),
	.debug_address,
	.debug_data,
	.debug_as(),
	.debug_rw(),
	.debug_bus_cycles,
	.debug_unmapped_cycles(),
	.cpu_running()
);

reg [7:0] program_rom [0:2424831];
string rom_path;
integer rom_file;
integer bytes_read;
integer response_delay = 0;
integer system_cycles = 0;
logic observed_req = 1'b0;

always_ff @(posedge clk) begin
	system_cycles <= system_cycles + 1;

	if (rom_req != observed_req) begin
		observed_req <= rom_req;
		response_delay <= 2;
	end
	else if (response_delay != 0) begin
		response_delay <= response_delay - 1;
		if (response_delay == 1) begin
			rom_dout <= {
				program_rom[rom_addr],
				program_rom[rom_addr + 1'b1]
			};
			rom_ack <= observed_req;
		end
	end
end

initial begin
	if (!$value$plusargs("ROM=%s", rom_path)) begin
		$display("FAIL: use +ROM=<packed-ROM-path>");
		$fatal(1);
	end

	rom_file = $fopen(rom_path, "rb");
	if (rom_file == 0) begin
		$display("FAIL: unable to open packed ROM: %s", rom_path);
		$fatal(1);
	end
	bytes_read = $fread(program_rom, rom_file);
	$fclose(rom_file);
	if (bytes_read != 2424832) begin
		$display("FAIL: packed ROM size=%0d", bytes_read);
		$fatal(1);
	end

	repeat (20) @(posedge clk);
	reset <= 1'b0;

	while (!sound_reset_n && (system_cycles < 20000000))
		@(posedge clk);

	if (!sound_reset_n) begin
		$display("FAIL: JSA reset stayed asserted after cycles=%0d bus=%0d address=%06x data=%04x",
			system_cycles, debug_bus_cycles, debug_address, debug_data);
		$fatal(1);
	end

	$display("REAL_ROM JSA reset released cycles=%0d bus=%0d latch=%04x",
		system_cycles, debug_bus_cycles, dut.latch_data);
	$display("mm2_sound_reset_realrom_tb: PASS");
	$finish;
end

endmodule
