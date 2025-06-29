// SPDX-License-Identifier: MPL-2.0
/*
 *	Peripherals to run weakcore on a FPGA.
 *	Copyright (c) 2025 Yao Zi <ziyao@disroot.org>
 */

module weaksoc(input wire clk, output reg led);
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

	/* =================== Peripheral Selection ============ */

	wire access_brom	= bus_req & (bus_addr < 32'h00001000);
	wire access_led		= bus_req & (bus_addr == 32'h80000000);

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

	/* ======================= Bus Read Response =============== */

	assign bus_ack = 1'b1;
	assign bus_to_cpu = {32{access_brom}} & brom_data;
endmodule
