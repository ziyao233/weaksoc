-- SPDX-License-Identifier: MPL-2.0
--[[
--	Testbench for the eno uart
--	Copyright (c) 2025 Yao Zi <ziyao@disroot.org>
--]]

local coverify		= require "coverify";
local Veno_uart		= require "Veno_uart";

local string		= require "string";
local table		= require "table";

local traceEnable;

if os.getenv("DUMP") then
	traceEnable = function(v) v:trace(true); end
else
	traceEnable = function(v) end;
end

local eno_uart = Veno_uart.new();
traceEnable(eno_uart);

local bench = coverify.Bench(eno_uart);

local function
verifyByte(bench, divider, byte)
	local timeBeforeSample = divider // 2;

	assert(byte > 0x00 and byte <= 0xff);

	byte = byte << 1;		-- start bit
	byte = byte | (1 << 9);		-- stop bit

	for i = 1, 10 do
		for j = 1, timeBeforeSample do
			assert(bench:get("tx_idle") == 0);
			bench:waitClk("posedge");
		end

		assert(bench:get("tx") == (byte & 1),
		       ("sending bit %d, expecting %d but got %d"):
		       format(i, byte & 1, bench:get("tx")));

		for j = 1, divider - timeBeforeSample do
			assert(bench:get("tx_idle") == 0);
			bench:waitClk("posedge");
		end

		byte = byte >> 1;
	end
end

local function
txTest(divider)
	return function(self)
		self:waitClk("preposedge");
		assert(self:get("tx") == 1);

		-- setup divider
		self:waitClk("preposedge");
		self:set("divider", divider);
		self:set("divider_access", 1);
		self:waitClk("posedge");
		self:set("divider_access", 0);

		-- the TX line should remain high when idle
		assert(self:get("tx") == 1);

		-- Check whether tx_idle is correct
		assert(self:get("tx_idle") == 1);

		self:waitClk("preposedge");
		self:set("tx_access", 1);
		self:set("tx_data", 114);
		self:waitClk("posedge");
		self:set("tx_access", 0);

		-- Send a byte and verify
		verifyByte(self, (divider + 1) * 8, 114);
		self:waitClk("posedge");
		assert(self:get("tx") == 1);
		assert(self:get("tx_idle") == 1);

		self:waitClk("preposedge");
		self:set("tx_access", 1);
		self:set("tx_data", 114);
		self:waitClk("posedge");
		self:set("tx_access", 0);

		verifyByte(self, (divider + 1) * 8, 114);
		self:waitClk("posedge");
		assert(self:get("tx") == 1);	-- assert TX line goes back to
						-- idle

		-- Assert new TX requests are ignored when the buffer isn't
		-- empty
		self:waitClk("preposedge");
		self:set("tx_access", 1);
		self:set("tx_data", 191);
		self:waitClk("posedge");
		self:set("tx_access", 0);

		verifyByte(self, (divider + 1) * 8, 191);

		self:pass();
	end;
end

local function
rxWriteData(bench, divider, byte)
	assert(byte >= 0x00 and byte < 0xff);

	byte = byte << 1;		-- start bit
	byte = byte | (1 << 9);		-- stop bit

	for i = 1, 10 do
		bench:waitClk("preposedge");
		bench:set("rx", byte & 1);

		for i = 1, divider do
			bench:waitClk("posedge");
		end

		byte = byte >> 1;
	end

	bench:set("rx", 1);
end

local function
rxTest(divider)
	return function(self)
		self:set("rx", 1);
		self:waitClk("preposedge");
		assert(self:get("rx_avail") == 0);

		-- the divider is set by tx_test()
		self:waitClk("posedge");

		rxWriteData(self, (divider + 1) * 8, 0x5a);
		self:waitClk("preposedge");
		assert(self:get("rx_avail") == 1);
		assert(self:get("rx_data") == 0x5a,
		       ("asserting data: expect %x but got %x\n"):
		       format(10, self:get("rx_data")));

		rxWriteData(self, (divider + 1) * 8, 0x3f);

		self:waitClk("preposedge");
		self:set("rx_access", 1);
		assert(self:get("rx_data") == 0x5a);
		self:waitClk("posedge");
		assert(self:get("rx_data") == 0x3f);
		self:waitClk("posedge");
		self:waitClk("preposedge");
		self:set("rx_access", 0);
		self:waitClk("posedge");
		assert(self:get("rx_avail") == 0);
	end;
end

bench:register(txTest(1));
bench:register(rxTest(1));
bench:run("clk", "rst", 0, 1);
