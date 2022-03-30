#!/bin/sh

# TMDS clock: 25 * 5 = 125
# System clock: 25
# SDRAM clock: ~52

ecppll -i 25 -o 125 --clkout2 25 --clkout3 50 -f generated_pll.v

