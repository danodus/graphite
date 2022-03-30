YOSYS := yosys
ECPPACK := ecppack
NEXTPNR := nextpnr-ecp5
FUJPROG := fujprog

DEVICE := 85k
PACKAGE := CABGA381

PIN_DEF := ulx3s.lpf
SRC := ../reciprocal.sv \
		../graphite.sv \
		display_timings_480p.sv \
		uart.sv \
		ram.sv \
		hdmi_encoder.v \
		generated_pll.v \
		sdram_ctrl.v \
		sdram_test.sv \
		top.sv

all: top.bin

clean:
	rm -f *.hex *.asc *.json *.bin *.log

top.json: $(SRC)
	$(YOSYS) -ql top.log -p 'synth_ecp5 -top top -json top.json' $(SRC)

top.asc: top.json $(PIN_DEF)
	$(NEXTPNR) -l top_nextpnr.log --$(DEVICE) --package $(PACKAGE) --json top.json --lpf $(PIN_DEF) --textcfg top.asc --randomize-seed

top.bin: top.asc
	$(ECPPACK) --compress --input top.asc --bit top.bin

prog: top.bin
	$(FUJPROG) top.bin

.PHONY: all prog
