// Converts the packed MRA byte stream to logical ROM regions.
//
// Stream layout:
//   000000-07ffff  68000 program (already byte-interleaved)
//   080000-08ffff  JSA III 6502 program
//   090000-18ffff  playfield graphics
//   190000-20ffff  motion-object graphics
//   210000-22ffff  OKI sample ROM at logical 00000
//   230000-24ffff  OKI sample ROM at logical 60000

module mm2_rom_layout
(
	input  logic [24:0] stream_addr,
	output logic        valid,
	output logic  [2:0] region,
	output logic [19:0] region_addr,
	output logic        last_byte
);

localparam logic [2:0] REGION_MAIN    = 3'd0;
localparam logic [2:0] REGION_AUDIO   = 3'd1;
localparam logic [2:0] REGION_TILES   = 3'd2;
localparam logic [2:0] REGION_SPRITES = 3'd3;
localparam logic [2:0] REGION_SAMPLES = 3'd4;

always_comb begin
	valid       = 1'b1;
	region      = REGION_MAIN;
	region_addr = 20'd0;
	last_byte   = (stream_addr == 25'h024ffff);

	if (stream_addr < 25'h0080000) begin
		region      = REGION_MAIN;
		region_addr = stream_addr[19:0];
	end
	else if (stream_addr < 25'h0090000) begin
		region      = REGION_AUDIO;
		region_addr = stream_addr[19:0] - 20'h80000;
	end
	else if (stream_addr < 25'h0190000) begin
		region      = REGION_TILES;
		region_addr = stream_addr[19:0] - 20'h90000;
	end
	else if (stream_addr < 25'h0210000) begin
		region      = REGION_SPRITES;
		region_addr = stream_addr[19:0] - 20'h90000;
	end
	else if (stream_addr < 25'h0230000) begin
		region      = REGION_SAMPLES;
		region_addr = stream_addr[19:0] - 20'h10000;
	end
	else if (stream_addr < 25'h0250000) begin
		region      = REGION_SAMPLES;
		region_addr = 20'h60000 + (stream_addr[19:0] - 20'h30000);
	end
	else begin
		valid       = 1'b0;
		region      = REGION_MAIN;
		region_addr = 20'd0;
		last_byte   = 1'b0;
	end
end

endmodule
