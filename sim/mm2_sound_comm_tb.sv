`timescale 1ns/1ps

module mm2_sound_comm_tb;

reg clk = 0;
always #5 clk = ~clk;

reg reset = 1;
reg sound_reset_n = 0;
reg main_write = 0;
reg [7:0] main_write_data = 0;
reg main_read = 0;
wire [7:0] main_read_data;
reg sound_read = 0;
wire [7:0] sound_read_data;
reg sound_write = 0;
reg [7:0] sound_write_data = 0;
wire main_to_sound_ready;
wire sound_to_main_ready;
wire sound_nmi_n;
wire main_irq6;

mm2_sound_comm dut(.*);

task require(input logic condition, input string message);
begin
	if (!condition) begin
		$display("FAIL: %s", message);
		$fatal(1);
	end
end
endtask

initial begin
	repeat (3) @(posedge clk);
	reset = 0;
	sound_reset_n = 1;

	@(negedge clk);
	main_write_data = 8'h5a;
	main_write = 1;
	@(posedge clk);
	@(negedge clk);
	main_write = 0;
	#1;
	require(main_to_sound_ready && !sound_nmi_n,
		"main command asserts ready and active-low sound NMI");
	require(sound_read_data == 8'h5a, "sound CPU sees command byte");

	sound_read = 1;
	@(posedge clk);
	@(negedge clk);
	sound_read = 0;
	#1;
	require(!main_to_sound_ready && sound_nmi_n,
		"sound read clears command and NMI");

	sound_write_data = 8'ha7;
	sound_write = 1;
	@(posedge clk);
	@(negedge clk);
	sound_write = 0;
	#1;
	require(sound_to_main_ready && main_irq6,
		"sound response asserts ready and main IRQ6");
	require(main_read_data == 8'ha7, "main CPU sees response byte");

	main_read = 1;
	@(posedge clk);
	@(negedge clk);
	main_read = 0;
	#1;
	require(!sound_to_main_ready && !main_irq6,
		"main read clears response and IRQ6");

	main_write = 1;
	@(posedge clk);
	@(negedge clk);
	main_write = 0;
	sound_reset_n = 0;
	@(posedge clk);
	#1;
	require(!main_to_sound_ready && !sound_to_main_ready,
		"sound-board reset clears both handshakes");

	$display("mm2_sound_comm_tb: PASS");
	$finish;
end

endmodule
