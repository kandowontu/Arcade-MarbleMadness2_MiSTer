// Raster timing documented by MAME's marblmd2 driver:
// 14.318181 MHz CPU/master reference, 7.1590905 MHz pixels,
// 456 clocks/line, 262 lines/frame, 336x240 visible.
//
// The sync positions are provisional because the MAME driver explicitly lists
// the crystals/timing as unverified. Totals and visible area match the driver.

module mm2_video_timing
(
	input  logic       clk,
	input  logic       reset,
	input  logic [3:0] h_adjust,
	input  logic [3:0] v_adjust,
	output logic       ce_pix,
	output logic [8:0] h_count,
	output logic [8:0] v_count,
	output logic       hblank,
	output logic       hsync,
	output logic       vblank,
	output logic       vsync
);

localparam int H_TOTAL      = 456;
localparam int H_VISIBLE    = 336;
localparam int H_SYNC_START = 360;
localparam int H_SYNC_END   = 408;
localparam int V_TOTAL      = 262;
localparam int V_VISIBLE    = 240;
localparam int V_SYNC_START = 244;
localparam int V_SYNC_END   = 247;

logic [2:0] pixel_div;
assign ce_pix = (pixel_div == 3'd0);

// MiSTer encodes these OSD choices as 4-bit two's-complement values:
// 0..+7 followed by -8..-1. Only move the sync windows relative to the
// unchanged active picture and blanking periods; game timing stays native.
integer h_sync_start_adjusted;
integer h_sync_end_adjusted;
integer v_sync_start_adjusted;
integer v_sync_end_adjusted;

always_ff @(posedge clk) begin
	if (reset) begin
		pixel_div <= 3'd0;
		h_count   <= 9'd0;
		v_count   <= 9'd0;
	end
	else begin
		pixel_div <= pixel_div + 3'd1;
		if (ce_pix) begin
			if (h_count == H_TOTAL - 1) begin
				h_count <= 9'd0;
				if (v_count == V_TOTAL - 1)
					v_count <= 9'd0;
				else
					v_count <= v_count + 9'd1;
			end
			else begin
				h_count <= h_count + 9'd1;
			end
		end
	end
end

always_comb begin
	h_sync_start_adjusted = H_SYNC_START + $signed(h_adjust);
	h_sync_end_adjusted   = H_SYNC_END   + $signed(h_adjust);
	v_sync_start_adjusted = V_SYNC_START + $signed(v_adjust);
	v_sync_end_adjusted   = V_SYNC_END   + $signed(v_adjust);

	hblank = (h_count >= H_VISIBLE);
	hsync  = (h_count >= h_sync_start_adjusted)
	      && (h_count <  h_sync_end_adjusted);
	vblank = (v_count >= V_VISIBLE);
	vsync  = (v_count >= v_sync_start_adjusted)
	      && (v_count <  v_sync_end_adjusted);
end

endmodule
