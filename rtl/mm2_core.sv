// Marble Madness II platform integration shell.
//
// Phase 3 adds the Atari VAD primary playfield, scanline IRQ, scrolling,
// split-half eight-bit graphics decode, and IRGB1555 palette conversion.
//
// Copyright (C) 2026 kandowontu and contributors
// SPDX-License-Identifier: GPL-2.0-or-later

module mm2_core
(
	input  logic        clk,
	input  logic        reset,
	input  logic        storage_reset,
	input  logic        memory_ready,
	input  logic        service,
	input  logic [15:0] dip_switches,

	input  logic        rom_downloading,
	input  logic        rom_wr,
	input  logic [24:0] rom_addr,
	input  logic  [7:0] rom_data,
	output logic        rom_wait,

	input  logic        eeprom_loading,
	input  logic        eeprom_host_write,
	input  logic [10:0] eeprom_host_address,
	input  logic  [7:0] eeprom_host_data,
	output logic  [7:0] eeprom_host_q,
	output logic        eeprom_dirty,

	input  logic [15:0] joystick_p1,
	input  logic [15:0] joystick_p2,
	input  logic [15:0] joystick_p3,

	output logic [24:0] mem_addr,
	output logic [15:0] mem_din,
	output logic  [1:0] mem_be,
	output logic        mem_rnw,
	output logic        mem_req,
	input  logic [15:0] mem_dout,
	input  logic        mem_ack,

	output logic        ce_pix,
	output logic        hblank,
	output logic        hsync,
	output logic        vblank,
	output logic        vsync,
	output logic  [7:0] red,
	output logic  [7:0] green,
	output logic  [7:0] blue,
	output logic signed [15:0] audio,
	output logic        rom_ready
);

logic [8:0] h_count;
logic [8:0] v_count;

mm2_video_timing video_timing
(
	.clk(clk),
	.reset(reset),
	.ce_pix(ce_pix),
	.h_count(h_count),
	.v_count(v_count),
	.hblank(hblank),
	.hsync(hsync),
	.vblank(vblank),
	.vsync(vsync)
);

logic [24:0] loader_addr;
logic [15:0] loader_din;
logic  [1:0] loader_be;
logic        loader_req;
logic        loader_ack;
logic        rom_layout_error;

mm2_rom_loader rom_loader
(
	.clk(clk),
	// ROM presence must survive menu/game resets. Only a new FPGA image or
	// loss of the core PLL clears the persistent loader state.
	.reset(storage_reset),
	.downloading(rom_downloading),
	.ioctl_wr(rom_wr),
	.ioctl_addr(rom_addr),
	.ioctl_data(rom_data),
	.ioctl_wait(rom_wait),
	.mem_addr(loader_addr),
	.mem_din(loader_din),
	.mem_be(loader_be),
	.mem_req(loader_req),
	.mem_ack(loader_ack),
	.rom_ready(rom_ready),
	.rom_signature(),
	.layout_error(rom_layout_error),
	.download_seen(),
	.download_end_seen(),
	.accepted_writes(),
	.last_write_addr(),
	.regions_seen_debug()
);

logic [24:0] cpu_rom_addr;
logic        cpu_rom_req;
logic [15:0] cpu_rom_dout;
logic        cpu_rom_ack;
logic [11:0] playfield_tile_address;
logic [15:0] playfield_tile_data;
logic  [7:0] video_palette_address;
logic [15:0] video_palette_data;
logic [11:0] motion_ram_address;
logic [15:0] motion_ram_data;
logic  [8:0] playfield_xscroll;
logic  [8:0] playfield_yscroll;
logic  [8:0] motion_xscroll;
logic  [8:0] motion_yscroll;
logic        cpu_running;
logic  [7:0] sound_command;
logic        sound_command_ready;
logic        sound_command_read;
logic  [7:0] sound_response;
logic        sound_response_write;
logic        sound_response_ready;
logic        sound_nmi_n;
logic        sound_reset_n;

