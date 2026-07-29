// Single-port SDR SDRAM controller for the MiSTer 32 MiB module.
//
// The interface uses a toggle request/acknowledge handshake. Address, data,
// byte enables, and direction must remain stable until mem_ack equals mem_req.
//
// Copyright (C) 2026 kandowontu and contributors
// SPDX-License-Identifier: GPL-2.0-or-later

module mm2_sdram
(
	input  logic        clk,
	input  logic        reset,

	inout  wire  [15:0] SDRAM_DQ,
	output logic [12:0] SDRAM_A,
	output logic  [1:0] SDRAM_BA,
	output wire         SDRAM_CLK,
	output wire         SDRAM_CKE,
	output logic        SDRAM_DQML,
	output logic        SDRAM_DQMH,
	output wire         SDRAM_nCS,
	output wire         SDRAM_nWE,
	output wire         SDRAM_nCAS,
	output wire         SDRAM_nRAS,

	input  logic [24:0] mem_addr,
	input  logic [15:0] mem_din,
	input  logic  [1:0] mem_be,
	input  logic        mem_rnw,
	input  logic        mem_req,
	output logic [15:0] mem_dout,
	output logic        mem_ack,
	output logic        ready
);

localparam logic [2:0] CMD_LOAD_MODE = 3'b000;
localparam logic [2:0] CMD_REFRESH   = 3'b001;
localparam logic [2:0] CMD_PRECHARGE = 3'b010;
localparam logic [2:0] CMD_ACTIVE    = 3'b011;
localparam logic [2:0] CMD_WRITE     = 3'b100;
localparam logic [2:0] CMD_READ      = 3'b101;
localparam logic [2:0] CMD_NOP       = 3'b111;

// Burst length 1, sequential access, CAS 3, single-location write burst.
localparam logic [12:0] MODE_REGISTER = 13'h230;

// clk is 114.545448 MHz. This exceeds the SDRAM's 100 us power-up delay and
// issues refreshes more frequently than the required 8192 per 64 ms.
localparam logic [15:0] INIT_DELAY_CYCLES = 16'd24000;
localparam logic [15:0] REFRESH_CYCLES    = 16'd800;

typedef enum logic [3:0]
{
	ST_INIT_WAIT,
	ST_INIT_TRP,
	ST_INIT_RFC1,
	ST_INIT_RFC2,
	ST_INIT_MRD,
	ST_IDLE,
	ST_ACTIVATE,
	ST_READ_WAIT,
	ST_WRITE_WAIT,
	ST_REFRESH_WAIT
} state_t;

state_t state;
logic [15:0] delay_count;
logic [15:0] refresh_count;
logic  [2:0] command;
logic [24:0] latched_addr;
logic [15:0] latched_din;
logic  [1:0] latched_be;
logic        latched_rnw;
logic        latched_req;
logic [15:0] dq_out;
logic        dq_oe = 1'b0;

assign SDRAM_DQ = dq_oe ? dq_out : 16'hzzzz;
assign SDRAM_CKE = 1'b1;
assign SDRAM_nCS = 1'b0;
assign {SDRAM_nRAS, SDRAM_nCAS, SDRAM_nWE} = command;

