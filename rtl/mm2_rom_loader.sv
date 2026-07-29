// Packs the MRA byte stream into full 16-bit SDRAM writes while preserving
// 68000 byte order. Even stream addresses occupy DQ[15:8], odd addresses
// occupy DQ[7:0]. Full-word writes avoid depending on SDRAM byte-mask timing
// during the high-throughput HPS download.
//
// Copyright (C) 2026 kandowontu and contributors
// SPDX-License-Identifier: GPL-2.0-or-later

module mm2_rom_loader
(
	input  logic        clk,
	input  logic        reset,
	input  logic        downloading,
	input  logic        ioctl_wr,
	input  logic [24:0] ioctl_addr,
	input  logic  [7:0] ioctl_data,
	output logic        ioctl_wait,

	output logic [24:0] mem_addr,
	output logic [15:0] mem_din,
	output logic  [1:0] mem_be,
	output logic        mem_req,
	input  logic        mem_ack,

	output logic        rom_ready,
	output logic  [7:0] rom_signature,
	output logic        layout_error,

	output logic        download_seen,
	output logic        download_end_seen,
	output logic [21:0] accepted_writes,
	output logic [24:0] last_write_addr,
	output logic  [4:0] regions_seen_debug
);

logic        stream_valid;
logic  [2:0] stream_region;
logic [19:0] region_addr;
logic        stream_last;

mm2_rom_layout layout
(
	.stream_addr(ioctl_addr),
	.valid(stream_valid),
	.region(stream_region),
	.region_addr(region_addr),
	.last_byte(stream_last)
);

logic       downloading_d;
logic [4:0] regions_seen;
logic       commit_pending;
logic       even_byte_pending;
logic [24:0] even_byte_addr;
logic  [7:0] even_byte_data;

assign ioctl_wait = (mem_req != mem_ack);
assign regions_seen_debug = regions_seen;

always_ff @(posedge clk) begin
	downloading_d <= downloading;

	if (reset) begin
		downloading_d <= 1'b0;
		mem_addr      <= 25'd0;
		mem_din       <= 16'd0;
		mem_be        <= 2'b00;
		mem_req       <= 1'b0;
		rom_ready     <= 1'b0;
		rom_signature <= 8'h00;
		layout_error  <= 1'b0;
		regions_seen  <= 5'b00000;
		commit_pending <= 1'b0;
		even_byte_pending <= 1'b0;
		even_byte_addr <= 25'd0;
		even_byte_data <= 8'd0;
		download_seen <= 1'b0;
		download_end_seen <= 1'b0;
		accepted_writes <= 22'd0;
		last_write_addr <= 25'd0;
	end
	else begin
		if (downloading && !downloading_d) begin
			rom_ready     <= 1'b0;
			rom_signature <= 8'h00;
			layout_error  <= 1'b0;
			regions_seen  <= 5'b00000;
			commit_pending <= 1'b0;
			even_byte_pending <= 1'b0;
			even_byte_addr <= 25'd0;
			even_byte_data <= 8'd0;
			download_seen <= 1'b1;
			download_end_seen <= 1'b0;
			accepted_writes <= 22'd0;
			last_write_addr <= 25'd0;
		end

		if (commit_pending && (mem_req == mem_ack)) begin
			rom_ready      <= !layout_error && (&regions_seen);
			commit_pending <= 1'b0;
		end

		// ioctl_wr is already qualified with the ROM index by the top level.
		// Do not additionally gate it with downloading: the HPS can change the
		// download flag on the boundary clock surrounding the final data strobe.
		if (ioctl_wr && (mem_req == mem_ack)) begin
			accepted_writes <= accepted_writes + 22'd1;
			last_write_addr <= ioctl_addr;

			if (!stream_valid) begin
				layout_error <= 1'b1;
			end
			else begin
				if (!ioctl_addr[0]) begin
					if (even_byte_pending)
						layout_error <= 1'b1;

					even_byte_pending <= 1'b1;
					even_byte_addr    <= ioctl_addr;
					even_byte_data    <= ioctl_data;
				end
				else begin
					if (!even_byte_pending
						|| (even_byte_addr + 25'd1 != ioctl_addr)) begin
						layout_error <= 1'b1;
					end
					else begin
						mem_addr <= even_byte_addr;
						mem_din  <= {even_byte_data, ioctl_data};
						mem_be   <= 2'b11;
						mem_req  <= ~mem_req;
					end
					even_byte_pending <= 1'b0;
				end

				regions_seen[stream_region] <= 1'b1;
				rom_signature <= {rom_signature[6:0], rom_signature[7]}
				               ^ ioctl_data ^ region_addr[7:0];

				if (stream_last) begin
					commit_pending <= 1'b1;
					// Include the last region before checking it after ack.
					regions_seen[stream_region] <= 1'b1;
				end
			end
		end

		// Normal MiSTer downloads are also complete when ioctl_download falls.
		// This makes completion independent of an exact last-address strobe
		// while the SDRAM handshake still guarantees all accepted data drained.
		if (downloading_d && !downloading) begin
			download_end_seen <= 1'b1;
			commit_pending <= 1'b1;
			// ioctl_download may fall on the same clock as the final odd-byte
			// strobe. That strobe consumes the pending even byte above.
			if (even_byte_pending
				&& !(ioctl_wr && stream_valid && ioctl_addr[0]
					&& (even_byte_addr + 25'd1 == ioctl_addr)))
				layout_error <= 1'b1;
		end
	end
end

endmodule
