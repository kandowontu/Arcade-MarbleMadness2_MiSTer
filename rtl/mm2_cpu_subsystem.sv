// Marble Madness II 68000, bus fabric, local RAM, inputs, EEPROM, palette,
// and Atari VAD control path.
//
// The CPU runs at 14.318181 MHz from alternating enables on the 57.272724 MHz
// system clock. Program ROM reads use a toggle handshake to external SDRAM.
//
// Copyright (C) 2026 kandowontu and contributors
// SPDX-License-Identifier: GPL-2.0-or-later

module mm2_cpu_subsystem
(
	input  logic        clk,
	input  logic        reset,
	input  logic        ce_pix,
	input  logic [8:0]  h_count,
	input  logic [8:0]  v_count,
	input  logic        vblank,
	input  logic        service,
	input  logic [15:0] dip_switches,
	input  logic [15:0] joystick_p1,
	input  logic [15:0] joystick_p2,
	input  logic [15:0] joystick_p3,

	output logic [24:0] rom_addr,
	output logic        rom_req,
	input  logic [15:0] rom_dout,
	input  logic        rom_ack,

	input  logic [11:0] playfield_tile_address,
	output logic [15:0] playfield_tile_data,
	input  logic  [7:0] video_palette_address,
	output logic [15:0] video_palette_data,
	input  logic [11:0] motion_ram_address,
	output logic [15:0] motion_ram_data,
	output logic  [8:0] playfield_xscroll,
	output logic  [8:0] playfield_yscroll,
	output logic  [8:0] motion_xscroll,
	output logic  [8:0] motion_yscroll,

	output logic  [7:0] sound_command,
	output logic        sound_command_ready,
	input  logic        sound_command_read,
	input  logic  [7:0] sound_response,
	input  logic        sound_response_write,
	output logic        sound_response_ready,
	output logic        sound_nmi_n,
	output logic        sound_reset_n,

	input  logic        eeprom_host_write,
	input  logic [10:0] eeprom_host_address,
	input  logic  [7:0] eeprom_host_data,
	output logic  [7:0] eeprom_host_q,
	output logic        eeprom_dirty,

	output logic [23:0] debug_address,
	output logic [15:0] debug_data,
	output logic        debug_as,
	output logic        debug_rw,
	output logic [31:0] debug_bus_cycles,
	output logic [15:0] debug_unmapped_cycles,
	output logic        cpu_running
);

