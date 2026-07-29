// Five-client arbiter for the single-port SDRAM controller.
//
// ROM downloading has priority. CPU, playfield, motion-object, and sound
// reads are round-robin so none of the runtime clients can starve the others.
//
// Copyright (C) 2026 kandowontu and contributors
// SPDX-License-Identifier: GPL-2.0-or-later

module mm2_memory_arbiter
(
	input  logic        clk,
	input  logic        reset,

	input  logic [24:0] loader_addr,
	input  logic [15:0] loader_din,
	input  logic  [1:0] loader_be,
	input  logic        loader_req,
	output logic        loader_ack,

	input  logic [24:0] cpu_addr,
	input  logic        cpu_req,
	output logic [15:0] cpu_dout,
	output logic        cpu_ack,

	input  logic [24:0] video_addr,
	input  logic        video_req,
	output logic [15:0] video_dout,
	output logic        video_ack,

	input  logic [24:0] motion_addr,
	input  logic        motion_req,
	output logic [15:0] motion_dout,
	output logic        motion_ack,

	input  logic [24:0] sound_addr,
	input  logic        sound_req,
	output logic [15:0] sound_dout,
	output logic        sound_ack,

	output logic [24:0] mem_addr,
	output logic [15:0] mem_din,
	output logic  [1:0] mem_be,
	output logic        mem_rnw,
	output logic        mem_req,
	input  logic [15:0] mem_dout,
	input  logic        mem_ack
);

typedef enum logic [2:0]
{
	ARB_IDLE,
	ARB_LOADER,
	ARB_CPU,
	ARB_VIDEO,
	ARB_MOTION,
	ARB_SOUND
} arb_state_t;

arb_state_t state;
logic mem_ack_meta;
logic mem_ack_sync;
logic [1:0] next_client;

always_ff @(posedge clk) begin
	mem_ack_meta <= mem_ack;
	mem_ack_sync <= mem_ack_meta;

	if (reset) begin
		state        <= ARB_IDLE;
		loader_ack   <= 1'b0;
		cpu_ack      <= 1'b0;
		cpu_dout     <= 16'd0;
		video_ack    <= 1'b0;
		video_dout   <= 16'd0;
		motion_ack   <= 1'b0;
		motion_dout  <= 16'd0;
		sound_ack    <= 1'b0;
		sound_dout   <= 16'd0;
		mem_addr     <= 25'd0;
		mem_din      <= 16'd0;
		mem_be       <= 2'b00;
		mem_rnw      <= 1'b1;
		mem_req      <= 1'b0;
		mem_ack_meta <= 1'b0;
		mem_ack_sync <= 1'b0;
		next_client  <= 2'd0;
	end
	else begin
		case (state)
			ARB_IDLE: begin
				if (loader_req != loader_ack) begin
					mem_addr <= loader_addr;
					mem_din  <= loader_din;
					mem_be   <= loader_be;
					mem_rnw  <= 1'b0;
					mem_req  <= ~mem_req;
					state    <= ARB_LOADER;
				end
				else begin
					case (next_client)
						2'd0: begin
							if (cpu_req != cpu_ack) begin
								mem_addr <= cpu_addr;
								state <= ARB_CPU;
							end
							else if (video_req != video_ack) begin
								mem_addr <= video_addr;
								state <= ARB_VIDEO;
							end
							else if (motion_req != motion_ack) begin
								mem_addr <= motion_addr;
								state <= ARB_MOTION;
							end
							else if (sound_req != sound_ack) begin
								mem_addr <= sound_addr;
								state <= ARB_SOUND;
							end
						end
						2'd1: begin
							if (video_req != video_ack) begin
								mem_addr <= video_addr;
								state <= ARB_VIDEO;
							end
							else if (motion_req != motion_ack) begin
								mem_addr <= motion_addr;
								state <= ARB_MOTION;
							end
							else if (cpu_req != cpu_ack) begin
								mem_addr <= cpu_addr;
								state <= ARB_CPU;
							end
							else if (sound_req != sound_ack) begin
								mem_addr <= sound_addr;
								state <= ARB_SOUND;
							end
						end
						2'd2: begin
							if (motion_req != motion_ack) begin
								mem_addr <= motion_addr;
								state <= ARB_MOTION;
							end
							else if (sound_req != sound_ack) begin
								mem_addr <= sound_addr;
								state <= ARB_SOUND;
							end
							else if (cpu_req != cpu_ack) begin
								mem_addr <= cpu_addr;
								state <= ARB_CPU;
							end
							else if (video_req != video_ack) begin
								mem_addr <= video_addr;
								state <= ARB_VIDEO;
							end
						end
						default: begin
							if (sound_req != sound_ack) begin
								mem_addr <= sound_addr;
								state <= ARB_SOUND;
							end
							else if (cpu_req != cpu_ack) begin
								mem_addr <= cpu_addr;
								state <= ARB_CPU;
							end
							else if (video_req != video_ack) begin
								mem_addr <= video_addr;
								state <= ARB_VIDEO;
							end
							else if (motion_req != motion_ack) begin
								mem_addr <= motion_addr;
								state <= ARB_MOTION;
							end
						end
					endcase

					if ((cpu_req != cpu_ack)
						|| (video_req != video_ack)
						|| (motion_req != motion_ack)
						|| (sound_req != sound_ack)) begin
						mem_din <= 16'd0;
						mem_be  <= 2'b11;
						mem_rnw <= 1'b1;
						mem_req <= ~mem_req;
					end
				end
			end

			ARB_LOADER: begin
				if (mem_ack_sync == mem_req) begin
					loader_ack <= loader_req;
					state      <= ARB_IDLE;
				end
			end

			ARB_CPU: begin
				if (mem_ack_sync == mem_req) begin
					cpu_dout <= mem_dout;
					cpu_ack  <= cpu_req;
					next_client <= 2'd1;
					state    <= ARB_IDLE;
				end
			end

			ARB_VIDEO: begin
				if (mem_ack_sync == mem_req) begin
					video_dout <= mem_dout;
					video_ack  <= video_req;
					next_client <= 2'd2;
					state      <= ARB_IDLE;
				end
			end

			ARB_MOTION: begin
				if (mem_ack_sync == mem_req) begin
					motion_dout <= mem_dout;
					motion_ack  <= motion_req;
					next_client <= 2'd3;
					state      <= ARB_IDLE;
				end
			end

			ARB_SOUND: begin
				if (mem_ack_sync == mem_req) begin
					sound_dout <= mem_dout;
					sound_ack  <= sound_req;
					next_client <= 2'd0;
					state      <= ARB_IDLE;
				end
			end

			default: state <= ARB_IDLE;
		endcase
	end
end

endmodule
