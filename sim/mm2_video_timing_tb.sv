`timescale 1ns/1ps

module mm2_video_timing_tb;

logic clk = 1'b0;
logic reset = 1'b1;
logic [3:0] h_adjust = 4'd0;
logic [3:0] v_adjust = 4'd0;
wire ce_pix;
wire [8:0] h_count;
wire [8:0] v_count;
wire hblank;
wire hsync;
wire vblank;
wire vsync;

always #5 clk = ~clk;

mm2_video_timing dut
(
	.*
);

task check_sync_at(
	input logic [8:0] h,
	input logic [8:0] v,
	input logic expected_hsync,
	input logic expected_vsync,
	input string message
);
	begin
		force dut.h_count = h;
		force dut.v_count = v;
		#1;
		if ((hsync !== expected_hsync) || (vsync !== expected_vsync)) begin
			$display("FAIL: %s h=%0d v=%0d hs=%b vs=%b", message,
			         h, v, hsync, vsync);
			$fatal(1);
		end
		release dut.h_count;
		release dut.v_count;
	end
endtask

initial begin
	repeat (2) @(posedge clk);
	reset = 1'b0;

	check_sync_at(9'd359, 9'd243, 1'b0, 1'b0, "zero before sync");
	check_sync_at(9'd360, 9'd244, 1'b1, 1'b1, "zero sync start");
	check_sync_at(9'd407, 9'd246, 1'b1, 1'b1, "zero sync end minus one");
	check_sync_at(9'd408, 9'd247, 1'b0, 1'b0, "zero sync end");

	h_adjust = 4'd7;
	v_adjust = 4'd7;
	check_sync_at(9'd366, 9'd250, 1'b0, 1'b0, "+7 before sync");
	check_sync_at(9'd367, 9'd251, 1'b1, 1'b1, "+7 sync start");
	check_sync_at(9'd414, 9'd253, 1'b1, 1'b1, "+7 sync end minus one");
	check_sync_at(9'd415, 9'd254, 1'b0, 1'b0, "+7 sync end");

	h_adjust = 4'h8;
	v_adjust = 4'h8;
	check_sync_at(9'd351, 9'd235, 1'b0, 1'b0, "-8 before sync");
	check_sync_at(9'd352, 9'd236, 1'b1, 1'b1, "-8 sync start");
	check_sync_at(9'd399, 9'd238, 1'b1, 1'b1, "-8 sync end minus one");
	check_sync_at(9'd400, 9'd239, 1'b0, 1'b0, "-8 sync end");

	h_adjust = 4'hf;
	v_adjust = 4'hf;
	check_sync_at(9'd359, 9'd243, 1'b1, 1'b1, "-1 sync start");
	check_sync_at(9'd407, 9'd246, 1'b0, 1'b0, "-1 sync end");

	$display("mm2_video_timing_tb: PASS");
	$finish;
end

endmodule
