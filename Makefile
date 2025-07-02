WEAKCORE	?=

SRCS		= weaksoc.v $(WEAKCORE) eno_uart.v

weaksoc.bit: weaksoc.config
	ecppack --svf weaksoc.svf weaksoc.config weaksoc.bit

weaksoc.config: weaksoc.json weaksoc.lpf
	nextpnr-ecp5 --25k --package CABGA381 --speed 6 --json weaksoc.json \
		--textcfg weaksoc.config --lpf weaksoc.lpf --freq 65

weaksoc.json: $(SRCS)
	yosys -p "synth_ecp5 -top weaksoc -json weaksoc.json" $(SRCS)

upload: weaksoc.bit
	openFPGALoader --cable cmsisdap weaksoc.bit

clean:
	rm -f weaksoc.json weaksoc.config weaksoc.svf weaksoc.bit
