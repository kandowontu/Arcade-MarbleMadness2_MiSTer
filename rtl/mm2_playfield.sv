// Atari VAD primary playfield line renderer.
//
// The tilemap is 64x64, column scanned, with 8x8 tiles. Each tile row is
// decoded from four SDRAM words using the split-half eight-bit MAME layout,
// then written into the line buffer for the following scanline.
//
// Copyright (C) 2026 kandowontu and contributors
// SPDX-License-Identifier: GPL-2.0-or-later

module mm2_playfield
(
	input  logic        clk,
	input  logic        reset,
	input  logic        enable,
	input  logic        ce_pix,
	input  logic [8:0]  h_count,
	input  logic [8:0]  v_count,
	input  logic [8:0]  xscroll,
	input  logic [8:0]  yscroll,

	output logic [11:0] tile_address,
	input  logic [15:0] tile_data,

	output logic [24:0] gfx_addr,
	output logic        gfx_req,
	input  logic [15:0] gfx_dout,
	input  logic        gfx_ack,

	output logic  [7:0] pixel_data,
	output logic        pixel_valid,
	output logic        busy,
	output logic        underrun
);

localparam logic [24:0] TILE_ROM_BASE = 25'h0090000;
localparam logic [24:0] TILE_ROM_HALF = 25'h0080000;

typedef enum logic [2:0]
{
	PF_IDLE,
	PF_TILE_FETCH,
	PF_TILE_WAIT,
	PF_GFX_WAIT,
	PF_OUTPUT
} pf_state_t;

pf_state_t state;

logic [7:0] line_buffer_0 [0:335];
logic [7:0] line_buffer_1 [0:335];
logic [8:0] line_tag_0;
logic [8:0] line_tag_1;
logic       line_valid_0;
logic       line_valid_1;

logic [8:0] target_line;
logic [8:0] world_y;
logic [5:0] tile_column;
logic [15:0] tile_word;
logic [15:0] gfx_word_0;
logic [15:0] gfx_word_1;
logic [15:0] gfx_word_2;
logic [15:0] gfx_word_3;
logic  [1:0] gfx_word_index;
logic  [2:0] tile_pixel;
logic signed [10:0] screen_x;

