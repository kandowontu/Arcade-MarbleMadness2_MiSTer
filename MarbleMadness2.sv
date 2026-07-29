//============================================================================
//
// Marble Madness II (prototype) MiSTer core
//
// Copyright (C) 2026 kandowontu and contributors
// SPDX-License-Identifier: GPL-2.0-or-later
//
//============================================================================

module emu
(
	`include "sys/emu_ports.vh"
);

assign ADC_BUS  = 'Z;
assign USER_OUT = '1;
assign {UART_RTS, UART_TXD, UART_DTR} = 0;
assign {SD_SCK, SD_MOSI, SD_CS} = 'Z;

assign {DDRAM_CLK, DDRAM_BURSTCNT, DDRAM_ADDR, DDRAM_DIN,
        DDRAM_BE, DDRAM_RD, DDRAM_WE} = '0;

assign VGA_SL       = 0;
assign VGA_F1       = 0;
assign VGA_SCALER   = 0;
assign VGA_DISABLE  = 0;
assign HDMI_FREEZE  = 0;
assign HDMI_BLACKOUT = 0;
assign HDMI_BOB_DEINT = 0;

assign AUDIO_S   = 1;
wire signed [15:0] core_audio;
assign AUDIO_L   = core_audio;
assign AUDIO_R   = core_audio;
assign AUDIO_MIX = 0;

assign LED_DISK  = 0;
assign LED_POWER = 0;
assign BUTTONS   = 0;

assign VIDEO_ARX = 12'd4;
assign VIDEO_ARY = 12'd3;

`include "build_id.v"
localparam CONF_STR = {
	"MarbleMadness2;;",
	"-;",
	"P1,Video;",
	"P1O[2:1],Aspect ratio,Original,Full Screen,[ARC1],[ARC2];",
	"P1-;",
	"P2,Controls;",
	"P2O[3],Trackball/Mouse,On,Off;",
	"P2O[7:6],Trackball sensitivity,100%,50%,25%,200%;",
	"P2O[4],Service/Test mode,Off,On;",
	"P2-;",
	"DIP;",
	"F2,EEP,Load EEPROM;",
	"T[5],Save EEPROM;",
	"-;",
	"T[0],Reset;",
	"R[0],Reset and close OSD;",
	"v,0;",
	"V,v",`BUILD_DATE
};

wire         forced_scandoubler;
wire  [1:0]  buttons;
wire [127:0] status;
wire         ioctl_download;
wire         ioctl_upload;
wire         ioctl_rd;
wire         ioctl_wr;
wire [24:0]  ioctl_addr;
wire  [7:0]  ioctl_dout;
wire  [7:0]  ioctl_index;
wire         ioctl_wait;
wire  [7:0]  eeprom_host_q;
wire         eeprom_dirty;
wire [15:0]  joystick_0;
wire [15:0]  joystick_1;
wire [15:0]  joystick_2;
wire [24:0]  ps2_mouse;

hps_io #(.CONF_STR(CONF_STR)) hps_io
(
	.clk_sys(clk_sys),
	.HPS_BUS(HPS_BUS),
	.EXT_BUS(),
	.gamma_bus(),
	.forced_scandoubler(forced_scandoubler),
	.buttons(buttons),
	.status(status),
	.ioctl_download(ioctl_download),
	.ioctl_upload(ioctl_upload),
	.ioctl_upload_req(status[5]),
	.ioctl_upload_index(8'd2),
	.ioctl_rd(ioctl_rd),
	.ioctl_wr(ioctl_wr),
	.ioctl_addr(ioctl_addr),
	.ioctl_dout(ioctl_dout),
	.ioctl_din(eeprom_host_q),
	.ioctl_index(ioctl_index),
	.ioctl_wait(ioctl_wait),
	.ps2_mouse(ps2_mouse),
	.joystick_0(joystick_0),
	.joystick_1(joystick_1),
	.joystick_2(joystick_2)
);

wire clk_sys;
wire clk_sdr;
wire pll_locked;

pll pll
(
	.refclk(CLK_50M),
	.rst(1'b0),
	.outclk_0(clk_sdr),
	.outclk_1(clk_sys),
	.locked(pll_locked)
);

wire reset = RESET | status[0] | buttons[1] | ~pll_locked;

logic [15:0] dip_switches = 16'h00ff;
always_ff @(posedge clk_sys) begin
	if (ioctl_wr && (ioctl_index == 8'd254) && !ioctl_addr[24:1]) begin
		if (ioctl_addr[0])
			dip_switches[15:8] <= ioctl_dout;
		else
			dip_switches[7:0] <= ioctl_dout;
	end
end

wire [24:0] mem_addr;
wire [15:0] mem_din;
wire  [1:0] mem_be;
wire        mem_rnw;
wire        mem_req;
wire [15:0] mem_dout;
wire        mem_ack;
wire        memory_ready;
logic       memory_ready_meta;
logic       memory_ready_sys;

mm2_sdram sdram
(
	.clk(clk_sdr),
	.reset(~pll_locked),
	.SDRAM_DQ,
	.SDRAM_A,
	.SDRAM_BA,
	.SDRAM_CLK,
	.SDRAM_CKE,
	.SDRAM_DQML,
	.SDRAM_DQMH,
	.SDRAM_nCS,
	.SDRAM_nWE,
	.SDRAM_nCAS,
	.SDRAM_nRAS,
	.mem_addr,
	.mem_din,
	.mem_be,
	.mem_rnw,
	.mem_req,
	.mem_dout,
	.mem_ack,
	.ready(memory_ready)
);

// The SDRAM controller runs at 114.545 MHz while the core runs at
// 57.273 MHz. Synchronize its one-way initialized flag before it fans out
// into CPU and sound-board reset logic.
always_ff @(posedge clk_sys) begin
	if (reset) begin
		memory_ready_meta <= 1'b0;
		memory_ready_sys  <= 1'b0;
	end
	else begin
		memory_ready_meta <= memory_ready;
		memory_ready_sys  <= memory_ready_meta;
	end
end

wire       ce_pix;
wire       hblank;
wire       hsync;
wire       vblank;
wire       vsync;
wire [7:0] red;
wire [7:0] green;
wire [7:0] blue;
wire       rom_ready;
logic      vblank_d;
wire       frame_tick = vblank && !vblank_d;
wire [15:0] p1_controls;
wire        service_input = status[4] | joystick_0[9];

always_ff @(posedge clk_sys) begin
	if (reset)
		vblank_d <= 1'b0;
	else
		vblank_d <= vblank;
end

mm2_trackball_to_joystick trackball_controls
(
	.clk(clk_sys),
	.reset,
	.enable(!status[3]),
	.frame_tick,
	.sensitivity(status[7:6]),
	.ps2_mouse,
	.joystick_in(joystick_0),
	.joystick_out(p1_controls)
);

mm2_core core
(
	.clk(clk_sys),
	.reset(reset),
	.storage_reset(~pll_locked),
	.memory_ready(memory_ready_sys),
	.service(service_input),
	.dip_switches(dip_switches),
	.rom_downloading(ioctl_download && (ioctl_index == 8'd0)),
	.rom_wr(ioctl_wr && (ioctl_index == 8'd0)),
	.rom_addr(ioctl_addr),
	.rom_data(ioctl_dout),
	.rom_wait(ioctl_wait),
	.eeprom_loading(ioctl_download && (ioctl_index == 8'd2)),
	.eeprom_host_write(ioctl_wr && (ioctl_index == 8'd2)),
	.eeprom_host_address(ioctl_addr[10:0]),
	.eeprom_host_data(ioctl_dout),
	.eeprom_host_q,
	.eeprom_dirty,
	.joystick_p1(p1_controls),
	.joystick_p2(joystick_1),
	.joystick_p3(joystick_2),
	.mem_addr,
	.mem_din,
	.mem_be,
	.mem_rnw,
	.mem_req,
	.mem_dout,
	.mem_ack,
	.ce_pix(ce_pix),
	.hblank(hblank),
	.hsync(hsync),
	.vblank(vblank),
	.vsync(vsync),
	.red(red),
	.green(green),
	.blue(blue),
	.audio(core_audio),
	.rom_ready(rom_ready)
);

assign CLK_VIDEO = clk_sys;
assign CE_PIXEL  = ce_pix;
assign VGA_DE    = ~(hblank | vblank);
assign VGA_HS    = hsync;
assign VGA_VS    = vsync;
assign VGA_R     = red;
assign VGA_G     = green;
assign VGA_B     = blue;

// The LED turns on when a complete validated ROM stream is in SDRAM.
assign LED_USER = rom_ready;

endmodule
