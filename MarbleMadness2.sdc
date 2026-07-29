derive_pll_clocks
derive_clock_uncertainty

# Marble Madness II core-specific constraints

# SDRAM read data is a bundled-data CDC. mm2_sdram updates mem_dout together
# with its toggle acknowledge, and mm2_memory_arbiter passes that acknowledge
# through two clk_sys registers before capturing any client result. The data
# therefore remains stable for multiple clk_sys cycles; it is not required to
# meet the clocks' shortest 114-to-57 MHz phase relationship.
set_false_path \
	-from [get_keepers {*mm2_sdram:sdram|mem_dout[*]}] \
	-to [get_keepers {*mm2_memory_arbiter:memory_arbiter|*_dout[*]}]
