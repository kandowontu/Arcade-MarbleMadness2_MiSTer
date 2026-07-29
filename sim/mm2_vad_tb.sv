`timescale 1ns/1ps

module mm2_vad_tb;

logic clk = 1'b0;
always #5 clk = ~clk;

logic reset = 1'b1;
logic ce_pix = 1'b0;
logic [8:0] h_count = 9'd0;
logic [8:0] v_count = 9'd0;
logic cpu_write = 1'b0;
logic [4:0] cpu_address = 5'd0;
logic [15:0] cpu_data = 16'd0;
logic [1:0] cpu_byte_enable = 2'b11;
wire [15:0] cpu_q;
logic eof_write = 1'b0;
logic [5:0] eof_address = 6'd0;
logic [15:0] eof_data = 16'd0;
logic [1:0] eof_byte_enable = 2'b11;
wire [8:0] playfield_xscroll;
wire [8:0] playfield_yscroll;
wire [8:0] motion_xscroll;
wire [8:0] motion_yscroll;
wire irq4;

mm2_vad dut
(
	.clk,
	.reset,
	.ce_pix,
	.h_count,
	.v_count,
	.cpu_write,
	.cpu_address,
	.cpu_data,
	.cpu_byte_enable,
	.cpu_q,
	.eof_write,
	.eof_address,
	.eof_data,
	.eof_byte_enable,
	.playfield_xscroll,
	.playfield_yscroll,
	.motion_xscroll,
	.motion_yscroll,
	.irq4
);

task automatic write_control
(
	input logic [4:0] address,
	input logic [15:0] data
);
begin
	@(negedge clk);
	cpu_address = address;
	cpu_data = data;
	cpu_write = 1'b1;
	@(negedge clk);
	cpu_write = 1'b0;
end
endtask

task automatic write_eof
(
	input logic [5:0] address,
	input logic [15:0] data
);
begin
	@(negedge clk);
	eof_address = address;
	eof_data = data;
	eof_write = 1'b1;
	@(negedge clk);
	eof_write = 1'b0;
end
endtask

task automatic require(input logic condition, input string message);
begin
	if (!condition) begin
		$display("FAIL: %s", message);
		$fatal(1);
	end
end
endtask

initial begin
	repeat (4) @(posedge clk);
	reset = 1'b0;

	write_control(5'h1a, 16'h018a); // PF1 x = 3, selector A
	write_control(5'h1b, 16'h028b); // PF0 x = 5, selector B
	write_control(5'h18, 16'h038f); // PF0 y = 7, selector F
	write_control(5'h17, 16'h0609); // MO x = 12, selector 9
	write_control(5'h16, 16'h088d); // MO y = 17, selector D
	#1;
	require(playfield_xscroll == 9'd12,
		"PF xscroll includes PF0, PF1 low bits, and +4 offset");
	require(playfield_yscroll == 9'd7,
		"PF yscroll follows selector F");
	require((motion_xscroll == 9'd12) && (motion_yscroll == 9'd17),
		"motion-object scroll selectors 9 and D are decoded");

	v_count = 9'd250;
	cpu_address = 5'd0;
	#1;
	require(cpu_q == 16'h40fa,
		"control offset zero reports capped scanline and vblank flag");

	write_control(5'h03, 16'h0005);
	@(negedge clk);
	v_count = 9'd5;
	h_count = 9'd0;
	ce_pix = 1'b1;
	@(negedge clk);
	ce_pix = 1'b0;
	#1;
	require(irq4, "scanline target asserts IRQ4");

	write_control(5'h1e, 16'h0000);
	#1;
	require(!irq4, "register 1e clears IRQ4");

	// EOF word 1a changes PF0 x to 9 at the next frame boundary.
	write_eof(6'h1a, 16'h048b);
	@(negedge clk);
	v_count = 9'd0;
	h_count = 9'd0;
	ce_pix = 1'b1;
	@(negedge clk);
	ce_pix = 1'b0;
	#1;
	require(playfield_xscroll == 9'd16,
		"non-zero EOF parameter is applied at scanline zero");

	$display("mm2_vad_tb: PASS");
	$finish;
end

endmodule