// CPU execution starts only after SDRAM initialization and a complete,
// committed ROM stream. It is halted again immediately for a replacement
// download.
wire cpu_reset = reset
	               || !memory_ready
	               || !rom_ready
	               || rom_downloading
	               || rom_wait
	               || eeprom_loading;

mm2_cpu_subsystem cpu_subsystem
(
	.clk(clk),
	.reset(cpu_reset),
	.ce_pix,
	.h_count,
	.v_count,
	.vblank(vblank),
	.service(service),
	.dip_switches(dip_switches),
	.joystick_p1(joystick_p1),
	.joystick_p2(joystick_p2),
	.joystick_p3(joystick_p3),
	.rom_addr(cpu_rom_addr),
	.rom_req(cpu_rom_req),
	.rom_dout(cpu_rom_dout),
	.rom_ack(cpu_rom_ack),
	.playfield_tile_address,
	.playfield_tile_data,
	.video_palette_address,
	.video_palette_data,
	.motion_ram_address,
	.motion_ram_data,
	.playfield_xscroll,
	.playfield_yscroll,
	.motion_xscroll,
	.motion_yscroll,
	.sound_command,
	.sound_command_ready,
	.sound_command_read,
	.sound_response,
	.sound_response_write,
	.sound_response_ready,
	.sound_nmi_n,
	.sound_reset_n,
	.eeprom_host_write,
	.eeprom_host_address,
	.eeprom_host_data,
	.eeprom_host_q,
	.eeprom_dirty,
	.debug_address(),
	.debug_data(),
	.debug_as(),
	.debug_rw(),
	.debug_bus_cycles(),
	.debug_unmapped_cycles(),
	.cpu_running(cpu_running)
);

logic [24:0] video_rom_addr;
logic        video_rom_req;
logic [15:0] video_rom_dout;
logic        video_rom_ack;
logic  [7:0] playfield_pixel;
logic        playfield_pixel_valid;
logic        playfield_busy;
logic        playfield_underrun;

mm2_playfield playfield
(
	.clk,
	.reset,
	.enable(memory_ready && rom_ready && !rom_downloading),
	.ce_pix,
	.h_count,
	.v_count,
	.xscroll(playfield_xscroll),
	.yscroll(playfield_yscroll),
	.tile_address(playfield_tile_address),
	.tile_data(playfield_tile_data),
	.gfx_addr(video_rom_addr),
	.gfx_req(video_rom_req),
	.gfx_dout(video_rom_dout),
	.gfx_ack(video_rom_ack),
	.pixel_data(playfield_pixel),
	.pixel_valid(playfield_pixel_valid),
	.busy(playfield_busy),
	.underrun(playfield_underrun)
);

