// Byte-enabled 16-bit RAM for a 68000 bus.
//
// Explicit altsyncram use prevents Quartus 17 from expanding large mixed-byte
// arrays into logic. The simulation branch remains vendor-independent.
//
// Copyright (C) 2026 kandowontu and contributors
// SPDX-License-Identifier: GPL-2.0-or-later

module mm2_m68k_ram
#(
	parameter int ADDR_WIDTH = 10
)
(
	input  wire                  clk,
	input  wire [ADDR_WIDTH-1:0] address,
	input  wire           [15:0] data,
	input  wire            [1:0] byte_enable,
	input  wire                  write,
	output wire           [15:0] q,

	input  wire [ADDR_WIDTH-1:0] video_address,
	output wire           [15:0] video_q
);

`ifdef SYNTHESIS

altsyncram ram
(
	.address_a(address),
	.clock0(clk),
	.data_a(data),
	.wren_a(write),
	.byteena_a(byte_enable),
	.q_a(q),
	.aclr0(1'b0),
	.aclr1(1'b0),
	.address_b(video_address),
	.addressstall_a(1'b0),
	.addressstall_b(1'b0),
	.byteena_b(1'b1),
	.clock1(clk),
	.clocken0(1'b1),
	.clocken1(1'b1),
	.clocken2(1'b1),
	.clocken3(1'b1),
	.data_b(16'd0),
	.eccstatus(),
	.q_b(video_q),
	.rden_a(1'b1),
	.rden_b(1'b1),
	.wren_b(1'b0)
);

defparam
	ram.clock_enable_input_a = "BYPASS",
	ram.clock_enable_input_b = "BYPASS",
	ram.clock_enable_output_a = "BYPASS",
	ram.clock_enable_output_b = "BYPASS",
	ram.intended_device_family = "Cyclone V",
	ram.lpm_type = "altsyncram",
	ram.numwords_a = 2**ADDR_WIDTH,
	ram.numwords_b = 2**ADDR_WIDTH,
	ram.operation_mode = "BIDIR_DUAL_PORT",
	ram.outdata_aclr_a = "NONE",
	ram.outdata_aclr_b = "NONE",
	ram.outdata_reg_a = "UNREGISTERED",
	ram.outdata_reg_b = "UNREGISTERED",
	ram.power_up_uninitialized = "FALSE",
	ram.ram_block_type = "M10K",
	ram.read_during_write_mode_port_a = "DONT_CARE",
	ram.read_during_write_mode_mixed_ports = "DONT_CARE",
	ram.widthad_a = ADDR_WIDTH,
	ram.widthad_b = ADDR_WIDTH,
	ram.width_a = 16,
	ram.width_b = 16,
	ram.width_byteena_a = 2,
	ram.width_byteena_b = 1;

`else

logic [7:0] ram_low  [0:(2**ADDR_WIDTH)-1];
logic [7:0] ram_high [0:(2**ADDR_WIDTH)-1];
integer simulation_index;

initial begin
	for (simulation_index = 0;
		simulation_index < (2**ADDR_WIDTH);
		simulation_index = simulation_index + 1) begin
		ram_low[simulation_index] = 8'd0;
		ram_high[simulation_index] = 8'd0;
	end
end

always_ff @(posedge clk) begin
	if (write && byte_enable[0])
		ram_low[address] <= data[7:0];
	if (write && byte_enable[1])
		ram_high[address] <= data[15:8];
end

assign q = {ram_high[address], ram_low[address]};
assign video_q = {
	ram_high[video_address], ram_low[video_address]};

`endif

endmodule
