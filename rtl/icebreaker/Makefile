YOSYS := yosys
ICEPACK := icepack
NEXTPNR := nextpnr-ice40
ICEPROG := iceprog

DEVICE := up5k
PACKAGE := sg48

PIN_DEF := icebreaker.pcf
SRC :=  ../draw_line.sv \
		../reciprocal.sv \
		../graphite.sv \
		ram.sv \
		clock_gen_480p.sv \
		display_timings_480p.sv \
		uart.sv \
		top.sv

all: top.bin

clean:
	rm -f *.hex *.asc *.json *.bin *.log

top.json: $(SRC)
	$(YOSYS) -ql top.log -p 'synth_ice40 -dsp -top top -json top.json' $(SRC)

top.asc: top.json $(PIN_DEF)
	$(NEXTPNR) -l top_nextpnr.log --$(DEVICE) --package $(PACKAGE) --json top.json --pcf $(PIN_DEF) --asc top.asc --randomize-seed

top.bin: top.asc
	$(ICEPACK) -s top.asc top.bin

prog: top.bin
	$(ICEPROG) top.bin

.PHONY: all prog