// The SDRAM clock is phase-aligned with the registered command outputs.
// A DDR output primitive gives a clean forwarded clock on hardware while
// retaining a simple clock assignment for RTL simulation.
`ifdef SYNTHESIS
altddio_out
#(
	.extend_oe_disable("OFF"),
	.intended_device_family("Cyclone V"),
	.invert_output("OFF"),
	.lpm_hint("UNUSED"),
	.lpm_type("altddio_out"),
	.oe_reg("UNREGISTERED"),
	.power_up_high("OFF"),
	.width(1)
)
sdram_clock_out
(
	.datain_h(1'b0),
	.datain_l(1'b1),
	.outclock(clk),
	.dataout(SDRAM_CLK),
	.aclr(1'b0),
	.aset(1'b0),
	.oe(1'b1),
	.outclocken(1'b1),
	.sclr(1'b0),
	.sset(1'b0)
);
`else
// The synthesized ALTDDIO instance forwards an inverted clock: commands and
// DQ change on clk's rising edge, then the SDRAM samples them half a cycle
// later on SDRAM_CLK's rising edge.
assign SDRAM_CLK = ~clk;
`endif

// Keep the shared DQ output enable as a simple, always-loaded register. This
// allows Quartus to duplicate it into the sixteen I/O cells instead of
// implementing a synchronous-clear/load combination in core logic.
always_ff @(posedge clk) begin
	dq_oe <= !reset
	      && (state == ST_ACTIVATE)
	      && (delay_count == 16'd0)
	      && !latched_rnw;
end

always_ff @(posedge clk) begin
	command    <= CMD_NOP;
	SDRAM_DQML <= 1'b1;
	SDRAM_DQMH <= 1'b1;

	if (reset) begin
		state         <= ST_INIT_WAIT;
		delay_count   <= INIT_DELAY_CYCLES;
		refresh_count <= 16'd0;
		SDRAM_A       <= 13'd0;
		SDRAM_BA      <= 2'd0;
		mem_dout      <= 16'd0;
		mem_ack       <= 1'b0;
		ready         <= 1'b0;
		latched_addr  <= 25'd0;
		latched_din   <= 16'd0;
		latched_be    <= 2'd0;
		latched_rnw   <= 1'b1;
		latched_req   <= 1'b0;
	end
	else begin
		if (ready && (refresh_count != 16'hffff))
			refresh_count <= refresh_count + 16'd1;

		case (state)
			ST_INIT_WAIT: begin
				if (delay_count != 16'd0) begin
					delay_count <= delay_count - 16'd1;
				end
				else begin
					SDRAM_A       <= 13'd0;
					SDRAM_A[10]   <= 1'b1;
					SDRAM_BA      <= 2'd0;
					command        <= CMD_PRECHARGE;
					delay_count    <= 16'd3;
					state          <= ST_INIT_TRP;
				end
			end

			ST_INIT_TRP: begin
				if (delay_count != 16'd0) begin
					delay_count <= delay_count - 16'd1;
				end
				else begin
					command      <= CMD_REFRESH;
					delay_count  <= 16'd10;
					state        <= ST_INIT_RFC1;
				end
			end

			ST_INIT_RFC1: begin
				if (delay_count != 16'd0) begin
					delay_count <= delay_count - 16'd1;
				end
				else begin
					command      <= CMD_REFRESH;
					delay_count  <= 16'd10;
					state        <= ST_INIT_RFC2;
				end
			end

			ST_INIT_RFC2: begin
				if (delay_count != 16'd0) begin
					delay_count <= delay_count - 16'd1;
				end
				else begin
					SDRAM_A      <= MODE_REGISTER;
					SDRAM_BA     <= 2'd0;
					command      <= CMD_LOAD_MODE;
					delay_count  <= 16'd3;
					state        <= ST_INIT_MRD;
				end
			end

			ST_INIT_MRD: begin
				if (delay_count != 16'd0) begin
					delay_count <= delay_count - 16'd1;
				end
				else begin
					ready         <= 1'b1;
					refresh_count <= 16'd0;
					state         <= ST_IDLE;
				end
			end

			ST_IDLE: begin
				if (refresh_count >= REFRESH_CYCLES) begin
					command       <= CMD_REFRESH;
					refresh_count <= 16'd0;
					delay_count   <= 16'd10;
					state         <= ST_REFRESH_WAIT;
				end
				else if (mem_req != mem_ack) begin
					latched_addr <= mem_addr;
					latched_din  <= mem_din;
					latched_be   <= mem_be;
					latched_rnw  <= mem_rnw;
					latched_req  <= mem_req;

					// 32 MiB linear byte address:
					// bank[1:0], row[12:0], column[8:0], byte lane.
					SDRAM_BA     <= mem_addr[24:23];
					SDRAM_A      <= mem_addr[22:10];
					command      <= CMD_ACTIVE;
					delay_count  <= 16'd3;
					state        <= ST_ACTIVATE;
				end
			end

			ST_ACTIVATE: begin
				if (delay_count != 16'd0) begin
					delay_count <= delay_count - 16'd1;
				end
				else begin
					SDRAM_BA       <= latched_addr[24:23];
					SDRAM_A        <= 13'd0;
					SDRAM_A[10]    <= 1'b1; // auto-precharge
					SDRAM_A[8:0]   <= latched_addr[9:1];
					SDRAM_DQML     <= ~latched_be[0];
					SDRAM_DQMH     <= ~latched_be[1];

					if (latched_rnw) begin
						command      <= CMD_READ;
						// CAS latency is three. Capture midway through the
						// single data cycle, three clk rising edges after the
						// SDRAM samples this command.
						delay_count  <= 16'd3;
						state        <= ST_READ_WAIT;
					end
					else begin
						command      <= CMD_WRITE;
						dq_out       <= latched_din;
						delay_count  <= 16'd5;
						state        <= ST_WRITE_WAIT;
					end
				end
			end

			ST_READ_WAIT: begin
				if (delay_count != 16'd0) begin
					delay_count <= delay_count - 16'd1;
				end
				else begin
					mem_dout <= SDRAM_DQ;
					mem_ack  <= latched_req;
					state    <= ST_IDLE;
				end
			end

			ST_WRITE_WAIT: begin
				if (delay_count != 16'd0) begin
					delay_count <= delay_count - 16'd1;
				end
				else begin
					mem_ack <= latched_req;
					state   <= ST_IDLE;
				end
			end

			ST_REFRESH_WAIT: begin
				if (delay_count != 16'd0)
					delay_count <= delay_count - 16'd1;
				else
					state <= ST_IDLE;
			end

			default: state <= ST_INIT_WAIT;
		endcase
	end
end

endmodule
