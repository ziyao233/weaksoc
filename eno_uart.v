// SPDX-License-Identifier: MPL-2.0
/*
 *	The eno UART for weaksoc
 *	Eight data bits, no parity bit, one stop bit.
 *	Copyright (c) 2025 Yao Zi <ziyao@disroot.org>
 */

/*
 *	baudrate = input clock / (divider + 1) / 8
 */

module eno_uart(input wire clk,
		input wire rst,

		input wire [31:0] divider,
		input wire divider_access,

		input wire [7:0] tx_data,
		input wire tx_access,

		output wire [7:0] rx_data,
		input wire rx_access,

		output wire tx_idle,
		output wire rx_avail,

		output wire tx,
		input wire rx);

	/* ====================== Clock generation ================== */

	reg [31:0] sample_divider;
	reg [31:0] sample_counter;

	wire counter_overflow = sample_counter == sample_divider;
	wire [31:0] next_counter = counter_overflow ?
					32'b0 : sample_counter + 1;
	wire sample_posedge =
		sample_counter == {1'b0, sample_divider[31:1]};

	always @ (posedge clk) begin
		if (~rst) begin
			sample_divider <= 32'hffffffff;
			sample_counter <= 32'h0;
		end else if (divider_access) begin
			sample_divider <= divider;
			sample_counter <= 32'h0;
		end else begin
			sample_counter <= next_counter;
		end
	end

	/* =========================== Data TX ====================== */

	reg [9:0] tx_buf;
	reg [2:0] tx_counter;

	wire [2:0] next_tx_counter = sample_posedge ?
					tx_counter + 1 : tx_counter;
	wire [9:0] next_tx_buf = (next_tx_counter == 0) & sample_posedge ?
					{ 1'b0, tx_buf[9:1] } : tx_buf;
	wire tx_buf_valid = |tx_buf;

	assign tx_idle = ~tx_buf_valid;
	assign tx = tx_buf_valid ? tx_buf[0] : 1'b1;

	always @ (posedge clk) begin
		if (~rst) begin
			tx_buf <= 10'b0;
		end else if (tx_access & ~tx_buf_valid) begin
			tx_buf <= {1'b1, tx_data, 1'b0};
			tx_counter <= 3'h0;
		end else begin
			tx_buf <= next_tx_buf;
			tx_counter <= next_tx_counter;
		end
	end

	/* ======================== DATA RX ======================= */

	reg [7:0] rx_fifo[8];
	reg [2:0] rx_read_pos;
	reg [2:0] rx_write_pos;

	assign rx_avail = rx_read_pos != rx_write_pos;

	reg [9:0] rx_buf;
	reg [3:0] rx_bit_counter;
	reg [2:0] rx_sample_counter;

	wire rx_do_sample = sample_posedge & (rx_sample_counter == 3'd3);
	wire [3:0] next_rx_bit_counter = rx_bit_counter + 1;
	wire rx_ongoing = rx_bit_counter < 4'd10;
	wire rx_last_bit = next_rx_bit_counter == 4'd10;

	always @ (posedge clk) begin
		if (~rst) begin
			rx_bit_counter		<= 4'd10;
			rx_sample_counter	<= 3'b0;
		end else if (~rx_ongoing & ~rx) begin
			rx_bit_counter		<= 4'd0;
			rx_sample_counter	<= 3'b0;
		end else if (rx_do_sample & rx_ongoing) begin
			rx_bit_counter		<= next_rx_bit_counter;
			rx_sample_counter	<= rx_sample_counter + 1;

			rx_buf <= {rx, rx_buf[9:1]};
		end else if (sample_posedge & rx_ongoing) begin
			rx_sample_counter	<= rx_sample_counter + 1;
		end
	end

	assign rx_data = rx_fifo[rx_read_pos];
	always @ (posedge clk) begin
		if (~rst) begin
			rx_write_pos	<= 3'h0;
		end else if (sample_posedge & rx_last_bit & rx_do_sample) begin
			rx_write_pos		<= rx_write_pos + 1;
			rx_fifo[rx_write_pos]	<= rx_buf[9:2];
		end

		if (~rst) begin
			rx_read_pos	<= 3'h0;
		end else if (rx_access & rx_avail) begin
			rx_read_pos	<= rx_read_pos + 1;
		end
	end

`ifdef DUMP
	initial begin
		$dumpfile("dump.vcd");
		$dumpvars();
	end
`endif
endmodule