wire [8:0] next_line = (v_count == 9'd261)
	                  ? 9'd0 : v_count + 9'd1;
wire [8:0] next_world_y = next_line + yscroll;
wire line_start = ce_pix && (h_count == 9'd0);
wire [24:0] tile_row_base = TILE_ROM_BASE
	                       + {6'd0, tile_word[13:0], 5'd0}
	                       + {20'd0, world_y[2:0], 2'd0};

function automatic [7:0] decoded_pixel
(
	input logic [2:0] pixel_number,
	input logic [15:0] word0,
	input logic [15:0] word1,
	input logic [15:0] word2,
	input logic [15:0] word3
);
begin
	case (pixel_number)
		3'd0: decoded_pixel = word0[15:8];
		3'd1: decoded_pixel = word2[15:8];
		3'd2: decoded_pixel = word0[7:0];
		3'd3: decoded_pixel = word2[7:0];
		3'd4: decoded_pixel = word1[15:8];
		3'd5: decoded_pixel = word3[15:8];
		3'd6: decoded_pixel = word1[7:0];
		default: decoded_pixel = word3[7:0];
	endcase
end
endfunction

logic [2:0] source_pixel;
logic [7:0] output_pixel;

always_comb begin
	source_pixel = tile_word[15] ? (3'd7 - tile_pixel) : tile_pixel;
	output_pixel = decoded_pixel(source_pixel,
		gfx_word_0, gfx_word_1, gfx_word_2, gfx_word_3);

	pixel_data  = 8'd0;
	pixel_valid = 1'b0;
	if (h_count < 9'd336) begin
		if (!v_count[0] && line_valid_0 && (line_tag_0 == v_count)) begin
			pixel_data  = line_buffer_0[h_count];
			pixel_valid = 1'b1;
		end
		else if (v_count[0] && line_valid_1
			&& (line_tag_1 == v_count)) begin
			pixel_data  = line_buffer_1[h_count];
			pixel_valid = 1'b1;
		end
	end
end

always_ff @(posedge clk) begin
	if (reset) begin
		state           <= PF_IDLE;
		gfx_addr        <= 25'd0;
		gfx_req         <= 1'b0;
		tile_address    <= 12'd0;
		target_line     <= 9'd0;
		world_y         <= 9'd0;
		tile_column     <= 6'd0;
		tile_word       <= 16'd0;
		gfx_word_0      <= 16'd0;
		gfx_word_1      <= 16'd0;
		gfx_word_2      <= 16'd0;
		gfx_word_3      <= 16'd0;
		gfx_word_index  <= 2'd0;
		tile_pixel      <= 3'd0;
		screen_x        <= 11'sd0;
		line_tag_0      <= 9'd0;
		line_tag_1      <= 9'd0;
		line_valid_0    <= 1'b0;
		line_valid_1    <= 1'b0;
		busy            <= 1'b0;
		underrun        <= 1'b0;
	end
	else begin
		if (line_start && (next_line < 9'd240) && (state != PF_IDLE))
			underrun <= 1'b1;

		case (state)
			PF_IDLE: begin
				busy <= 1'b0;
				if (enable && line_start && (next_line < 9'd240)) begin
					target_line <= next_line;
					world_y     <= next_world_y;
					tile_column <= xscroll[8:3];
					tile_address <= {
						xscroll[8:3], next_world_y[8:3]};
					screen_x <= -$signed({8'd0, xscroll[2:0]});
					busy  <= 1'b1;
					state <= PF_TILE_FETCH;
				end
			end

			// The video port of the tile RAM registers its address in the
			// M10K. Allow one full clock before consuming its output.
			PF_TILE_FETCH: begin
				state <= PF_TILE_WAIT;
			end

			PF_TILE_WAIT: begin
				tile_word      <= tile_data;
				gfx_word_index <= 2'd0;
				gfx_addr       <= TILE_ROM_BASE
				                + {6'd0, tile_data[13:0], 5'd0}
				                + {20'd0, world_y[2:0], 2'd0};
				gfx_req <= ~gfx_req;
				state   <= PF_GFX_WAIT;
			end

			PF_GFX_WAIT: begin
				if (gfx_ack == gfx_req) begin
					case (gfx_word_index)
						2'd0: gfx_word_0 <= gfx_dout;
						2'd1: gfx_word_1 <= gfx_dout;
						2'd2: gfx_word_2 <= gfx_dout;
						default: gfx_word_3 <= gfx_dout;
					endcase

					if (gfx_word_index == 2'd3) begin
						tile_pixel <= 3'd0;
						state      <= PF_OUTPUT;
					end
					else begin
						gfx_word_index <= gfx_word_index + 2'd1;
						case (gfx_word_index)
							2'd0: gfx_addr <= tile_row_base + 25'd2;
							2'd1: gfx_addr <= tile_row_base
							                 + TILE_ROM_HALF;
							default: gfx_addr <= tile_row_base
							                 + TILE_ROM_HALF
							                 + 25'd2;
						endcase
						gfx_req <= ~gfx_req;
					end
				end
			end

			PF_OUTPUT: begin
				if ((screen_x >= 0) && (screen_x < 336)) begin
					if (target_line[0])
						line_buffer_1[screen_x] <= output_pixel;
					else
						line_buffer_0[screen_x] <= output_pixel;
				end

				screen_x   <= screen_x + 11'sd1;
				tile_pixel <= tile_pixel + 3'd1;

				if ((tile_pixel == 3'd7) && (screen_x >= 335)) begin
					if (target_line[0]) begin
						line_tag_1   <= target_line;
						line_valid_1 <= 1'b1;
					end
					else begin
						line_tag_0   <= target_line;
						line_valid_0 <= 1'b1;
					end
					busy  <= 1'b0;
					state <= PF_IDLE;
				end
				else if (tile_pixel == 3'd7) begin
					tile_column  <= tile_column + 6'd1;
					tile_address <= {
						tile_column + 6'd1, world_y[8:3]};
					state <= PF_TILE_FETCH;
				end
			end

			default: state <= PF_IDLE;
		endcase
	end
end

endmodule
