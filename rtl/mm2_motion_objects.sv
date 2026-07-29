// Atari linked-list motion-object scanline renderer for Marble Madness II.
//
// One SLIP word selects a linked list for each eight-line band. Four-word
// entries describe an object. The renderer evaluates the list for the next
// visible scanline and writes opaque 4bpp pixels into alternating line
// buffers. Later objects in the list overwrite earlier objects, matching the
// non-reversed MAME configuration.
//
// Copyright (C) 2026 kandowontu and contributors
// SPDX-License-Identifier: GPL-2.0-or-later

module mm2_motion_objects
(
	input  logic        clk,
	input  logic        reset,
	input  logic        enable,
	input  logic        ce_pix,
	input  logic [8:0]  h_count,
	input  logic [8:0]  v_count,
	input  logic [8:0]  xscroll,
	input  logic [8:0]  yscroll,

	output logic [11:0] ram_address,
	input  logic [15:0] ram_data,

	output logic [24:0] gfx_addr,
	output logic        gfx_req,
	input  logic [15:0] gfx_dout,
	input  logic        gfx_ack,

	output logic  [7:0] pixel_data,
	output logic        pixel_opaque,
	output logic        pixel_valid,
	output logic        busy,
	output logic        underrun
);

localparam logic [11:0] SLIP_WORD_BASE = 12'hfc0;
localparam logic [24:0] MOTION_ROM_BASE = 25'h0190000;
localparam logic [24:0] MOTION_ROM_HALF = 25'h0040000;
localparam logic  [9:0] LAST_VALID_LINK = 10'd991;

typedef enum logic [3:0]
{
	MO_IDLE,
	MO_CLEAR,
	MO_SLIP_FETCH,
	MO_SLIP_LATCH,
	MO_ENTRY_FETCH,
	MO_ENTRY_LATCH,
	MO_EVALUATE,
	MO_GFX_FIRST,
	MO_GFX_SECOND,
	MO_OUTPUT,
	MO_ADVANCE,
	MO_FINISH
} mo_state_t;

mo_state_t state;

logic [8:0] line_tag_0;
logic [8:0] line_tag_1;
logic       line_valid_0;
logic       line_valid_1;
logic       line_write;
logic [8:0] line_write_address;
logic [8:0] line_write_data;
wire  [8:0] line_data_0;
wire  [8:0] line_data_1;

mm2_line_buffer #(.WIDTH(9)) line_buffer_0
(
	.clk,
	.write(line_write && !target_line[0]),
	.write_address(line_write_address),
	.write_data(line_write_data),
	.read_address(h_count),
	.read_data(line_data_0)
);

mm2_line_buffer #(.WIDTH(9)) line_buffer_1
(
	.clk,
	.write(line_write && target_line[0]),
	.write_address(line_write_address),
	.write_data(line_write_data),
	.read_address(h_count),
	.read_data(line_data_1)
);

logic [8:0] target_line;
logic [8:0] clear_x;
logic [9:0] current_link;
logic [1:0] entry_word_index;
logic [15:0] entry_word_0;
logic [15:0] entry_word_1;
logic [15:0] entry_word_2;
logic [15:0] entry_word_3;
logic [1023:0] visited;

logic signed [10:0] current_object_x;
logic [14:0] current_base_code;
logic  [3:0] current_width;
logic  [2:0] current_tile_row;
logic  [2:0] current_gfx_row;
logic  [3:0] current_color;
logic        current_hflip;
logic  [3:0] current_tile_column;
logic  [2:0] current_pixel;
logic [15:0] gfx_first_word;
logic [15:0] gfx_second_word;

