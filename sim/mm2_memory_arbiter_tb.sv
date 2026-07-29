`timescale 1ns/1ps

module mm2_memory_arbiter_tb;

logic clk = 1'b0;
always #5 clk = ~clk;

logic reset = 1'b1;
logic [24:0] loader_addr = 25'd0;
logic [15:0] loader_din = 16'd0;
logic [1:0] loader_be = 2'd0;
logic loader_req = 1'b0;
wire loader_ack;
logic [24:0] cpu_addr = 25'd0;
logic cpu_req = 1'b0;
wire [15:0] cpu_dout;
wire cpu_ack;
logic [24:0] video_addr = 25'd0;
logic video_req = 1'b0;
wire [15:0] video_dout;
wire video_ack;
logic [24:0] motion_addr = 25'd0;
logic motion_req = 1'b0;
wire [15:0] motion_dout;
wire motion_ack;
logic [24:0] sound_addr = 25'd0;
logic sound_req = 1'b0;
wire [15:0] sound_dout;
wire sound_ack;
wire [24:0] mem_addr;
wire [15:0] mem_din;
wire [1:0] mem_be;
wire mem_rnw;
wire mem_req;
logic [15:0] mem_dout = 16'd0;
logic mem_ack = 1'b0;

mm2_memory_arbiter dut
(
	.clk,
	.reset,
	.loader_addr,
	.loader_din,
	.loader_be,
	.loader_req,
	.loader_ack,
	.cpu_addr,
	.cpu_req,
	.cpu_dout,
	.cpu_ack,
	.video_addr,
	.video_req,
	.video_dout,
	.video_ack,
	.motion_addr,
	.motion_req,
	.motion_dout,
	.motion_ack,
	.sound_addr,
	.sound_req,
	.sound_dout,
	.sound_ack,
	.mem_addr,
	.mem_din,
	.mem_be,
	.mem_rnw,
	.mem_req,
	.mem_dout,
	.mem_ack
);

integer response_delay = 0;
logic observed_req = 1'b0;
logic first_rnw = 1'b1;
logic [24:0] first_addr = 25'd0;
integer transaction_count = 0;

always_ff @(posedge clk) begin
	if (mem_req != observed_req) begin
		observed_req <= mem_req;
		response_delay <= 3;
		transaction_count <= transaction_count + 1;
		if (transaction_count == 0) begin
			first_rnw  <= mem_rnw;
			first_addr <= mem_addr;
		end
	end
	else if (response_delay != 0) begin
		response_delay <= response_delay - 1;
		if (response_delay == 1) begin
			mem_dout <= 16'ha55a;
			mem_ack  <= observed_req;
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
	repeat (4) @(posedge clk);
	reset <= 1'b0;
	@(posedge clk);

	loader_addr <= 25'h0012344;
	loader_din  <= 16'hbeef;
	loader_be   <= 2'b10;
	loader_req  <= ~loader_req;
	cpu_addr    <= 25'h0000040;
	cpu_req     <= ~cpu_req;
	@(posedge clk);
	#1;

	while (loader_ack != loader_req)
		@(posedge clk);
	#1;
	require(!first_rnw, "loader is a write");
	require(first_addr == 25'h0012344, "loader address is preserved");

	while (cpu_ack != cpu_req)
		@(posedge clk);
	#1;
	require(mem_rnw, "CPU request is a read");
	require(cpu_dout == 16'ha55a, "CPU receives SDRAM data");

	@(posedge clk);
	video_addr <= 25'h0090122;
	video_req  <= ~video_req;
	@(posedge clk);
	while (video_ack != video_req)
		@(posedge clk);
	#1;
	require(mem_rnw, "playfield request is a read");
	require(video_dout == 16'ha55a, "playfield receives SDRAM data");

	@(posedge clk);
	cpu_addr    <= 25'h0000080;
	cpu_req     <= ~cpu_req;
	video_addr  <= 25'h0090200;
	video_req   <= ~video_req;
	motion_addr <= 25'h0190040;
	motion_req  <= ~motion_req;
	sound_addr  <= 25'h0210080;
	sound_req   <= ~sound_req;
	@(posedge clk);
	while ((cpu_ack != cpu_req)
		|| (video_ack != video_req)
		|| (motion_ack != motion_req)
		|| (sound_ack != sound_req))
		@(posedge clk);
	#1;
	require(motion_dout == 16'ha55a,
		"motion renderer receives SDRAM data");
	require(sound_dout == 16'ha55a,
		"sound board receives SDRAM data");
	require(transaction_count == 7,
		"all four simultaneous runtime requests complete");

	$display("mm2_memory_arbiter_tb: PASS");
	$finish;
end

endmodule
