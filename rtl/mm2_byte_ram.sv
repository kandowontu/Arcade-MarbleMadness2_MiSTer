module mm2_byte_ram
#(
	parameter ADDR_WIDTH = 16
)
(
	input  logic                  clk,
	input  logic [ADDR_WIDTH-1:0] address,
	input  logic            [7:0] data,
	input  logic                  write,
	output logic            [7:0] q
);

`ifdef SYNTHESIS
altsyncram #(
	.operation_mode("SINGLE_PORT"),
	.width_a(8),
	.widthad_a(ADDR_WIDTH),
	.numwords_a(1 << ADDR_WIDTH),
	.outdata_reg_a("UNREGISTERED"),
	.intended_device_family("Cyclone V"),
	.ram_block_type("M10K")
) ram (
	.clock0(clk),
	.address_a(address),
	.data_a(data),
	.wren_a(write),
	.q_a(q)
);
`else
logic [7:0] mem [0:(1 << ADDR_WIDTH)-1];
always_ff @(posedge clk) begin
	if (write)
		mem[address] <= data;
	q <= write ? data : mem[address];
end
`endif

endmodule
