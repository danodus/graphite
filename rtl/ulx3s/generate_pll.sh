#!/bin/sh

# TMDS clock: 25 * 5 = 125
# System clock: 25
# SDRAM clock: ~78

ecppll -i 25 -o 125 --clkout2 25 --clkout3 75 -f generated_pll.v

