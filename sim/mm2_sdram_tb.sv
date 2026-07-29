`timescale 1ns/1ps

module mm2_sdram_tb;

logic        clk = 1'b0;
logic        reset = 1'b1;
wire [15:0]  sdram_dq;
wire [12:0]  sdram_a;
wire  [1:0]  sdram_ba;
wire         sdram_clk;
wire         sdram_cke;
wire         sdram_dqml;
wire         sdram_dqmh;
wire         sdram_ncs;
wire         sdram_nwe;
wire         sdram_ncas;
wire         sdram_nras;
logic [24:0] mem_addr = 25'd0;
logic [15:0] mem_din = 16'd0;
logic  [1:0] mem_be = 2'b11;
logic        mem_rnw = 1'b1;
logic        mem_req = 1'b0;
wire [15:0]  mem_dout;
wire         mem_ack;
wire         ready;

logic [12:0] active_row [0:3];
logic [15:0] model_memory [0:65535];
logic [15:0] read_value = 16'd0;
logic [15:0] pending_read_value = 16'd0;
integer      read_latency = 0;
integer      read_drive_count = 0;
integer      precharge_count = 0;
integer      refresh_count = 0;
integer      mode_count = 0;
integer      active_count = 0;
integer      write_count = 0;
integer      read_count = 0;
integer      word_address;
integer      init_refresh_count;
integer      i;

assign sdram_dq = (read_drive_count != 0) ? read_value : 16'hzzzz;

always #4.365 clk = ~clk;

mm2_sdram dut
(
	.clk(clk),
	.reset(reset),
	.SDRAM_DQ(sdram_dq),
	.SDRAM_A(sdram_a),
	.SDRAM_BA(sdram_ba),
	.SDRAM_CLK(sdram_clk),
	.SDRAM_CKE(sdram_cke),
	.SDRAM_DQML(sdram_dqml),
	.SDRAM_DQMH(sdram_dqmh),
	.SDRAM_nCS(sdram_ncs),
	.SDRAM_nWE(sdram_nwe),
	.SDRAM_nCAS(sdram_ncas),
	.SDRAM_nRAS(sdram_nras),
	.mem_addr(mem_addr),
	.mem_din(mem_din),
	.mem_be(mem_be),
	.mem_rnw(mem_rnw),
	.mem_req(mem_req),
	.mem_dout(mem_dout),
	.mem_ack(mem_ack),
	.ready(ready)
);

// Minimal single-bank-aware CAS-3, burst-length-1 SDRAM model. Commands are
// sampled on SDRAM_CLK's rising edge and read data is driven for exactly one
// SDRAM cycle. This catches captures that occur after the real DQ window.
always @(posedge sdram_clk) begin
	if (read_drive_count != 0)
		read_drive_count <= read_drive_count - 1;

	if (read_latency != 0) begin
		read_latency <= read_latency - 1;
		if (read_latency == 1) begin
			read_value <= pending_read_value;
			read_drive_count <= 1;
		end
	end

	case ({sdram_nras, sdram_ncas, sdram_nwe})
		3'b010: begin
			precharge_count <= precharge_count + 1;
			if (!sdram_a[10]) begin
				$display("FAIL: initialization did not precharge all banks");
				$fatal(1);
			end
		end

		3'b001: refresh_count <= refresh_count + 1;

		3'b000: begin
			mode_count <= mode_count + 1;
			if ((sdram_ba != 2'd0) || (sdram_a != 13'h230)) begin
				$display("FAIL: unexpected SDRAM mode register %h bank %0d",
					sdram_a, sdram_ba);
				$fatal(1);
			end
		end

		3'b011: begin
			active_count <= active_count + 1;
			active_row[sdram_ba] <= sdram_a;
		end

		3'b100: begin
			write_count <= write_count + 1;
			word_address = {sdram_ba, active_row[sdram_ba],
				sdram_a[8:0]};
			if (word_address > 65535) begin
				$display("FAIL: test SDRAM address escaped model memory");
				$fatal(1);
			end
			if (!sdram_dqml)
				model_memory[word_address][7:0] <= sdram_dq[7:0];
			if (!sdram_dqmh)
				model_memory[word_address][15:8] <= sdram_dq[15:8];
		end

		3'b101: begin
			read_count <= read_count + 1;
			word_address = {sdram_ba, active_row[sdram_ba],
				sdram_a[8:0]};
			if (word_address > 65535) begin
				$display("FAIL: test SDRAM address escaped model memory");
				$fatal(1);
			end
			pending_read_value <= model_memory[word_address];
			read_latency <= 3;
		end

		default: begin
		end
	endcase
end

task automatic transact
(
	input logic [24:0] address,
	input logic [15:0] data,
	input logic  [1:0] byte_enable,
	input logic        read_not_write
);
begin
	@(negedge clk);
	mem_addr = address;
	mem_din = data;
	mem_be = byte_enable;
	mem_rnw = read_not_write;
	mem_req = ~mem_req;
	while (mem_ack !== mem_req)
		@(posedge clk);
	@(negedge clk);
end
endtask

initial begin
	for (i = 0; i < 65536; i = i + 1)
		model_memory[i] = 16'h0000;

	repeat (4) @(posedge clk);
	reset = 1'b0;

	wait (ready === 1'b1);
	@(posedge clk);

	if (precharge_count != 1 || refresh_count != 2 || mode_count != 1) begin
		$display("FAIL: initialization sequence P=%0d R=%0d M=%0d",
			precharge_count, refresh_count, mode_count);
		$fatal(1);
	end

	init_refresh_count = refresh_count;

	transact(25'h001234, 16'h1234, 2'b11, 1'b0);
	transact(25'h001234, 16'h0000, 2'b11, 1'b1);
	if (mem_dout !== 16'h1234) begin
		$display("FAIL: full-word SDRAM read returned %h", mem_dout);
		$fatal(1);
	end

	transact(25'h001234, 16'habcd, 2'b10, 1'b0);
	transact(25'h001234, 16'h0000, 2'b11, 1'b1);
	if (mem_dout !== 16'hab34) begin
		$display("FAIL: high-byte SDRAM write returned %h", mem_dout);
		$fatal(1);
	end

	transact(25'h001234, 16'h55ee, 2'b01, 1'b0);
	transact(25'h001234, 16'h0000, 2'b11, 1'b1);
	if (mem_dout !== 16'habee) begin
		$display("FAIL: low-byte SDRAM write returned %h", mem_dout);
		$fatal(1);
	end

	repeat (850) @(posedge clk);
	if (refresh_count <= init_refresh_count) begin
		$display("FAIL: periodic refresh was not observed");
		$fatal(1);
	end

	if ((active_count != 6) || (write_count != 3) || (read_count != 3)) begin
		$display("FAIL: transaction commands A=%0d W=%0d R=%0d",
			active_count, write_count, read_count);
		$fatal(1);
	end

	if (!sdram_cke || sdram_ncs) begin
		$display("FAIL: SDRAM clock-enable/chip-select state is invalid");
		$fatal(1);
	end

	$display("mm2_sdram_tb: PASS");
	$finish;
end

initial begin
	#1000000;
	$display("FAIL: SDRAM test timed out");
	$fatal(1);
end

endmodule
