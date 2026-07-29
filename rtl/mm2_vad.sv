// Atari VAD control-register subset used by Marble Madness II.
//
// This implements the scanline register/IRQ behavior, indexed playfield
// scroll parameters, and the end-of-frame register shadow described by MAME's
// atarivad device. The alpha-row and motion-object parameters are retained in
// the control array but are consumed by later phases.
//
// Copyright (C) 2026 kandowontu and contributors
// SPDX-License-Identifier: GPL-2.0-or-later

module mm2_vad
(
	input  logic        clk,
	input  logic        reset,
	input  logic        ce_pix,
	input  logic [8:0]  h_count,
	input  logic [8:0]  v_count,

	input  logic        cpu_write,
	input  logic [4:0]  cpu_address,
	input  logic [15:0] cpu_data,
	input  logic [1:0]  cpu_byte_enable,
	output logic [15:0] cpu_q,

	input  logic        eof_write,
	input  logic [5:0]  eof_address,
	input  logic [15:0] eof_data,
	input  logic [1:0]  eof_byte_enable,

	output logic [8:0]  playfield_xscroll,
	output logic [8:0]  playfield_yscroll,
	output logic [8:0]  motion_xscroll,
	output logic [8:0]  motion_yscroll,
	output logic        irq4
);

logic [15:0] control [0:31];
logic [15:0] eof_ram [0:27];
logic  [8:0] pf0_xscroll_raw;
logic  [8:0] pf1_xscroll_raw;
logic  [8:0] pf0_yscroll;
logic  [8:0] mo_xscroll;
logic  [8:0] mo_yscroll;

integer index;

function automatic [15:0] combine_word
(
	input logic [15:0] oldword,
	input logic [15:0] newword,
	input logic  [1:0] byte_enable
);
begin
	combine_word = oldword;
	if (byte_enable[1])
		combine_word[15:8] = newword[15:8];
	if (byte_enable[0])
		combine_word[7:0] = newword[7:0];
end
endfunction

task automatic apply_parameter(input logic [15:0] parameter_word);
begin
	case (parameter_word[3:0])
		4'h9: mo_xscroll       <= parameter_word[15:7];
		4'hA: pf1_xscroll_raw <= parameter_word[15:7];
		4'hB: pf0_xscroll_raw <= parameter_word[15:7];
		4'hD: mo_yscroll       <= parameter_word[15:7];
		4'hF: pf0_yscroll     <= parameter_word[15:7];
		default: begin
		end
	endcase
end
endtask

logic [15:0] cpu_newword;
logic [15:0] eof_newword;

always_comb begin
	cpu_newword = combine_word(
		control[cpu_address], cpu_data, cpu_byte_enable);
	eof_newword = 16'd0;
	if (eof_address < 6'd28)
		eof_newword = combine_word(
			eof_ram[eof_address], eof_data, eof_byte_enable);

	if (cpu_address == 5'd0) begin
		cpu_q = {7'd0, v_count};
		if (v_count > 9'd255)
			cpu_q[8:0] = 9'd255;
		if (v_count > 9'd239)
			cpu_q[14] = 1'b1;
	end
	else begin
		cpu_q = control[cpu_address];
	end

	// The primary playfield uses PF0 plus the low three PF1 bits and the
	// four-pixel board offset configured by the Marble Madness II driver.
	playfield_xscroll = pf0_xscroll_raw
	                  + {6'd0, pf1_xscroll_raw[2:0]}
	                  + 9'd4;
	playfield_yscroll = pf0_yscroll;
	motion_xscroll    = mo_xscroll;
	motion_yscroll    = mo_yscroll;
end

always_ff @(posedge clk) begin
	if (reset) begin
		irq4                <= 1'b0;
		pf0_xscroll_raw     <= 9'd0;
		pf1_xscroll_raw     <= 9'd0;
		pf0_yscroll         <= 9'd0;
		mo_xscroll          <= 9'd0;
		mo_yscroll          <= 9'd0;
		for (index = 0; index < 32; index = index + 1)
			control[index] <= 16'd0;
		for (index = 0; index < 28; index = index + 1)
			eof_ram[index] <= 16'd0;
	end
	else begin
		// A VAD scanline interrupt remains asserted until register 0x1e is
		// written; an interrupt-acknowledge cycle alone does not clear it.
		if (ce_pix && (h_count == 9'd0)
			&& (v_count == control[3][8:0]))
			irq4 <= 1'b1;

		if (eof_write && (eof_address < 6'd28)) begin
			eof_ram[eof_address] <= eof_newword;
		end

		if (cpu_write) begin
			control[cpu_address] <= cpu_newword;
			if ((cpu_address >= 5'h10)
				&& (cpu_address <= 5'h1b))
				apply_parameter(cpu_newword);
			if (cpu_address == 5'h1e)
				irq4 <= 1'b0;
		end

		// At the beginning of every frame the VAD copies each non-zero EOF
		// word into the corresponding control register in ascending order.
		if (ce_pix && (h_count == 9'd0) && (v_count == 9'd0)) begin
			for (index = 0; index < 28; index = index + 1) begin
				if (eof_ram[index] != 16'd0) begin
					control[index] <= eof_ram[index];
					if ((index >= 16) && (index <= 27))
						apply_parameter(eof_ram[index]);
				end
			end
		end
	end
end

endmodule
