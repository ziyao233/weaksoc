// SPDX-License-Identifier: MPL-2.0
/*
 *	Peripherals to run weakcore on a FPGA.
 *	Copyright (c) 2025 Yao Zi <ziyao@disroot.org>
 */

module weaksoc(input wire clk,
	       output reg led,
	       output wire pin_tx, input wire pin_rx);
	/* ================ Reset generation =================== */
	reg [3:0] rstcount = 4'b0;

	always @ (posedge clk) begin
		rstcount <= rstcount[3] ? rstcount : rstcount + 1;
	end

	wire rst = rstcount[3];

	/* ======================== Core ======================= */

	wire [31:0] bus_from_cpu;
	wire [31:0] bus_to_cpu;
	wire [31:0] bus_addr;
	wire bus_req, bus_ack, bus_wr;
	wire [3:0] bus_wr_mask;
	weakcore weakcore(
		.clk		(clk),
		.rst		(rst),
		.bus_in		(bus_to_cpu),
		.bus_out	(bus_from_cpu),
		.bus_addr	(bus_addr),
		.bus_req	(bus_req),
		.bus_ack	(bus_ack),
		.bus_wr		(bus_wr),
		.bus_wr_mask	(bus_wr_mask));

	/* =================== Peripheral Selection ============
	 *
	 *	0000 0000 - 0x0000 1000:	BROM
	 *	8000 0000 - 0x8000 0000:	LED
	 *	9000 0000 - 0x9000 000f:	UART
	 */
	wire access_brom	= bus_req & (bus_addr < 32'h00001000);
	wire access_led		= bus_req & (bus_addr == 32'h80000000);
	wire access_uart	= bus_req &
					(bus_addr >= 32'h90000000) &
					(bus_addr < 32'h90000010);

	/* =========================== BROM ======================= */

	reg [31:0] brom [0:255];
	wire [31:0] brom_data = brom[bus_addr[9:2]];

	initial $readmemh("firmware/brom.hex", brom);

	/* ========================== LED ========================= */

	always @ (posedge clk) begin
		if (access_led & bus_wr & bus_wr_mask[0]) begin
			led <= bus_from_cpu[0];
		end
	end

	/* ========================= UART ========================= */

	/*
	 *	9000 0000:	UART TX		(write)
	 *	9000 0004:	UART RX		(read)
	 *	9000 0008:	UART Divider	(write)
	 *	9000 000c:	UART Status	(read)
	 *		BIT(0):		tx_idle
	 *		BIT(1):		rx_avail
	 */

	wire [3:0] uart_offset = bus_addr[3:0];
	wire is_uart_tx		= access_uart & (uart_offset == 4'h0);
	wire is_uart_rx 	= access_uart & (uart_offset == 4'h4);
	wire is_uart_div 	= access_uart & (uart_offset == 4'h8);
	wire is_uart_status	= access_uart & (uart_offset == 4'hc);

	wire [31:0] uart_rx;
	wire [31:0] uart_status;
	wire [31:0] uart_data	= ({32{is_uart_rx}} & uart_rx) |
				  ({32{is_uart_status}} & uart_status);

	assign uart_rx[31:8] = 24'b0;
	assign uart_status [31:2] = 30'b0;

	eno_uart eno_uart(
		.clk		(clk),
		.rst		(rst),
		.divider	(bus_from_cpu),
		.divider_access	(is_uart_div),
		.tx_data	(bus_from_cpu[7:0]),
		.tx_access	(is_uart_tx),
		.rx_data	(uart_rx[7:0]),
		.rx_access	(is_uart_rx),
		.tx_idle	(uart_status[0]),
		.rx_avail	(uart_status[1]),
		.tx		(pin_tx),
		.rx		(pin_rx));

	/* ======================= Bus Read Response =============== */

	assign bus_ack = 1'b1;
	assign bus_to_cpu = ({32{access_brom}} & brom_data) |
			    ({32{access_uart}} & uart_data);
endmodule
