`timescale 1ns/1ps

module mm2_playfield_tb;

logic clk = 1'b0;
always #5 clk = ~clk;

logic reset = 1'b1;
logic enable = 1'b1;
logic ce_pix = 1'b0;
logic [8:0] h_count = 9'd0;
logic [8:0] v_count = 9'd261;
logic [8:0] xscroll = 9'd0;
logic [8:0] yscroll = 9'd0;
wire [11:0] tile_address;
logic [15:0] tile_data = 16'd0;
wire [24:0] gfx_addr;
wire gfx_req;
logic [15:0] gfx_dout = 16'd0;
logic gfx_ack = 1'b0;
wire [7:0] pixel_data;
wire pixel_valid;
wire busy;
wire underrun;

mm2_playfield dut
(
	.clk,
	.reset,
	.enable,
	.ce_pix,
	.h_count,
	.v_count,
	.xscroll,
	.yscroll,
	.tile_address,
	.tile_data,
	.gfx_addr,
	.gfx_req,
	.gfx_dout,
	.gfx_ack,
	.pixel_data,
	.pixel_valid,
	.busy,
	.underrun
);

// Model the registered-address video port of the physical M10K. Column zero
// is normal and column one is horizontally flipped. All columns select tile
// code zero so the ROM response is shared.
always_ff @(posedge clk) begin
	tile_data <= (tile_address[11:6] == 6'd1)
	           ? 16'h8000 : 16'h0000;
end

function automatic [15:0] graphics_word(input logic [24:0] address);
begin
	case (address)
		25'h0090000: graphics_word = 16'h8102; // pixels 0,2
		25'h0090002: graphics_word = 16'h0406; // pixels 4,6
		25'h0110000: graphics_word = 16'h0103; // pixels 1,3
		25'h0110002: graphics_word = 16'h0507; // pixels 5,7
		default:     graphics_word = 16'h0000;
	endcase
end
endfunction

integer graphics_reads = 0;
always_ff @(posedge clk) begin
	if (reset) begin
		gfx_ack <= 1'b0;
		gfx_dout <= 16'd0;
		graphics_reads <= 0;
	end
	else if (gfx_req != gfx_ack) begin
		gfx_dout <= graphics_word(gfx_addr);
		gfx_ack <= gfx_req;
		graphics_reads <= graphics_reads + 1;
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

task automatic check_pixel
(
	input logic [8:0] x,
	input logic [7:0] expected
);
begin
	h_count = x;
	#1;
	if (!pixel_valid || (pixel_data !== expected)) begin
		$display("FAIL: pixel %0d expected %02x got %02x valid=%0d",
			x, expected, pixel_data, pixel_valid);
		$fatal(1);
	end
end
endtask

integer timeout;
initial begin
	repeat (4) @(posedge clk);
	reset = 1'b0;

	// At line 261 the renderer prepares visible line zero.
	@(negedge clk);
	ce_pix = 1'b1;
	h_count = 9'd0;
	@(negedge clk);
	ce_pix = 1'b0;

	timeout = 0;
	while (!busy && (timeout < 20)) begin
		@(posedge clk);
		timeout = timeout + 1;
	end
	require(busy, "line renderer started");

	timeout = 0;
	while (busy && (timeout < 10000)) begin
		@(posedge clk);
		timeout = timeout + 1;
	end
	require(!busy, "line renderer completed");
	require(!underrun, "line renderer met its deadline");
	require(graphics_reads == 168,
		"42 visible tiles required exactly four ROM words each");

	v_count = 9'd0;
	check_pixel(9'd0, 8'h81);
	check_pixel(9'd1, 8'h01);
	check_pixel(9'd2, 8'h02);
	check_pixel(9'd3, 8'h03);
	check_pixel(9'd4, 8'h04);
	check_pixel(9'd5, 8'h05);
	check_pixel(9'd6, 8'h06);
	check_pixel(9'd7, 8'h07);
	check_pixel(9'd8, 8'h07);
	check_pixel(9'd15, 8'h81);

	$display("mm2_playfield_tb: PASS");
	$finish;
end

endmodule