wire [8:0] next_line = (v_count == 9'd261)
	                  ? 9'd0 : v_count + 9'd1;
wire [8:0] next_world_y = next_line + yscroll;
wire line_start = ce_pix && (h_count == 9'd0);

logic [3:0] object_width;
logic [3:0] object_height;
logic [8:0] wrapped_x;
logic [8:0] wrapped_y;
logic signed [10:0] object_x;
logic signed [10:0] object_y;
logic signed [11:0] object_bottom;
logic signed [10:0] target_signed;
logic [10:0] relative_y;
logic object_on_line;

always @* begin
	object_width  = {1'b0, entry_word_3[6:4]} + 4'd1;
	object_height = {1'b0, entry_word_3[2:0]} + 4'd1;

	wrapped_x = entry_word_2[15:7] - xscroll;
	if (wrapped_x >= 9'd336)
		object_x = $signed({2'b00, wrapped_x}) - 11'sd512;
	else
		object_x = $signed({2'b00, wrapped_x});

	wrapped_y = 9'd0
	          - entry_word_3[15:7]
	          - {2'd0, object_height, 3'd0}
	          - yscroll;
	if (wrapped_y >= 9'd240)
		object_y = $signed({2'b00, wrapped_y}) - 11'sd512;
	else
		object_y = $signed({2'b00, wrapped_y});

	target_signed = $signed({2'b00, target_line});
	object_bottom = object_y
	              + $signed({5'd0, object_height, 3'd0});
	object_on_line = (target_signed >= object_y)
	               && ($signed({1'b0, target_signed}) < object_bottom);
	relative_y = target_signed - object_y;
end

function automatic [13:0] tile_code_for
(
	input logic [14:0] base_code,
	input logic  [2:0] tile_row,
	input logic  [3:0] width,
	input logic  [3:0] screen_column,
	input logic        hflip
);
	integer code_offset;
begin
	if (hflip)
		code_offset = (tile_row * width)
		            + (width - 1 - screen_column);
	else
		code_offset = (tile_row * width) + screen_column;
	tile_code_for = (base_code + code_offset) & 14'h3fff;
end
endfunction

function automatic [24:0] tile_row_address
(
	input logic [13:0] tile_code,
	input logic  [2:0] row
);
begin
	tile_row_address = MOTION_ROM_BASE
	                 + {7'd0, tile_code, 4'd0}
	                 + {21'd0, row, 1'b0};
end
endfunction

function automatic [3:0] decoded_nibble
(
	input logic [2:0] pixel_number,
	input logic [15:0] first_half,
	input logic [15:0] second_half
);
begin
	case (pixel_number)
		3'd0: decoded_nibble = second_half[15:12];
		3'd1: decoded_nibble = second_half[11:8];
		3'd2: decoded_nibble = first_half[15:12];
		3'd3: decoded_nibble = first_half[11:8];
		3'd4: decoded_nibble = second_half[7:4];
		3'd5: decoded_nibble = second_half[3:0];
		3'd6: decoded_nibble = first_half[7:4];
		default: decoded_nibble = first_half[3:0];
	endcase
end
endfunction

logic [2:0] source_pixel;
logic [3:0] output_pen;
logic signed [10:0] output_x;

always @* begin
	source_pixel = current_hflip
	             ? (3'd7 - current_pixel) : current_pixel;
	output_pen = decoded_nibble(
		source_pixel, gfx_first_word, gfx_second_word);
	output_x = current_object_x
	         + $signed({4'd0, current_tile_column, 3'd0})
	         + $signed({8'd0, current_pixel});

	line_write = 1'b0;
	line_write_address = 9'd0;
	line_write_data = 9'd0;
	if (state == MO_CLEAR) begin
		line_write = 1'b1;
		line_write_address = clear_x;
	end
	else if ((state == MO_OUTPUT) && (output_pen != 4'd0)
		&& (output_x >= 0) && (output_x < 336)) begin
		line_write = 1'b1;
		line_write_address = output_x[8:0];
		line_write_data = {1'b1, current_color, output_pen};
	end

	pixel_data   = 8'd0;
	pixel_opaque = 1'b0;
	pixel_valid  = 1'b0;
	if (h_count < 9'd336) begin
		if (!v_count[0] && line_valid_0 && (line_tag_0 == v_count)) begin
			pixel_data   = line_data_0[7:0];
			pixel_opaque = line_data_0[8];
			pixel_valid  = 1'b1;
		end
		else if (v_count[0] && line_valid_1
			&& (line_tag_1 == v_count)) begin
			pixel_data   = line_data_1[7:0];
			pixel_opaque = line_data_1[8];
			pixel_valid  = 1'b1;
		end
	end
end

always_ff @(posedge clk) begin
	if (reset) begin
		state               <= MO_IDLE;
		ram_address         <= 12'd0;
		gfx_addr            <= 25'd0;
		gfx_req             <= 1'b0;
		target_line         <= 9'd0;
		clear_x             <= 9'd0;
		current_link        <= 10'd0;
		entry_word_index    <= 2'd0;
		entry_word_0        <= 16'd0;
		entry_word_1        <= 16'd0;
		entry_word_2        <= 16'd0;
		entry_word_3        <= 16'd0;
		visited             <= '0;
		current_object_x    <= 11'sd0;
		current_base_code   <= 15'd0;
		current_width       <= 4'd1;
		current_tile_row    <= 3'd0;
		current_gfx_row     <= 3'd0;
		current_color       <= 4'd0;
		current_hflip       <= 1'b0;
		current_tile_column <= 4'd0;
		current_pixel       <= 3'd0;
		gfx_first_word      <= 16'd0;
		gfx_second_word     <= 16'd0;
		line_tag_0          <= 9'd0;
		line_tag_1          <= 9'd0;
		line_valid_0        <= 1'b0;
		line_valid_1        <= 1'b0;
		busy                <= 1'b0;
		underrun            <= 1'b0;
	end
	else begin
		// Drop a stale/invalid startup list at the scanline deadline rather
		// than allowing it to wedge all subsequent motion-object lines.
		// The diagnostic is per-frame and clears on entry to vertical blank.
		if (line_start && (v_count == 9'd240))
			underrun <= 1'b0;

		if (enable && line_start && (next_line < 9'd240)) begin
			if ((state != MO_IDLE) && (state != MO_FINISH))
				underrun <= 1'b1;

			// MO_FINISH reached exactly at the boundary is still on time.
			if (state == MO_FINISH) begin
				if (target_line[0]) begin
					line_tag_1   <= target_line;
					line_valid_1 <= 1'b1;
				end
				else begin
					line_tag_0   <= target_line;
					line_valid_0 <= 1'b1;
				end
			end

			target_line <= next_line;
			clear_x     <= 9'd0;
			busy        <= 1'b1;
			state       <= MO_CLEAR;
		end
		else case (state)
			MO_IDLE: begin
				busy <= 1'b0;
			end

			MO_CLEAR: begin
				if (clear_x == 9'd335) begin
					ram_address <= SLIP_WORD_BASE
					             + {6'd0, next_world_y[8:3]};
					state <= MO_SLIP_FETCH;
				end
				else begin
					clear_x <= clear_x + 9'd1;
				end
			end

			// The shadow RAM video address is registered in its M10K.
			MO_SLIP_FETCH: state <= MO_SLIP_LATCH;

			MO_SLIP_LATCH: begin
				visited          <= '0;
				current_link     <= ram_data[9:0];
				entry_word_index <= 2'd0;
				if (ram_data[9:0] > LAST_VALID_LINK) begin
					state <= MO_FINISH;
				end
				else begin
					ram_address <= {ram_data[9:0], 2'b00};
					state <= MO_ENTRY_FETCH;
				end
			end

			MO_ENTRY_FETCH: begin
				visited[current_link] <= 1'b1;
				state <= MO_ENTRY_LATCH;
			end

			MO_ENTRY_LATCH: begin
				case (entry_word_index)
					2'd0: entry_word_0 <= ram_data;
					2'd1: entry_word_1 <= ram_data;
					2'd2: entry_word_2 <= ram_data;
					default: entry_word_3 <= ram_data;
				endcase

				if (entry_word_index == 2'd3) begin
					state <= MO_EVALUATE;
				end
				else begin
					entry_word_index <= entry_word_index + 2'd1;
					ram_address <= ram_address + 12'd1;
					state <= MO_ENTRY_FETCH;
				end
			end

			MO_EVALUATE: begin
				if (!object_on_line) begin
					state <= MO_ADVANCE;
				end
				else begin
					current_object_x    <= object_x;
					current_base_code   <= entry_word_1[14:0];
					current_width       <= object_width;
					current_tile_row    <= relative_y[5:3];
					current_gfx_row     <= relative_y[2:0];
					current_color       <= entry_word_2[3:0];
					current_hflip       <= entry_word_1[15];
					current_tile_column <= 4'd0;
					current_pixel       <= 3'd0;
					gfx_addr <= tile_row_address(
						tile_code_for(
							entry_word_1[14:0],
							relative_y[5:3],
							object_width,
							4'd0,
							entry_word_1[15]),
						relative_y[2:0]);
					gfx_req <= ~gfx_req;
					state <= MO_GFX_FIRST;
				end
			end

			MO_GFX_FIRST: begin
				if (gfx_ack == gfx_req) begin
					gfx_first_word <= gfx_dout;
					gfx_addr <= gfx_addr + MOTION_ROM_HALF;
					gfx_req <= ~gfx_req;
					state <= MO_GFX_SECOND;
				end
			end

			MO_GFX_SECOND: begin
				if (gfx_ack == gfx_req) begin
					gfx_second_word <= gfx_dout;
					current_pixel <= 3'd0;
					state <= MO_OUTPUT;
				end
			end

			MO_OUTPUT: begin
				current_pixel <= current_pixel + 3'd1;
				if (current_pixel == 3'd7) begin
					if ((current_tile_column + 4'd1)
						< current_width) begin
						current_tile_column
							<= current_tile_column + 4'd1;
						current_pixel <= 3'd0;
						gfx_addr <= tile_row_address(
							tile_code_for(
								current_base_code,
								current_tile_row,
								current_width,
								current_tile_column + 4'd1,
								current_hflip),
							current_gfx_row);
						gfx_req <= ~gfx_req;
						state <= MO_GFX_FIRST;
					end
					else begin
						state <= MO_ADVANCE;
					end
				end
			end

			MO_ADVANCE: begin
				entry_word_index <= 2'd0;
				if ((entry_word_0[9:0] > LAST_VALID_LINK)
					|| visited[entry_word_0[9:0]]) begin
					state <= MO_FINISH;
				end
				else begin
					current_link <= entry_word_0[9:0];
					ram_address <= {entry_word_0[9:0], 2'b00};
					state <= MO_ENTRY_FETCH;
				end
			end

			MO_FINISH: begin
				if (target_line[0]) begin
					line_tag_1   <= target_line;
					line_valid_1 <= 1'b1;
				end
				else begin
					line_tag_0   <= target_line;
					line_valid_0 <= 1'b1;
				end
				busy  <= 1'b0;
				state <= MO_IDLE;
			end

			default: state <= MO_IDLE;
		endcase
	end
end

endmodule
