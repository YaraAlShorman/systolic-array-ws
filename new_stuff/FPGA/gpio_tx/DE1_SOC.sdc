# DE1_SOC.sdc

# 50MHz clock on DE1-SoC (period = 20ns)
create_clock -name {CLOCK_50} -period 20.000 -waveform {0.000 10.000} [get_ports {CLOCK_50}]

# Derive any PLL-generated clocks (none in your design but good practice)
derive_pll_clocks

# Add clock uncertainty for setup/hold margin
derive_clock_uncertainty

# Constrain GPIO input/output delays relative to CLOCK_50
# Half period is standard conservative estimate
#set_input_delay  -clock {CLOCK_50} -max 10.0 [get_ports {GPIO_0[*]}]
#set_input_delay  -clock {CLOCK_50} -max 10.0 [get_ports {GPIO_1[*]}]
#set_output_delay -clock {CLOCK_50} -max 10.0 [get_ports {GPIO_0[*]}]
#set_output_delay -clock {CLOCK_50} -max 10.0 [get_ports {GPIO_1[*]}]



# GPIO — cross physical cables, not analyzable
set_false_path -from [get_ports {GPIO_0[*]}]
set_false_path -from [get_ports {GPIO_1[*]}]
set_false_path -to   [get_ports {GPIO_0[*]}]
set_false_path -to   [get_ports {GPIO_1[*]}]

# LEDR — asynchronous output, no timing requirement
set_false_path -to [get_ports {LEDR[*]}]

# KEY — asynchronous input (reset button)
set_false_path -from [get_ports {KEY[*]}]