// Atari JSA III general input port.
//
// Marble Madness II selects the swapped-coin variant, so bit 0 is coin 1
// and bit 1 is coin 2. The custom self-test inputs on bits 4 and 7 follow
// the main-board active-low service switch and are therefore active high here.

module mm2_jsa_inputs
(
	input  logic       service,
	input  logic       coin1,
	input  logic       coin2,
	input  logic       command_ready,
	input  logic       response_ready,
	output logic [7:0] data
);

always_comb begin
	data = {
		service,
		~command_ready,
		response_ready,
		service,
		service,
		1'b0,
		coin2,
		coin1
	};
end

endmodule
