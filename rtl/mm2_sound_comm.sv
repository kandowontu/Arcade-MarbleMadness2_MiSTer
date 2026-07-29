// Atari dual-CPU sound command/response latches.
//
// A main-CPU command asserts the 6502 NMI until the sound CPU consumes it.
// A sound-CPU response asserts main IRQ6 until the 68000 reads the byte.

module mm2_sound_comm
(
	input  logic       clk,
	input  logic       reset,
	input  logic       sound_reset_n,

	input  logic       main_write,
	input  logic [7:0] main_write_data,
	input  logic       main_read,
	output logic [7:0] main_read_data,

	input  logic       sound_read,
	output logic [7:0] sound_read_data,
	input  logic       sound_write,
	input  logic [7:0] sound_write_data,

	output logic       main_to_sound_ready,
	output logic       sound_to_main_ready,
	output logic       sound_nmi_n,
	output logic       main_irq6
);

logic [7:0] main_to_sound_data;
logic [7:0] sound_to_main_data;

assign main_read_data = sound_to_main_data;
assign sound_read_data = main_to_sound_data;
assign sound_nmi_n = ~main_to_sound_ready;
assign main_irq6 = sound_to_main_ready;

always_ff @(posedge clk) begin
	if (reset || !sound_reset_n) begin
		main_to_sound_data  <= 8'd0;
		sound_to_main_data  <= 8'd0;
		main_to_sound_ready <= 1'b0;
		sound_to_main_ready <= 1'b0;
	end
	else begin
		if (sound_read)
			main_to_sound_ready <= 1'b0;
		if (main_write) begin
			main_to_sound_data  <= main_write_data;
			main_to_sound_ready <= 1'b1;
		end

		if (main_read)
			sound_to_main_ready <= 1'b0;
		if (sound_write) begin
			sound_to_main_data  <= sound_write_data;
			sound_to_main_ready <= 1'b1;
		end
	end
end

endmodule
