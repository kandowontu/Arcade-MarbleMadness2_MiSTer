`timescale 1ns/1ps

module mm2_cpu_realrom_tb;

logic clk = 1'b0;
always #5 clk = ~clk;

logic reset = 1'b1;
wire vblank;
wire [24:0] rom_addr;
wire rom_req;
logic [15:0] rom_dout = 16'hffff;
logic rom_ack = 1'b0;
wire [23:0] debug_address;
wire [15:0] debug_data;
wire debug_as;
wire debug_rw;
wire [31:0] debug_bus_cycles;
wire [15:0] debug_unmapped_cycles;
wire cpu_running;
wire [11:0] playfield_tile_address;
wire [15:0] playfield_tile_data;
wire  [7:0] video_palette_address;
wire [15:0] video_palette_data;
wire [11:0] motion_ram_address;
wire [15:0] motion_ram_data;
wire [8:0] playfield_xscroll;
wire [8:0] playfield_yscroll;
wire [8:0] motion_xscroll;
wire [8:0] motion_yscroll;
wire       sound_reset_n;

wire       ce_pix;
wire [8:0] h_count;
wire [8:0] v_count;
wire       hblank;
wire       hsync;
wire       vsync;

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
	.playfield_tile_address,
	.playfield_tile_data,
	.video_palette_address,
	.video_palette_data,
	.motion_ram_address,
	.motion_ram_data,
	.playfield_xscroll,
	.playfield_yscroll,
	.motion_xscroll,
	.motion_yscroll,
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
	.debug_as,
	.debug_rw,
	.debug_bus_cycles,
	.debug_unmapped_cycles,
	.cpu_running
);

logic capture_enabled = 1'b0;

wire [24:0] pf_gfx_addr;
wire pf_gfx_req;
logic [15:0] pf_gfx_dout = 16'd0;
logic pf_gfx_ack = 1'b0;
wire [7:0] pf_pixel;
wire pf_pixel_valid;
wire pf_busy;
wire pf_underrun;

mm2_playfield playfield
(
	.clk,
	.reset,
	.enable(capture_enabled),
	.ce_pix,
	.h_count,
	.v_count,
	.xscroll(playfield_xscroll),
	.yscroll(playfield_yscroll),
	.tile_address(playfield_tile_address),
	.tile_data(playfield_tile_data),
	.gfx_addr(pf_gfx_addr),
	.gfx_req(pf_gfx_req),
	.gfx_dout(pf_gfx_dout),
	.gfx_ack(pf_gfx_ack),
	.pixel_data(pf_pixel),
	.pixel_valid(pf_pixel_valid),
	.busy(pf_busy),
	.underrun(pf_underrun)
);

wire [24:0] mo_gfx_addr;
wire mo_gfx_req;
logic [15:0] mo_gfx_dout = 16'd0;
logic mo_gfx_ack = 1'b0;
wire [7:0] mo_pixel;
wire mo_pixel_opaque;
wire mo_pixel_valid;
wire mo_busy;
wire mo_underrun;

mm2_motion_objects motion_objects
(
	.clk,
	.reset,
	.enable(capture_enabled),
	.ce_pix,
	.h_count,
	.v_count,
	.xscroll(motion_xscroll),
	.yscroll(motion_yscroll),
	.ram_address(motion_ram_address),
	.ram_data(motion_ram_data),
	.gfx_addr(mo_gfx_addr),
	.gfx_req(mo_gfx_req),
	.gfx_dout(mo_gfx_dout),
	.gfx_ack(mo_gfx_ack),
	.pixel_data(mo_pixel),
	.pixel_opaque(mo_pixel_opaque),
	.pixel_valid(mo_pixel_valid),
	.busy(mo_busy),
	.underrun(mo_underrun)
);

reg [7:0] program_rom [0:2424831];
string rom_path;
string trace_path;
string frame_path;
integer rom_file;
integer trace_file;
integer frame_file;
integer bytes_read;
integer target_cycles = 100000;
integer response_delay = 0;
integer system_cycles = 0;
  integer frame_count = 0;
  reg mo_underrun_d = 1'b0;
integer rom_cycles = 0;
integer ram_7d_cycles = 0;
integer ram_7f_cycles = 0;
integer io_cycles = 0;
integer unmapped_cycles = 0;
integer trace_cycle = 0;
logic observed_req = 1'b0;
logic vblank_d = 1'b0;
logic saw_sp_hi = 1'b0;
logic saw_sp_lo = 1'b0;
logic saw_pc_hi = 1'b0;
logic saw_pc_lo = 1'b0;
logic saw_first_opcode = 1'b0;

always_ff @(posedge clk) begin
	if (pf_gfx_req != pf_gfx_ack) begin
		pf_gfx_dout <= {
			program_rom[pf_gfx_addr],
			program_rom[pf_gfx_addr + 1'b1]};
		pf_gfx_ack <= pf_gfx_req;
	end
	if (mo_gfx_req != mo_gfx_ack) begin
		mo_gfx_dout <= {
			program_rom[mo_gfx_addr],
			program_rom[mo_gfx_addr + 1'b1]};
		mo_gfx_ack <= mo_gfx_req;
	end
end

logic [7:0] mixed_palette_address;
logic mixed_pixel_valid;
always_comb begin
	mixed_palette_address = {1'b0, pf_pixel[6:0]};
	mixed_pixel_valid = pf_pixel_valid;
	if (mo_pixel_valid && mo_pixel_opaque) begin
		if (!pf_pixel_valid || !pf_pixel[7]) begin
			mixed_palette_address = mo_pixel | 8'h80;
			mixed_pixel_valid = 1'b1;
		end
		else if (mo_pixel[7]) begin
			mixed_palette_address = mo_pixel;
			mixed_pixel_valid = 1'b1;
		end
	end
end
assign video_palette_address = mixed_palette_address;

wire [5:0] frame_r6 = {
	video_palette_data[14:10], video_palette_data[15]};
wire [5:0] frame_g6 = {
	video_palette_data[9:5], video_palette_data[15]};
wire [5:0] frame_b6 = {
	video_palette_data[4:0], video_palette_data[15]};
wire [7:0] frame_red   = {frame_r6, frame_r6[5:4]};
wire [7:0] frame_green = {frame_g6, frame_g6[5:4]};
wire [7:0] frame_blue  = {frame_b6, frame_b6[5:4]};

reg [23:0] frame_buffer [0:80639];
integer frame_index;

  always_ff @(posedge clk) begin
  	mo_underrun_d <= mo_underrun;
  	if (capture_enabled && mo_underrun && !mo_underrun_d)
  		$display("REAL_ROM motion underrun first seen at h=%0d v=%0d busy=%0d",
  			h_count, v_count, mo_busy);

  	if (capture_enabled && ce_pix
		&& (h_count < 9'd336) && (v_count < 9'd240)) begin
		frame_buffer[(v_count * 336) + h_count]
			<= mixed_pixel_valid
			? {frame_red, frame_green, frame_blue} : 24'd0;
	end
end

always_ff @(posedge clk) begin
	system_cycles <= system_cycles + 1;
	vblank_d <= vblank;
	if (vblank && !vblank_d)
		frame_count <= frame_count + 1;

	if (rom_req != observed_req) begin
		observed_req <= rom_req;
		response_delay <= 2;

		if (rom_addr >= 25'h0080000) begin
			$display("FAIL: CPU ROM request outside main program: %07x",
				rom_addr);
			$fatal(1);
		end

		case (rom_addr)
			25'h0000000: saw_sp_hi <= 1'b1;
			25'h0000002: saw_sp_lo <= 1'b1;
			25'h0000004: saw_pc_hi <= 1'b1;
			25'h0000006: saw_pc_lo <= 1'b1;
			25'h00009be: saw_first_opcode <= 1'b1;
			default: begin
			end
		endcase
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

	// Count and trace each newly accepted non-IACK bus request.
	if (!reset
		&& (dut.bus_state == 2'd0)
		&& !dut.cpu_as_n
		&& dut.cpu_iack_n) begin
		trace_cycle = trace_cycle + 1;
		$fdisplay(trace_file, "%0d,%06x,%0d,%0d,%0d,%04x,%01x,%0d",
			trace_cycle,
			dut.cpu_bus_address,
			dut.cpu_rw,
			!dut.cpu_uds_n,
			!dut.cpu_lds_n,
			dut.cpu_data_out,
			dut.cpu_fc,
			dut.mapped_cycle);

		if (dut.cs_program)
			rom_cycles <= rom_cycles + 1;
		else if (dut.cs_ram_7d)
			ram_7d_cycles <= ram_7d_cycles + 1;
		else if (dut.cs_ram_7f)
			ram_7f_cycles <= ram_7f_cycles + 1;
		else if (dut.mapped_cycle)
			io_cycles <= io_cycles + 1;
		else begin
			unmapped_cycles <= unmapped_cycles + 1;
			if (unmapped_cycles < 16)
				$display("UNMAPPED cycle=%0d address=%06x rw=%0d data=%04x",
					trace_cycle, dut.cpu_bus_address, dut.cpu_rw,
					dut.cpu_data_out);
		end
	end
end

task automatic require(input logic condition, input string message);
begin
	if (!condition) begin
		$display("FAIL: %s", message);
		$fatal(1);
	end
end
endtask

initial begin
	if (!$value$plusargs("ROM=%s", rom_path)) begin
		$display("FAIL: use +ROM=<packed-ROM-path>");
		$fatal(1);
	end
	if (!$value$plusargs("TRACE=%s", trace_path))
		trace_path = "mm2_bus_trace.csv";
	if (!$value$plusargs("CYCLES=%d", target_cycles))
		target_cycles = 100000;
	if ($value$plusargs("FRAME=%s", frame_path))
		capture_enabled = 1'b1;

	rom_file = $fopen(rom_path, "rb");
	if (rom_file == 0) begin
		$display("FAIL: unable to open packed ROM: %s", rom_path);
		$fatal(1);
	end
	bytes_read = $fread(program_rom, rom_file);
	$fclose(rom_file);
	require(bytes_read == 2424832,
		"packed ROM contains the complete 0x250000-byte stream");

	for (frame_index = 0; frame_index < 80640;
		frame_index = frame_index + 1)
		frame_buffer[frame_index] = 24'd0;

	trace_file = $fopen(trace_path, "w");
	if (trace_file == 0) begin
		$display("FAIL: unable to open trace output: %s", trace_path);
		$fatal(1);
	end
	$fdisplay(trace_file, "cycle,address,rw,uds,lds,write_data,fc,mapped");

	$display("REAL_ROM initial_sp=%02x%02x%02x%02x initial_pc=%02x%02x%02x%02x",
		program_rom[0], program_rom[1], program_rom[2], program_rom[3],
		program_rom[4], program_rom[5], program_rom[6], program_rom[7]);

	repeat (20) @(posedge clk);
	reset <= 1'b0;

	while ((debug_bus_cycles < target_cycles)
		&& (system_cycles < 20000000))
		@(posedge clk);

	$fclose(trace_file);

	if (capture_enabled) begin
		frame_file = $fopen(frame_path, "wb");
		require(frame_file != 0, "frame output can be opened");
		$fwrite(frame_file, "P6\n336 240\n255\n");
		for (frame_index = 0; frame_index < 80640;
			frame_index = frame_index + 1) begin
			$fwrite(frame_file, "%c%c%c",
				frame_buffer[frame_index][23:16],
				frame_buffer[frame_index][15:8],
				frame_buffer[frame_index][7:0]);
		end
		$fclose(frame_file);
		$display("REAL_ROM frame=%s pf_underrun=%0d mo_underrun=%0d",
			frame_path, pf_underrun, mo_underrun);
	end

	require(saw_sp_hi && saw_sp_lo, "68000 fetched both real initial-SP words");
	require(saw_pc_hi && saw_pc_lo, "68000 fetched both real initial-PC words");
	require(saw_first_opcode, "68000 fetched the real reset entry point");
	require(cpu_running, "CPU reports real program-ROM execution");
	require(debug_bus_cycles >= target_cycles,
		"CPU completed the requested number of real-ROM bus cycles");

	$display("REAL_ROM summary cycles=%0d rom=%0d ram7d=%0d ram7f=%0d io=%0d unmapped=%0d frames=%0d",
		debug_bus_cycles, rom_cycles, ram_7d_cycles, ram_7f_cycles,
		io_cycles, unmapped_cycles, frame_count);
	$display("REAL_ROM trace=%s", trace_path);
	$display("mm2_cpu_realrom_tb: PASS");
	$finish;
end

endmodule
