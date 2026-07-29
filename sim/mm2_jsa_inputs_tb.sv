`timescale 1ns/1ps

module mm2_jsa_inputs_tb;

logic service;
logic coin1;
logic coin2;
logic command_ready;
logic response_ready;
logic [7:0] data;

mm2_jsa_inputs dut(.*);

task automatic require(input logic condition, input string message);
begin
	if (!condition) begin
		$display("FAIL: %s (data=%02x)", message, data);
		$fatal(1);
	end
end
endtask

initial begin
	service = 1'b0;
	coin1 = 1'b0;
	coin2 = 1'b0;
	command_ready = 1'b0;
	response_ready = 1'b0;
	#1;
	require(data == 8'h40, "idle JSA III port");

	coin1 = 1'b1;
	#1;
	require(data == 8'h41, "coin 1 must drive swapped-coin bit 0");

	coin1 = 1'b0;
	coin2 = 1'b1;
	#1;
	require(data == 8'h42, "coin 2 must drive swapped-coin bit 1");

	coin2 = 1'b0;
	service = 1'b1;
	#1;
	require(data == 8'hd8, "service must assert JSA bits 7, 4, and 3");

	service = 1'b0;
	command_ready = 1'b1;
	response_ready = 1'b1;
	#1;
	require(data == 8'h20, "sound handshake polarity");

	$display("mm2_jsa_inputs_tb: PASS");
	$finish;
end

endmodule
