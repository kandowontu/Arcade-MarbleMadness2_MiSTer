// Atari JSA III sound board used by Marble Madness II.
//
// Clock ratios, address decode, banking, command polarity, and mixer controls
// follow MAME's atarijsa implementation. The 6502 program ROM is mirrored
// into M10K RAM during the MiSTer ROM download; OKI samples remain in SDRAM.

module mm2_jsa_iii
(
	input  logic        clk,
	input  logic        reset,
	input  logic        enable,
	input  logic        service,
	input  logic        coin1,
	input  logic        coin2,
	input  logic        sound_reset_n,

	input  logic  [7:0] command_data,
	input  logic        command_ready,
	output logic        command_read,
	input  logic        command_nmi_n,
	input  logic        response_ready,
	output logic  [7:0] response_data,
	output logic        response_write,

	input  logic        rom_wr,
	input  logic [15:0] rom_addr,
	input  logic  [7:0] rom_data,

	output logic [24:0] sample_addr,
	output logic        sample_req,
	input  logic [15:0] sample_dout,
	input  logic        sample_ack,

	output logic signed [15:0] audio
);

logic [7:0] clock_divider;
logic [5:0] oki_divider;
wire ce_ym     = (clock_divider[3:0] == 4'd0);
wire ce_ym_p1  = (clock_divider[4:0] == 5'd0);
wire ce_6502   = (clock_divider[4:0] == 5'd0);
wire ce_oki    = (oki_divider == 6'd0);
wire board_reset = reset || !enable || !sound_reset_n;

always_ff @(posedge clk) begin
	if (board_reset)
		clock_divider <= 8'd0;
	else
		clock_divider <= clock_divider + 8'd1;

	if (board_reset)
		oki_divider <= 6'd0;
	else if (oki_divider == 6'd47)
		oki_divider <= 6'd0;
	else
		oki_divider <= oki_divider + 6'd1;
end

wire [23:0] cpu_address_24;
wire [15:0] cpu_address = cpu_address_24[15:0];
wire [7:0] cpu_data_out;
logic [7:0] cpu_data_in;
wire cpu_rw;
wire cpu_sync;
wire cpu_write_strobe = ce_6502 && !cpu_rw;
wire cpu_read_strobe  = ce_6502 && cpu_rw;

T65 sound_cpu
(
	.Mode(2'b00),
	.BCD_en(1'b1),
	.Res_n(~board_reset),
	.Enable(ce_6502),
	.Clk(clk),
	.Rdy(1'b1),
	.Abort_n(1'b1),
	.IRQ_n(~(timed_irq || !ym_irq_n)),
	.NMI_n(command_nmi_n),
	.SO_n(1'b1),
	.R_W_n(cpu_rw),
	.Sync(cpu_sync),
	.EF(),
	.MF(),
	.XF(),
	.ML_n(),
	.VP_n(),
	.VDA(),
	.VPA(),
	.A(cpu_address_24),
	.DI(cpu_data_in),
	.DO(cpu_data_out),
	.Regs(),
	.DEBUG(),
	.NMI_ack()
);

logic [7:0] cpu_ram_q;
logic [7:0] audio_rom_q;
logic [15:0] audio_rom_address;
logic [1:0] cpu_bank;

always_comb begin
	if ((cpu_address >= 16'h3000) && (cpu_address < 16'h4000))
		audio_rom_address = {cpu_bank, cpu_address[11:0]};
	else
		audio_rom_address = cpu_address;
end

mm2_byte_ram #(.ADDR_WIDTH(16)) audio_program_rom
(
	.clk,
	.address(rom_wr ? rom_addr : audio_rom_address),
	.data(rom_data),
	.write(rom_wr),
	.q(audio_rom_q)
);

mm2_byte_ram #(.ADDR_WIDTH(13)) audio_work_ram
(
	.clk,
	.address(cpu_address[12:0]),
	.data(cpu_data_out),
	.write(cpu_write_strobe && (cpu_address < 16'h2000)),
	.q(cpu_ram_q)
);

wire cs_ym = (cpu_address >= 16'h2000) && (cpu_address <= 16'h27ff);
// JSA III decodes A11:A9 and mirrors the register selects through A10 and
// A8:A3. Reads occupy x8xx/x9xx while writes occupy xAxx/xBxx.
wire cs_jsa_io = (cpu_address >= 16'h2800) && (cpu_address <= 16'h2fff);
wire cs_io_read = cs_jsa_io && !cpu_address[9];
wire cs_io_write = cs_jsa_io && cpu_address[9];
wire [2:0] io_selector = cpu_address[2:0];

wire [7:0] ym_dout;
wire ym_irq_n;
wire ym_ct1;
wire ym_ct2;
wire ym_sample;
wire signed [15:0] ym_left;
wire signed [15:0] ym_right;

jt51 ym2151
(
	.rst(board_reset || !ym_reset_n),
	.clk,
	.cen(ce_ym),
	.cen_p1(ce_ym_p1),
	.cs_n(!(ce_6502 && cs_ym)),
	.wr_n(cpu_rw),
	.a0(cpu_address[0]),
	.din(cpu_data_out),
	.dout(ym_dout),
	.ct1(ym_ct1),
	.ct2(ym_ct2),
	.irq_n(ym_irq_n),
	.sample(ym_sample),
	.left(ym_left),
	.right(ym_right),
	.xleft(),
	.xright()
);

wire [7:0] oki_dout;
wire [17:0] oki_rom_addr;
logic [7:0] oki_rom_data;
logic oki_rom_ok;
wire signed [13:0] oki_sound;
wire oki_sample;
logic oki_write_n;
logic [7:0] oki_write_data;
logic oki_reset_n;
logic oki_pin7;

jt6295 #(.INTERPOL(0)) oki6295
(
	.rst(board_reset || !oki_reset_n),
	.clk,
	.cen(ce_oki),
	.ss(oki_pin7),
	.wrn(oki_write_n),
	.din(oki_write_data),
	.dout(oki_dout),
	.rom_addr(oki_rom_addr),
	.rom_data(oki_rom_data),
	.rom_ok(oki_rom_ok),
	.sound(oki_sound),
	.sample(oki_sample)
);

logic [7:0] overall_volume;
logic [2:0] ym_volume;
logic       oki_full_volume;
logic [1:0] oki_bank;
logic       ym_reset_n;
logic       timed_irq;
logic [17:0] timed_irq_counter;
logic [7:0] jsa_input_data;

mm2_jsa_inputs jsa_inputs
(
	.service,
	.coin1,
	.coin2,
	.command_ready,
	.response_ready,
	.data(jsa_input_data)
);

always_comb begin
	cpu_data_in = 8'hff;
	if (cpu_address < 16'h2000)
		cpu_data_in = cpu_ram_q;
	else if (cs_ym)
		cpu_data_in = ym_dout;
	else if (cs_io_read) begin
		case (io_selector)
			3'd0, 3'd1: cpu_data_in = oki_dout;
			3'd2:       cpu_data_in = command_data;
			3'd4:       cpu_data_in = jsa_input_data;
			3'd6:       cpu_data_in = 8'd0;
			default:    cpu_data_in = 8'hff;
		endcase
	end
	else if (cpu_address >= 16'h3000)
		cpu_data_in = audio_rom_q;
end

always_ff @(posedge clk) begin
	command_read  <= 1'b0;
	response_write <= 1'b0;
	oki_write_n   <= 1'b1;

	if (board_reset) begin
		cpu_bank          <= 2'd0;
		overall_volume    <= 8'h7f;
		ym_volume         <= 3'd7;
		oki_full_volume   <= 1'b1;
		oki_bank          <= 2'd0;
		ym_reset_n        <= 1'b0;
		oki_reset_n       <= 1'b0;
		oki_pin7          <= 1'b1;
		oki_write_data    <= 8'd0;
		response_data     <= 8'd0;
		timed_irq         <= 1'b0;
		timed_irq_counter <= 18'd0;
	end
	else begin
		if (timed_irq_counter == 18'd229375) begin
			timed_irq_counter <= 18'd0;
			timed_irq <= 1'b1;
		end
		else
			timed_irq_counter <= timed_irq_counter + 18'd1;

		if (cpu_read_strobe && cs_io_read) begin
			if (io_selector == 3'd2)
				command_read <= 1'b1;
			if (io_selector == 3'd6)
				timed_irq <= 1'b0;
		end

		if (cpu_write_strobe) begin
			if (cs_io_write) begin
				case (io_selector)
					3'd0, 3'd1: begin
						oki_write_data <= cpu_data_out;
						oki_write_n <= 1'b0;
					end
					3'd2: begin
						response_data <= cpu_data_out;
						response_write <= 1'b1;
					end
					3'd4: begin
						cpu_bank    <= cpu_data_out[7:6];
						oki_pin7    <= cpu_data_out[3];
						oki_reset_n <= cpu_data_out[2];
						oki_bank[0] <= cpu_data_out[1];
						ym_reset_n  <= cpu_data_out[0];
					end
					3'd6: begin
						oki_bank[1]    <= cpu_data_out[4];
						ym_volume      <= cpu_data_out[3:1];
						oki_full_volume <= cpu_data_out[0];
						timed_irq <= 1'b0;
					end
				endcase
			end
			else if (cs_io_read && (io_selector < 3'd2))
				overall_volume <= {1'b0, cpu_data_out[6:0]};
		end
	end
end

logic [17:0] cached_oki_address;
logic        sample_pending;
logic        sample_byte_select;
logic [24:0] translated_sample_address;
logic        translated_sample_valid;

always_comb begin
	translated_sample_valid = 1'b1;
	if (oki_rom_addr < 18'h20000) begin
		case (oki_bank)
			2'd0, 2'd1:
				translated_sample_address = 25'h0210000
				                          + {7'd0, oki_rom_addr};
			default: begin
				translated_sample_address = 25'd0;
				translated_sample_valid = 1'b0;
			end
		endcase
	end
	else begin
		translated_sample_address = 25'h0230000
		                          + {8'd0, oki_rom_addr[16:0]};
	end
end

always_ff @(posedge clk) begin
	if (board_reset) begin
		cached_oki_address <= 18'h3ffff;
		sample_addr        <= 25'd0;
		sample_req         <= 1'b0;
		sample_pending     <= 1'b0;
		sample_byte_select <= 1'b0;
		oki_rom_data       <= 8'hff;
		oki_rom_ok         <= 1'b0;
	end
	else begin
		oki_rom_ok <= (cached_oki_address == oki_rom_addr)
		           && !sample_pending;

		if ((cached_oki_address != oki_rom_addr) && !sample_pending) begin
			if (!translated_sample_valid) begin
				cached_oki_address <= oki_rom_addr;
				oki_rom_data <= 8'hff;
				oki_rom_ok <= 1'b1;
			end
			else begin
				sample_addr <= {translated_sample_address[24:1], 1'b0};
				sample_byte_select <= translated_sample_address[0];
				sample_req <= ~sample_req;
				sample_pending <= 1'b1;
				oki_rom_ok <= 1'b0;
			end
		end

		if (sample_pending && (sample_ack == sample_req)) begin
			oki_rom_data <= sample_byte_select
			              ? sample_dout[7:0] : sample_dout[15:8];
			cached_oki_address <= oki_rom_addr;
			sample_pending <= 1'b0;
			oki_rom_ok <= 1'b1;
		end
	end
end

logic signed [16:0] ym_sum;
logic signed [31:0] ym_scaled;
logic signed [31:0] oki_scaled;
logic signed [31:0] mixed_audio;

always_comb begin
	ym_sum = $signed(ym_left) + $signed(ym_right);
	ym_scaled = ($signed(ym_sum) * $signed({1'b0, ym_volume})
	            * $signed({1'b0, overall_volume})) >>> 10;
	oki_scaled = ($signed(oki_sound) * $signed({1'b0, overall_volume}))
	             >>> (oki_full_volume ? 5 : 6);
	if (!ym_ct1)
		oki_scaled = 32'sd0;
	mixed_audio = ym_scaled + oki_scaled;

	if (mixed_audio > 32'sd32767)
		audio = 16'sh7fff;
	else if (mixed_audio < -32'sd32768)
		audio = 16'sh8000;
	else
		audio = mixed_audio[15:0];
end

endmodule
