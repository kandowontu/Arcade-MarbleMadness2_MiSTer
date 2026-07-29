`timescale 1ns/1ps

module mm2_rom_layout_tb;

logic [24:0] stream_addr;
logic valid;
logic [2:0] region;
logic [19:0] region_addr;
logic last_byte;

mm2_rom_layout dut(.*);

task automatic check(
	input logic [24:0] test_address,
	input logic expected_valid,
	input logic [2:0] expected_region,
	input logic [19:0] expected_region_address,
	input logic expected_last
);
	begin
		stream_addr = test_address;
		#1;
		if ((valid !== expected_valid)
		    || (region !== expected_region)
		    || (region_addr !== expected_region_address)
		    || (last_byte !== expected_last)) begin
			$display("stream=%07x valid=%b region=%0d region_addr=%05x last=%b",
			         stream_addr, valid, region, region_addr, last_byte);
			$fatal(1, "ROM layout mismatch");
		end
	end
endtask

initial begin
	check(25'h0000000, 1, 0, 20'h00000, 0);
	check(25'h007ffff, 1, 0, 20'h7ffff, 0);
	check(25'h0080000, 1, 1, 20'h00000, 0);
	check(25'h008ffff, 1, 1, 20'h0ffff, 0);
	check(25'h0090000, 1, 2, 20'h00000, 0);
	check(25'h018ffff, 1, 2, 20'hfffff, 0);
	check(25'h0190000, 1, 3, 20'h00000, 0);
	check(25'h020ffff, 1, 3, 20'h7ffff, 0);
	check(25'h0210000, 1, 4, 20'h00000, 0);
	check(25'h022ffff, 1, 4, 20'h1ffff, 0);
	check(25'h0230000, 1, 4, 20'h60000, 0);
	check(25'h024ffff, 1, 4, 20'h7ffff, 1);
	check(25'h0250000, 0, 0, 20'h00000, 0);

	$display("mm2_rom_layout_tb: PASS");
	$finish;
end

endmodule