logic [1:0] cpu_phase;
wire cpu_phi1 = (cpu_phase == 2'd0);
wire cpu_phi2 = (cpu_phase == 2'd2);

always_ff @(posedge clk) begin
	if (reset)
		cpu_phase <= 2'd0;
	else
		cpu_phase <= cpu_phase + 2'd1;
end

wire        cpu_rw;
wire        cpu_as_n;
wire        cpu_lds_n;
wire        cpu_uds_n;
wire [2:0]  cpu_fc;
wire [15:0] cpu_data_out;
logic [15:0] cpu_data_in;
wire [23:1] cpu_word_addr;
logic        cpu_dtack_n;

// FC=111 is a CPU-space interrupt acknowledge cycle. VPA low requests the
// 68000's automatic vector for the level encoded on IPL.
wire cpu_iack_n = ~&cpu_fc;
wire cpu_vpa_n  = cpu_iack_n;

logic vad_irq4;
logic sound_irq6;
wire [2:0] cpu_ipl_n = sound_irq6 ? ~3'b110
	                       : vad_irq4 ? ~3'b100 : 3'b111;

fx68k main_cpu
(
	.clk(clk),
	.HALTn(1'b1),
	.extReset(reset),
	.pwrUp(reset),
	.enPhi1(cpu_phi1),
	.enPhi2(cpu_phi2),

	.eRWn(cpu_rw),
	.ASn(cpu_as_n),
	.LDSn(cpu_lds_n),
	.UDSn(cpu_uds_n),
	.E(),
	.VMAn(),

	.FC0(cpu_fc[0]),
	.FC1(cpu_fc[1]),
	.FC2(cpu_fc[2]),
	.BGn(),
	.oRESETn(),
	.oHALTEDn(),
	.DTACKn(cpu_dtack_n),
	.VPAn(cpu_vpa_n),
	.BERRn(1'b1),
	.BRn(1'b1),
	.BGACKn(1'b1),
	.IPL0n(cpu_ipl_n[0]),
	.IPL1n(cpu_ipl_n[1]),
	.IPL2n(cpu_ipl_n[2]),
	.iEdb(cpu_data_in),
	.oEdb(cpu_data_out),
	.eab(cpu_word_addr)
);

// A0 is not a physical 68000 address pin. Infer it for an odd-byte cycle so
// the byte-granular MAME-derived decoder can retain its documented addresses.
wire [23:0] cpu_even_address = {cpu_word_addr, 1'b0};
wire [23:0] cpu_bus_address =
	{cpu_word_addr, (!cpu_lds_n && cpu_uds_n)};

wire cs_program;
wire cs_p1_buttons;
wire cs_p2_buttons;
wire cs_status;
wire cs_joysticks;
wire cs_sound_response;
wire cs_sound_command;
wire cs_latch;
wire cs_eeprom_unlock;
wire cs_eeprom;
wire cs_watchdog;
wire cs_palette;
wire cs_vad_control;
wire cs_workram;
wire cs_playfield;
wire cs_motion;
wire cs_eof;
wire cs_slip;

mm2_address_decode decode
(
	.address(cpu_bus_address),
	.cs_program,
	.cs_p1_buttons,
	.cs_p2_buttons,
	.cs_status,
	.cs_joysticks,
	.cs_sound_response,
	.cs_sound_command,
	.cs_latch,
	.cs_eeprom_unlock,
	.cs_eeprom,
	.cs_watchdog,
	.cs_palette,
	.cs_vad_control,
	.cs_workram,
	.cs_playfield,
	.cs_motion,
	.cs_eof,
	.cs_slip
);

wire cs_ram_7d = (cpu_even_address >= 24'h7d0000)
	              && (cpu_even_address <= 24'h7dbfff);
wire cs_ram_7f = (cpu_even_address >= 24'h7f8000)
	              && (cpu_even_address <= 24'h7fbfff);

wire mapped_cycle = cs_program
	               || cs_p1_buttons
	               || cs_p2_buttons
	               || cs_status
	               || cs_joysticks
	               || cs_sound_response
	               || cs_sound_command
	               || cs_latch
	               || cs_eeprom_unlock
	               || cs_eeprom
	               || cs_watchdog
	               || cs_palette
	               || cs_vad_control
	               || cs_ram_7d
	               || cs_ram_7f;

// 0x7d0000-0x7dbfff contains work, playfield, object, EOF, and SLIP RAM.
// Keeping it unified matches the physical contiguous window and leaves a
// straightforward path to add a second video-side port.
logic  [7:0] eeprom [0:2047];

logic [15:0] latch_data;
logic        eeprom_unlocked;
logic        main_sound_write;
logic        main_sound_read;
logic  [7:0] main_sound_read_data;

mm2_sound_comm sound_comm
(
	.clk,
	.reset,
	.sound_reset_n,
	.main_write(main_sound_write),
	.main_write_data(cpu_data_out[7:0]),
	.main_read(main_sound_read),
	.main_read_data(main_sound_read_data),
	.sound_read(sound_command_read),
	.sound_read_data(sound_command),
	.sound_write(sound_response_write),
	.sound_write_data(sound_response),
	.main_to_sound_ready(sound_command_ready),
	.sound_to_main_ready(sound_response_ready),
	.sound_nmi_n,
	.main_irq6(sound_irq6)
);

wire [15:0] ram_7d_q;
wire [15:0] ram_7f_q;
wire [15:0] palette_q;
wire [15:0] unused_motion_shadow_q;
wire [15:0] unused_ram_7f_video_q;
wire local_write_cycle = !cpu_as_n
	                     && cpu_iack_n
	                     && !cpu_rw;
wire [1:0] cpu_byte_enable = {~cpu_uds_n, ~cpu_lds_n};
wire [15:0] palette_write_data = cpu_even_address[1]
	? {8'd0, cpu_data_out[15:8]}
	: {cpu_data_out[15:8], 8'd0};
wire [1:0] palette_byte_enable = cpu_even_address[1]
	? 2'b01 : 2'b10;

mm2_m68k_ram #(.ADDR_WIDTH(15)) local_ram_7d
(
	.clk(clk),
	.address(cpu_even_address[15:1]),
	.data(cpu_data_out),
	.byte_enable(cpu_byte_enable),
	.write(local_write_cycle && cs_ram_7d),
	.q(ram_7d_q),
	.video_address({3'b100, playfield_tile_address}),
	.video_q(playfield_tile_data)
);

mm2_m68k_ram #(.ADDR_WIDTH(13)) local_ram_7f
(
	.clk(clk),
	.address(cpu_even_address[13:1]),
	.data(cpu_data_out),
	.byte_enable(cpu_byte_enable),
	.write(local_write_cycle && cs_ram_7f),
	.q(ram_7f_q),
	.video_address(13'd0),
	.video_q(unused_ram_7f_video_q)
);

// The primary playfield already consumes the video port of the unified
// 0x7d0000 RAM. Mirror the 0x7da000-0x7dbfff motion/EOF/SLIP window into a
// second true-dual-port RAM so the two line renderers can run concurrently.
mm2_m68k_ram #(.ADDR_WIDTH(12)) motion_shadow
(
	.clk,
	.address(cpu_even_address[12:1]),
	.data(cpu_data_out),
	.byte_enable(cpu_byte_enable),
	.write(local_write_cycle && (cs_motion || cs_eof || cs_slip)),
	.q(unused_motion_shadow_q),
	.video_address(motion_ram_address),
	.video_q(motion_ram_data)
);

// Palette RAM is physically eight bits wide on the 68000 upper lane. Two
// consecutive CPU words select the high and low bytes of one IRGB1555 entry.
// A true-dual-port M10K keeps the video lookup independent of CPU writes.
mm2_m68k_ram #(.ADDR_WIDTH(8)) palette
(
	.clk,
	.address(cpu_even_address[9:2]),
	.data(palette_write_data),
	.byte_enable(palette_byte_enable),
	.write(local_write_cycle && cs_palette && !cpu_uds_n),
	.q(palette_q),
	.video_address(video_palette_address),
	.video_q(video_palette_data)
);

integer eeprom_index;
initial begin
	for (eeprom_index = 0; eeprom_index < 2048; eeprom_index = eeprom_index + 1)
		eeprom[eeprom_index] = 8'hff;
end

assign eeprom_host_q = eeprom[eeprom_host_address];

wire vad_write = local_write_cycle && cs_vad_control;
wire eof_write = local_write_cycle && cs_eof;
wire [15:0] vad_q;

mm2_vad vad
(
	.clk,
	.reset,
	.ce_pix,
	.h_count,
	.v_count,
	.cpu_write(vad_write),
	.cpu_address(cpu_even_address[5:1]),
	.cpu_data(cpu_data_out),
	.cpu_byte_enable,
	.cpu_q(vad_q),
	.eof_write,
	.eof_address(cpu_even_address[6:1]),
	.eof_data(cpu_data_out),
	.eof_byte_enable(cpu_byte_enable),
	.playfield_xscroll,
	.playfield_yscroll,
	.motion_xscroll,
	.motion_yscroll,
	.irq4(vad_irq4)
);

logic [15:0] p1_button_port;
logic [15:0] p2_button_port;
logic [15:0] status_port;
logic [15:0] joystick_port;

always_comb begin
	p1_button_port = 16'hffff;
	p2_button_port = 16'hffff;
	status_port    = 16'hffff;
	joystick_port  = 16'hffff;

	// The prototype labels each action button as that player's start button.
	// MiSTer also supplies a conventional Start input at joystick bit 10.
	p1_button_port[0] = ~(joystick_p3[4] | joystick_p3[10]);
	p1_button_port[8] = ~(joystick_p1[4] | joystick_p1[10]);
	p2_button_port[0] = 1'b1; // unconnected freeze input
	p2_button_port[8] = ~(joystick_p2[4] | joystick_p2[10]);

	// The main-board port presents both JSA ready lines as active low.
	status_port[4] = ~sound_response_ready;
	status_port[5] = ~sound_command_ready;
	status_port[6] = ~service;
	status_port[7] = ~vblank;

	joystick_port[0]  = ~joystick_p2[0];
	joystick_port[1]  = ~joystick_p2[1];
	joystick_port[2]  = ~joystick_p2[2];
	joystick_port[3]  = ~joystick_p2[3];
	joystick_port[4]  = ~joystick_p1[0];
	joystick_port[5]  = ~joystick_p1[1];
	joystick_port[6]  = ~joystick_p1[2];
	joystick_port[7]  = ~joystick_p1[3];
	joystick_port[8]  = ~joystick_p3[0];
	joystick_port[9]  = ~joystick_p3[1];
	joystick_port[10] = ~joystick_p3[2];
	joystick_port[11] = ~joystick_p3[3];
end

typedef enum logic [1:0]
{
	BUS_IDLE,
	BUS_ROM_WAIT,
	BUS_ACK
} bus_state_t;

bus_state_t bus_state;

always_ff @(posedge clk) begin
	debug_address <= cpu_bus_address;
	debug_data    <= cpu_data_out;
	debug_as      <= ~cpu_as_n;
	debug_rw      <= cpu_rw;

	if (reset) begin
		bus_state             <= BUS_IDLE;
		cpu_dtack_n           <= 1'b1;
		cpu_data_in           <= 16'hffff;
		rom_addr              <= 25'd0;
		rom_req               <= 1'b0;
		debug_address         <= 24'd0;
		debug_data            <= 16'd0;
		debug_as              <= 1'b0;
		debug_rw              <= 1'b1;
		debug_bus_cycles      <= 32'd0;
		debug_unmapped_cycles <= 16'd0;
		cpu_running           <= 1'b0;
		latch_data            <= 16'd0;
		sound_reset_n         <= 1'b0;
		main_sound_write      <= 1'b0;
		main_sound_read       <= 1'b0;
		eeprom_unlocked       <= 1'b0;
		eeprom_dirty          <= 1'b0;
	end
	else begin
		main_sound_write <= 1'b0;
		main_sound_read  <= 1'b0;

		if (eeprom_host_write) begin
			eeprom[eeprom_host_address] <= eeprom_host_data;
			eeprom_dirty <= 1'b0;
		end

		case (bus_state)
			BUS_IDLE: begin
				cpu_dtack_n <= 1'b1;

				// /AS leads /UDS and /LDS on a 68000 data cycle. Do not
				// acknowledge the request until a byte lane is valid or an
				// early sample can discard writes such as the JSA reset latch.
				if (!cpu_as_n && cpu_iack_n
					&& (!cpu_uds_n || !cpu_lds_n)) begin
					debug_bus_cycles <= debug_bus_cycles + 32'd1;

					if (!mapped_cycle)
						debug_unmapped_cycles <= debug_unmapped_cycles + 16'd1;

					if (cs_program && cpu_rw) begin
						rom_addr <= {1'b0, cpu_even_address};
						rom_req  <= ~rom_req;
						bus_state <= BUS_ROM_WAIT;
						cpu_running <= 1'b1;
					end
					else begin
						// Synchronous local reads.
						if (cs_p1_buttons)
							cpu_data_in <= p1_button_port;
						else if (cs_p2_buttons)
							cpu_data_in <= p2_button_port;
						else if (cs_status && !cpu_even_address[1])
							cpu_data_in <= status_port;
						else if (cs_status)
							cpu_data_in <= dip_switches;
						else if (cs_joysticks)
							cpu_data_in <= joystick_port;
						else if (cs_sound_response) begin
							cpu_data_in <= {8'hff, main_sound_read_data};
							if (cpu_rw && !cpu_lds_n)
								main_sound_read <= 1'b1;
						end
						else if (cs_eeprom)
							cpu_data_in <= {8'hff, eeprom[cpu_even_address[11:1]]};
						else if (cs_palette)
							cpu_data_in <= {
								cpu_even_address[1]
									? palette_q[7:0]
									: palette_q[15:8],
								8'hff};
						else if (cs_vad_control)
							cpu_data_in <= vad_q;
						else if (cs_ram_7d)
							cpu_data_in <= ram_7d_q;
						else if (cs_ram_7f)
							cpu_data_in <= ram_7f_q;
						else
							cpu_data_in <= 16'hffff;

						if (!cpu_rw) begin
							if (cs_sound_command && !cpu_lds_n)
								main_sound_write <= 1'b1;

							if (cs_latch) begin
								if (!cpu_uds_n)
									latch_data[15:8] <= cpu_data_out[15:8];
								if (!cpu_lds_n)
									latch_data[7:0] <= cpu_data_out[7:0];
								if (!cpu_lds_n)
									sound_reset_n <= cpu_data_out[4];
							end

							if (cs_eeprom_unlock)
								eeprom_unlocked <= 1'b1;

							if (cs_eeprom && !cpu_lds_n && eeprom_unlocked) begin
								eeprom[cpu_even_address[11:1]] <= cpu_data_out[7:0];
								eeprom_unlocked <= 1'b0;
								eeprom_dirty <= 1'b1;
							end

						end

						cpu_dtack_n <= 1'b0;
						bus_state   <= BUS_ACK;
					end
				end
			end

			BUS_ROM_WAIT: begin
				if (rom_ack == rom_req) begin
					cpu_data_in <= rom_dout;
					cpu_dtack_n <= 1'b0;
					bus_state   <= BUS_ACK;
				end
			end

			BUS_ACK: begin
				if (cpu_as_n) begin
					cpu_dtack_n <= 1'b1;
					bus_state   <= BUS_IDLE;
				end
			end

			default: bus_state <= BUS_IDLE;
		endcase
	end
end

endmodule
