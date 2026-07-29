`timescale 1ns/1ps

module mm2_rom_loader_tb;

logic clk = 1'b0;
always #5 clk = ~clk;

logic reset = 1'b1;
logic downloading = 1'b0;
logic ioctl_wr = 1'b0;
logic [24:0] ioctl_addr = 25'd0;
logic [7:0] ioctl_data = 8'd0;
wire ioctl_wait;
wire [24:0] mem_addr;
wire [15:0] mem_din;
wire [1:0] mem_be;
wire mem_req;
logic mem_ack = 1'b0;
wire rom_ready;
wire [7:0] rom_signature;
wire layout_error;

mm2_rom_loader dut
(
	.clk,
	.reset,
	.downloading,
	.ioctl_wr,
	.ioctl_addr,
	.ioctl_data,
	.ioctl_wait,
	.mem_addr,
	.mem_din,
	.mem_be,
	.mem_req,
	.mem_ack,
	.rom_ready,
	.rom_signature,
	.layout_error
);

logic [24:0] captured_addr;
logic [15:0] captured_data;
logic [1:0] captured_be;
integer write_count = 0;

always_ff @(posedge clk) begin
	if (mem_req != mem_ack) begin
		captured_addr <= mem_addr;
		captured_data <= mem_din;
		captured_be   <= mem_be;
		write_count   <= write_count + 1;
		mem_ack       <= mem_req;
	end
end

task automatic send_byte(
	input logic [24:0] address,
	input logic [7:0] data
);
begin
	while (ioctl_wait)
		@(posedge clk);
	ioctl_addr <= address;
	ioctl_data <= data;
	ioctl_wr   <= 1'b1;
	@(posedge clk);
	ioctl_wr   <= 1'b0;
	while (ioctl_wait)
		@(posedge clk);
	@(posedge clk);
	#1;
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
	reset <= 1'b0;
	@(posedge clk);
	downloading <= 1'b1;
	@(posedge clk);

	send_byte(25'h0000000, 8'h12);
	require(write_count == 0, "even byte is buffered until its pair arrives");

	send_byte(25'h0000001, 8'h34);
	require(captured_addr == 25'h0000000, "paired word uses even byte address");
	require(captured_data == 16'h1234, "paired bytes preserve 68000 order");
	require(captured_be == 2'b11, "ROM download uses both SDRAM lanes");

	// Touch every logical region, then commit the defined final byte.
	send_byte(25'h0080000, 8'h56);
	send_byte(25'h0080001, 8'h57);
	send_byte(25'h0090000, 8'h78);
	send_byte(25'h0090001, 8'h79);
	send_byte(25'h0190000, 8'h9a);
	send_byte(25'h0190001, 8'h9b);
	send_byte(25'h0210000, 8'hbc);
	send_byte(25'h0210001, 8'hbd);
	send_byte(25'h024fffe, 8'hdd);
	send_byte(25'h024ffff, 8'hde);

	downloading <= 1'b0;
	repeat (4) @(posedge clk);
	require(rom_ready, "complete region set marks ROM ready after final ack");
	require(!layout_error, "valid stream addresses do not set layout error");
	require(write_count == 6, "all paired writes reached memory");

	// A real HPS transfer may remove ioctl_download on the clock adjacent to
	// its final byte. Verify that the falling edge also commits a valid stream
	// without depending on a write at the exact maximum layout address.
	reset <= 1'b1;
	repeat (2) @(posedge clk);
	reset <= 1'b0;
	@(posedge clk);
	downloading <= 1'b1;
	@(posedge clk);

	send_byte(25'h0000000, 8'h11);
	send_byte(25'h0000001, 8'h12);
	send_byte(25'h0080000, 8'h22);
	send_byte(25'h0080001, 8'h23);
	send_byte(25'h0090000, 8'h33);
	send_byte(25'h0090001, 8'h34);
	send_byte(25'h0190000, 8'h44);
	send_byte(25'h0190001, 8'h45);
	send_byte(25'h0210000, 8'h55);
	// MiSTer may drop ioctl_download on the same edge as the final strobe.
	while (ioctl_wait)
		@(posedge clk);
	ioctl_addr <= 25'h0210001;
	ioctl_data <= 8'h56;
	ioctl_wr   <= 1'b1;
	downloading <= 1'b0;
	@(posedge clk);
	ioctl_wr <= 1'b0;
	while (ioctl_wait)
		@(posedge clk);
	repeat (4) @(posedge clk);
	require(rom_ready, "download falling edge commits a complete region set");
	require(!layout_error, "falling-edge commit preserves valid layout");

	$display("mm2_rom_loader_tb: PASS");
	$finish;
end

endmodule