logic [24:0] motion_rom_addr;
logic        motion_rom_req;
logic [15:0] motion_rom_dout;
logic        motion_rom_ack;
logic  [7:0] motion_pixel;
logic        motion_pixel_opaque;
logic        motion_pixel_valid;
logic        motion_busy;
logic        motion_underrun;
logic [24:0] sound_rom_addr;
logic        sound_rom_req;
logic [15:0] sound_rom_dout;
logic        sound_rom_ack;
mm2_jsa_iii sound_board
(
	.clk,
	.reset,
	.enable(memory_ready && rom_ready && !rom_downloading),
	.service,
	.coin1(joystick_p1[11] | joystick_p3[11]),
	.coin2(joystick_p2[11]),
	.sound_reset_n,
	.command_data(sound_command),
	.command_ready(sound_command_ready),
	.command_read(sound_command_read),
	.command_nmi_n(sound_nmi_n),
	.response_ready(sound_response_ready),
	.response_data(sound_response),
	.response_write(sound_response_write),
	.rom_wr(rom_wr && (rom_addr >= 25'h0080000)
		&& (rom_addr < 25'h0090000)),
	.rom_addr(rom_addr[15:0]),
	.rom_data,
	.sample_addr(sound_rom_addr),
	.sample_req(sound_rom_req),
	.sample_dout(sound_rom_dout),
	.sample_ack(sound_rom_ack),
	.audio
);

mm2_motion_objects motion_objects
(
	.clk,
	.reset,
	.enable(memory_ready && rom_ready && !rom_downloading),
	.ce_pix,
	.h_count,
	.v_count,
	.xscroll(motion_xscroll),
	.yscroll(motion_yscroll),
	.ram_address(motion_ram_address),
	.ram_data(motion_ram_data),
	.gfx_addr(motion_rom_addr),
	.gfx_req(motion_rom_req),
	.gfx_dout(motion_rom_dout),
	.gfx_ack(motion_rom_ack),
	.pixel_data(motion_pixel),
	.pixel_opaque(motion_pixel_opaque),
	.pixel_valid(motion_pixel_valid),
	.busy(motion_busy),
	.underrun(motion_underrun)
);

logic [7:0] mixed_palette_address;
logic       mixed_pixel_valid;

always_comb begin
	mixed_palette_address = {1'b0, playfield_pixel[6:0]};
	mixed_pixel_valid = playfield_pixel_valid;

	if (motion_pixel_valid && motion_pixel_opaque) begin
		if (!playfield_pixel_valid || !playfield_pixel[7]) begin
			// Low-priority playfield: force all motion objects into the
			// upper 128-entry palette bank.
			mixed_palette_address = motion_pixel | 8'h80;
			mixed_pixel_valid = 1'b1;
		end
		else if (motion_pixel[7]) begin
			// High-priority playfield only yields to MO colors 8-15.
			mixed_palette_address = motion_pixel;
			mixed_pixel_valid = 1'b1;
		end
	end
end

assign video_palette_address = mixed_palette_address;

mm2_memory_arbiter memory_arbiter
(
	.clk(clk),
	// MiSTer holds the runtime reset while an MRA begins transferring ROM #0.
	// Keep the storage path alive with the loader or the first accepted byte
	// asserts ioctl_wait while a reset arbiter can never acknowledge it.
	.reset(storage_reset),
	.loader_addr(loader_addr),
	.loader_din(loader_din),
	.loader_be(loader_be),
	.loader_req(loader_req),
	.loader_ack(loader_ack),
	.cpu_addr(cpu_rom_addr),
	.cpu_req(cpu_rom_req),
	.cpu_dout(cpu_rom_dout),
	.cpu_ack(cpu_rom_ack),
	.video_addr(video_rom_addr),
	.video_req(video_rom_req),
	.video_dout(video_rom_dout),
	.video_ack(video_rom_ack),
	.motion_addr(motion_rom_addr),
	.motion_req(motion_rom_req),
	.motion_dout(motion_rom_dout),
	.motion_ack(motion_rom_ack),
	.sound_addr(sound_rom_addr),
	.sound_req(sound_rom_req),
	.sound_dout(sound_rom_dout),
	.sound_ack(sound_rom_ack),
	.mem_addr(mem_addr),
	.mem_din(mem_din),
	.mem_be(mem_be),
	.mem_rnw(mem_rnw),
	.mem_req(mem_req),
	.mem_dout(mem_dout),
	.mem_ack(mem_ack)
);

logic [5:0] palette_red;
logic [5:0] palette_green;
logic [5:0] palette_blue;

always_comb begin
	// MAME's IRGB1555 decoder treats the intensity bit as the least
	// significant bit of each six-bit color component.
	palette_red   = {video_palette_data[14:10],
		video_palette_data[15]};
	palette_green = {video_palette_data[9:5],
		video_palette_data[15]};
	palette_blue  = {video_palette_data[4:0],
		video_palette_data[15]};

	if (hblank || vblank || !memory_ready || !rom_ready
		|| rom_layout_error) begin
		red   = 8'h00;
		green = 8'h00;
		blue  = 8'h00;
	end
	else begin
		// The playfield's graphics bit 7 is retained in the line buffer for
		// the phase-4 object mixer, but is masked from the palette address.
		if (mixed_pixel_valid) begin
			red   = {palette_red, palette_red[5:4]};
			green = {palette_green, palette_green[5:4]};
			blue  = {palette_blue, palette_blue[5:4]};
		end
		else begin
			red   = 8'd0;
			green = 8'd0;
			blue  = 8'd0;
		end
	end
end

endmodule
