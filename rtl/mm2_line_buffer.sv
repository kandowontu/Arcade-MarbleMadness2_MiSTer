// Small single-clock, simple-dual-port line RAM.
//
// The explicit synthesis branch prevents Quartus 17 from expanding a
// conditionally-cleared multi-bit line buffer into logic registers.

module mm2_line_buffer
#(
	parameter int WIDTH = 9,
	parameter int ADDR_WIDTH = 9,
	parameter int WORDS = 336
)
(
	input  wire                  clk,
	input  wire                  write,
	input  wire [ADDR_WIDTH-1:0] write_address,
	input  wire      [WIDTH-1:0] write_data,
	input  wire [ADDR_WIDTH-1:0] read_address,
	output wire      [WIDTH-1:0] read_data
);

`ifdef SYNTHESIS

altsyncram ram
(
	.address_a(write_address),
	.clock0(clk),
	.data_a(write_data),
	.wren_a(write),
	.address_b(read_address),
	.clock1(clk),
	.q_b(read_data),
	.aclr0(1'b0),
	.aclr1(1'b0),
	.addressstall_a(1'b0),
	.addressstall_b(1'b0),
	.byteena_a(1'b1),
	.byteena_b(1'b1),
	.clocken0(1'b1),
	.clocken1(1'b1),
	.clocken2(1'b1),
	.clocken3(1'b1),
	.data_b({WIDTH{1'b0}}),
	.eccstatus(),
	.q_a(),
	.rden_a(1'b1),
	.rden_b(1'b1),
	.wren_b(1'b0)
);

defparam
	ram.clock_enable_input_a = "BYPASS",
	ram.clock_enable_input_b = "BYPASS",
	ram.clock_enable_output_b = "BYPASS",
	ram.intended_device_family = "Cyclone V",
	ram.lpm_type = "altsyncram",
	ram.numwords_a = WORDS,
	ram.numwords_b = WORDS,
	ram.operation_mode = "DUAL_PORT",
	ram.outdata_aclr_b = "NONE",
	ram.outdata_reg_b = "UNREGISTERED",
	ram.power_up_uninitialized = "TRUE",
	ram.ram_block_type = "M10K",
	ram.read_during_write_mode_mixed_ports = "DONT_CARE",
	ram.widthad_a = ADDR_WIDTH,
	ram.widthad_b = ADDR_WIDTH,
	ram.width_a = WIDTH,
	ram.width_b = WIDTH,
	ram.width_byteena_a = 1,
	ram.width_byteena_b = 1;

`else

logic [WIDTH-1:0] ram [0:WORDS-1];

always_ff @(posedge clk) begin
	if (write && (write_address < WORDS))
		ram[write_address] <= write_data;
end

assign read_data = (read_address < WORDS)
	? ram[read_address] : {WIDTH{1'b0}};

`endif

endmodule
