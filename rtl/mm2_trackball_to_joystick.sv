// USB trackball/mouse compatibility for the joystick-based prototype.
//
// The dumped Marble Madness II program reads three digital joysticks. The
// earlier trackball program is not dumped, so MiSTer mouse deltas are paced
// into Player-1 joystick directions instead of pretending that the final
// board exposes trackball counters.
//
// Copyright (C) 2026 kandowontu
// SPDX-License-Identifier: GPL-2.0-or-later

module mm2_trackball_to_joystick
(
	input  logic        clk,
	input  logic        reset,
	input  logic        enable,
	input  logic        frame_tick,
	input  logic  [1:0] sensitivity,
	input  logic [24:0] ps2_mouse,
	input  logic [15:0] joystick_in,
	output logic [15:0] joystick_out
);

logic mouse_toggle_d;
logic signed [11:0] x_budget;
logic signed [11:0] y_budget;
logic signed [11:0] raw_x;
logic signed [11:0] raw_y;
logic signed [11:0] scaled_x;
logic signed [11:0] scaled_y;

function automatic signed [11:0] saturating_add
(
	input signed [11:0] current,
	input signed [11:0] delta
);
	logic signed [12:0] sum;
	begin
		sum = {current[11], current} + {delta[11], delta};
		if (sum > 13'sd2047)
			saturating_add = 12'sd2047;
		else if (sum < -13'sd2047)
			saturating_add = -12'sd2047;
		else
			saturating_add = sum[11:0];
	end
endfunction

always_comb begin
	raw_x = {{4{ps2_mouse[15]}}, ps2_mouse[15:8]};
	raw_y = {{4{ps2_mouse[23]}}, ps2_mouse[23:16]};

	// Zero is the useful power-on default.
	case (sensitivity)
		2'd0: begin // 100%
			scaled_x = raw_x;
			scaled_y = raw_y;
		end
		2'd1: begin // 50%
			scaled_x = raw_x >>> 1;
			scaled_y = raw_y >>> 1;
		end
		2'd2: begin // 25%
			scaled_x = raw_x >>> 2;
			scaled_y = raw_y >>> 2;
		end
		default: begin // 200%
			scaled_x = raw_x <<< 1;
			scaled_y = raw_y <<< 1;
		end
	endcase
end

always_ff @(posedge clk) begin
	mouse_toggle_d <= ps2_mouse[24];

	if (reset || !enable) begin
		x_budget <= 12'sd0;
		y_budget <= 12'sd0;
	end
	else if (mouse_toggle_d != ps2_mouse[24]) begin
		x_budget <= saturating_add(x_budget, scaled_x);
		y_budget <= saturating_add(y_budget, scaled_y);
	end
	else if (frame_tick) begin
		// Consume motion at a stable per-frame rate. This turns a relative
		// trackball packet into a direction long enough for the game loop to
		// sample while bounding latency after a fast spin.
		if (x_budget > 12'sd8)
			x_budget <= x_budget - 12'sd8;
		else if (x_budget < -12'sd8)
			x_budget <= x_budget + 12'sd8;
		else
			x_budget <= 12'sd0;

		if (y_budget > 12'sd8)
			y_budget <= y_budget - 12'sd8;
		else if (y_budget < -12'sd8)
			y_budget <= y_budget + 12'sd8;
		else
			y_budget <= 12'sd0;
	end
end

always_comb begin
	joystick_out = joystick_in;

	if (enable) begin
		// A trackball with two mouse buttons is sufficient to coin and start:
		// left is the game's combined Action/Start input, right is Coin.
		joystick_out[4]  = joystick_in[4]  | ps2_mouse[0];
		joystick_out[11] = joystick_in[11] | ps2_mouse[1];

		if (x_budget != 12'sd0) begin
			joystick_out[0] = (x_budget > 12'sd0); // right
			joystick_out[1] = (x_budget < 12'sd0); // left
		end

		if (y_budget != 12'sd0) begin
			// MiSTer's relative mouse Y follows the PS/2 convention:
			// positive motion is up and negative motion is down.
			joystick_out[2] = (y_budget < 12'sd0); // down
			joystick_out[3] = (y_budget > 12'sd0); // up
		end
	end
end

endmodule
