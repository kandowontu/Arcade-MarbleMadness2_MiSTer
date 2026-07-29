`timescale 1ns/1ps

module mm2_cpu_reset_tb;

logic clk = 1'b0;
always #5 clk = ~clk;

logic reset = 1'b1;
logic ce_pix = 1'b0;
logic [8:0] h_count = 9'd0;
logic [8:0] v_count = 9'd0;
logic vblank = 1'b0;
wire [24:0] rom_addr;
wire rom_req;
logic [15:0] rom_dout = 16'h4e71;
logic rom_ack = 1'b0;
wire [23:0] debug_address;
wire [15:0] debug_data;
wire debug_as;
wire debug_rw;
wire [31:0] debug_bus_cycles;
wire [15:0] debug_unmapped_cycles;
wire cpu_running;
wire [15:0] playfield_tile_data;
wire [15:0] video_palette_data;
wire [15:0] motion_ram_data;
wire [8:0] playfield_xscroll;
wire [8:0] playfield_yscroll;
wire [8:0] motion_xscroll;
wire [8:0] motion_yscroll;
logic eeprom_host_write = 1'b0;
logic [10:0] eeprom_host_address = 11'd0;
logic [7:0] eeprom_host_data = 8'd0;
wire [7:0] eeprom_host_q;
wire eeprom_dirty;

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
	.playfield_tile_data,
	.video_palette_address(8'd0),
	.video_palette_data,
	.motion_ram_address(12'd0),
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
	.sound_reset_n(),
	.eeprom_host_write,
	.eeprom_host_address,
	.eeprom_host_data,
	.eeprom_host_q,
	.eeprom_dirty,
	.debug_address,
	.debug_data,
	.debug_as,
	.debug_rw,
	.debug_bus_cycles,
	.debug_unmapped_cycles,
	.cpu_running
);

integer response_delay = 0;
logic observed_req = 1'b0;
logic saw_sp_hi = 1'b0;
logic saw_sp_lo = 1'b0;
logic saw_pc_hi = 1'b0;
logic saw_pc_lo = 1'b0;
logic saw_first_opcode = 1'b0;

function automatic [15:0] synthetic_rom(input logic [24:0] address);
begin
	case (address)
		25'h0000000: synthetic_rom = 16'h007d; // initial SP = 0x007d1000
		25'h0000002: synthetic_rom = 16'h1000;
		25'h0000004: synthetic_rom = 16'h0000; // initial PC = 0x00000010
		25'h0000006: synthetic_rom = 16'h0010;
		25'h0000010: synthetic_rom = 16'h60fe; // BRA.S $10
		default:     synthetic_rom = 16'h4e71; // NOP
	endcase
end
endfunction

always_ff @(posedge clk) begin
	if (rom_req != observed_req) begin
		observed_req  <= rom_req;
		response_delay <= 2;
		case (rom_addr)
			25'h0000000: saw_sp_hi <= 1'b1;
			25'h0000002: saw_sp_lo <= 1'b1;
			25'h0000004: saw_pc_hi <= 1'b1;
			25'h0000006: saw_pc_lo <= 1'b1;
			25'h0000010: saw_first_opcode <= 1'b1;
			default: ;
		endcase
	end
	else if (response_delay != 0) begin
		response_delay <= response_delay - 1;
		if (response_delay == 1) begin
			rom_dout <= synthetic_rom(rom_addr);
			rom_ack  <= observed_req;
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
	repeat (20) @(posedge clk);
	reset <= 1'b0;

	repeat (30000) @(posedge clk);

	require(saw_sp_hi && saw_sp_lo, "68000 fetched both initial-SP words");
	require(saw_pc_hi && saw_pc_lo, "68000 fetched both initial-PC words");
	require(saw_first_opcode, "68000 fetched the first instruction");
	require(cpu_running, "CPU reports program-ROM execution");
	require(debug_bus_cycles >= 5, "bus fabric completed reset-vector cycles");
	require(debug_unmapped_cycles == 0, "reset loop made no unmapped accesses");
	eeprom_host_address = 11'h123;
	#1;
	require(eeprom_host_q == 8'hff, "EEPROM powers up erased");
	@(negedge clk);
	eeprom_host_data = 8'ha5;
	eeprom_host_write = 1'b1;
	@(posedge clk);
	@(negedge clk);
	eeprom_host_write = 1'b0;
	#1;
	require(eeprom_host_q == 8'ha5, "host can restore an EEPROM byte");

	$display("mm2_cpu_reset_tb: PASS (%0d bus cycles)", debug_bus_cycles);
	$finish;
end

endmodule
