`timescale 1ns/1ps

module mm2_motion_objects_tb;

logic clk = 1'b0;
always #5 clk = ~clk;

logic reset = 1'b1;
logic enable = 1'b1;
logic ce_pix = 1'b0;
logic [8:0] h_count = 9'd0;
logic [8:0] v_count = 9'd261;
logic [8:0] xscroll = 9'd0;
logic [8:0] yscroll = 9'd0;
wire [11:0] ram_address;
logic [15:0] ram_data = 16'd0;
wire [24:0] gfx_addr;
wire gfx_req;
logic [15:0] gfx_dout = 16'd0;
logic gfx_ack = 1'b0;
wire [7:0] pixel_data;
wire pixel_opaque;
wire pixel_valid;
wire busy;
wire underrun;

mm2_motion_objects dut
(
	.clk,
	.reset,
	.enable,
	.ce_pix,
	.h_count,
	.v_count,
	.xscroll,
	.yscroll,
	.ram_address,
	.ram_data,
	.gfx_addr,
	.gfx_req,
	.gfx_dout,
	.gfx_ack,
	.pixel_data,
	.pixel_opaque,
	.pixel_valid,
	.busy,
	.underrun
);

function automatic [15:0] motion_word(input logic [11:0] address);
begin
	case (address)
		// Entry 0: normal tile, color 2, x=0, y=0, link 1.
		12'h000: motion_word = 16'h0001;
		12'h001: motion_word = 16'h0000;
		12'h002: motion_word = 16'h0002;
		12'h003: motion_word = 16'hfc00;

		// Entry 1: flipped tile, color 9, x=4, y=0, self link.
		// It overlaps entry 0 and must win because it is later in the list.
		12'h004: motion_word = 16'h0001;
		12'h005: motion_word = 16'h8000;
		12'h006: motion_word = 16'h0209;
		12'h007: motion_word = 16'hfc00;

		12'hfc0: motion_word = 16'h0000;
		default: motion_word = 16'h0000;
	endcase
end
endfunction

// Match the registered-address video port of the motion shadow M10K.
always_ff @(posedge clk)
	ram_data <= motion_word(ram_address);

function automatic [15:0] graphics_word(input logic [24:0] address);
begin
	case (address)
		25'h0190000: graphics_word = 16'h3478;
		25'h01d0000: graphics_word = 16'h1256;
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
	if (!pixel_valid || !pixel_opaque || (pixel_data !== expected)) begin
		$display("FAIL: pixel %0d expected %02x got %02x opaque=%0d valid=%0d",
			x, expected, pixel_data, pixel_opaque, pixel_valid);
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
	require(busy, "motion-object renderer started");

	timeout = 0;
	while (busy && (timeout < 5000)) begin
		@(posedge clk);
		timeout = timeout + 1;
	end
	require(!busy, "motion-object renderer completed");
	require(!underrun, "motion-object renderer met its deadline");
	require(graphics_reads == 4,
		"two visible objects required two ROM words each");

	v_count = 9'd0;
	check_pixel(9'd0, 8'h21);
	check_pixel(9'd3, 8'h24);
	check_pixel(9'd4, 8'h98);
	check_pixel(9'd7, 8'h95);
	check_pixel(9'd11, 8'h91);

	h_count = 9'd12;
	#1;
	require(pixel_valid && !pixel_opaque,
		"cleared line-buffer pixels remain transparent");

	$display("mm2_motion_objects_tb: PASS");
	$finish;
end

endmodule
