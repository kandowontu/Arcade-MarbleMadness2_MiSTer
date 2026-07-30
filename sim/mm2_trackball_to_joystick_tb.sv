`timescale 1ns/1ps

module mm2_trackball_to_joystick_tb;

logic clk = 1'b0;
logic reset;
logic enable;
logic frame_tick;
logic [1:0] sensitivity;
logic [24:0] ps2_mouse;
logic [15:0] joystick_in;
wire [15:0] joystick_out;

always #5 clk = ~clk;

mm2_trackball_to_joystick dut
(
	.clk,
	.reset,
	.enable,
	.frame_tick,
	.sensitivity,
	.ps2_mouse,
	.joystick_in,
	.joystick_out
);

task automatic require(input logic condition, input string message);
	if (!condition) begin
		$display("FAIL: %s", message);
		$fatal(1);
	end
endtask

task automatic send_packet
(
	input signed [7:0] dx,
	input signed [7:0] dy,
	input logic [2:0] buttons
);
	begin
		@(negedge clk);
		ps2_mouse = {
			~ps2_mouse[24],
			dy[7:0],
			dx[7:0],
			5'd0,
			buttons
		};
		@(posedge clk);
		@(posedge clk);
	end
endtask

task automatic next_frame;
	begin
		@(negedge clk);
		frame_tick = 1'b1;
		@(posedge clk);
		@(negedge clk);
		frame_tick = 1'b0;
		@(posedge clk);
	end
endtask

initial begin
	reset = 1'b1;
	enable = 1'b0;
	frame_tick = 1'b0;
	sensitivity = 2'd0;
	ps2_mouse = 25'd0;
	joystick_in = 16'd0;
	joystick_in[10] = 1'b1;
	repeat (2) @(posedge clk);
	@(negedge clk);
	reset = 1'b0;
	@(posedge clk);

	send_packet(8'sd16, 8'sd8, 3'b001);
	require(joystick_out[10], "ordinary Start input is preserved");
	require(!joystick_out[0] && !joystick_out[3],
		"disabled trackball does not drive directions");
	require(!joystick_out[4], "disabled trackball does not map mouse buttons");

	enable = 1'b1;
	send_packet(8'sd16, 8'sd8, 3'b001);
	require(joystick_out[0] && !joystick_out[1],
		"positive X drives right only");
	require(joystick_out[3] && !joystick_out[2],
		"positive Y drives up only");
	require(joystick_out[4], "left mouse button drives Action/Start");

	next_frame();
	require(joystick_out[0], "X motion persists for a second game frame");
	require(!joystick_out[3], "eight-count Y motion expires after one frame");
	next_frame();
	require(!joystick_out[0] && !joystick_out[1],
		"X motion budget drains without a stuck direction");

	send_packet(-8'sd12, -8'sd12, 3'b010);
	require(joystick_out[1] && joystick_out[2],
		"negative X and negative Y map to left and down");
	require(joystick_out[11], "right mouse button drives Coin");

	@(negedge clk);
	reset = 1'b1;
	repeat (2) @(posedge clk);
	@(negedge clk);
	reset = 1'b0;
	enable = 1'b1;
	sensitivity = 2'd1;
	send_packet(8'sd8, 8'sd0, 3'b000);
	require(joystick_out[0], "50-percent sensitivity retains small motion");
	next_frame();
	require(!joystick_out[0], "scaled motion drains on schedule");

	$display("mm2_trackball_to_joystick_tb: PASS");
	$finish;
end

endmodule
