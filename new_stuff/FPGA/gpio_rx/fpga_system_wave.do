# fpga_system_wave.do

# Clear existing waves
delete wave *

# ============================================================
# GPIO Bus (the "physical wires" between the two FPGAs)
# ============================================================
add wave -divider "=== GPIO: TX -> RX ==="
add wave -radix hex          /fpga_system_tb/gpio_flit_w
add wave -radix binary       /fpga_system_tb/gpio_flit_v_w
add wave -radix binary       /fpga_system_tb/gpio_flit_ready_w

add wave -divider "=== GPIO: RX -> TX ==="
add wave -radix hex          /fpga_system_tb/gpio_link_data_w
add wave -radix binary       /fpga_system_tb/gpio_link_v_w
add wave -radix binary       /fpga_system_tb/gpio_link_yumi_w

# ============================================================
# TX FPGA internals
# ============================================================
add wave -divider "=== TX: Clocks & Reset ==="
add wave -radix binary       /fpga_system_tb/tx/clk_i
add wave -radix binary       /fpga_system_tb/tx/reset_i

add wave -divider "=== TX: Send Trace Replay ==="
add wave -radix hex          /fpga_system_tb/tx/tr_data_lo
add wave -radix binary       /fpga_system_tb/tx/tr_v_lo
add wave -radix binary       /fpga_system_tb/tx/tr_yumi_li
add wave -radix unsigned     /fpga_system_tb/tx/rom_addr_send
add wave -radix binary       /fpga_system_tb/tx/done_send

add wave -divider "=== TX: Recv Trace Replay ==="
add wave -radix hex          /fpga_system_tb/tx/link_data_r
add wave -radix binary       /fpga_system_tb/tx/link_v_r
add wave -radix binary       /fpga_system_tb/tx/tr_v_li
add wave -radix binary       /fpga_system_tb/tx/tr_ready_lo
add wave -radix unsigned     /fpga_system_tb/tx/rom_addr_recv
add wave -radix binary       /fpga_system_tb/tx/done_recv

add wave -divider "=== TX: Done ==="
add wave -radix binary       /fpga_system_tb/tx/done_o

# ============================================================
# RX FPGA internals
# ============================================================
add wave -divider "=== RX: Clocks & Reset ==="
add wave -radix binary       /fpga_system_tb/rx/clk_i
add wave -radix binary       /fpga_system_tb/rx/reset_i

add wave -divider "=== RX: GPIO Input Registers ==="
add wave -radix hex          /fpga_system_tb/rx/flit_r
add wave -radix binary       /fpga_system_tb/rx/flit_v_r
add wave -radix binary       /fpga_system_tb/rx/link_yumi_r

add wave -divider "=== RX: top_chip Input ==="
add wave -radix hex          /fpga_system_tb/rx/u_top/in_flit
add wave -radix binary       /fpga_system_tb/rx/u_top/in_flit_v
add wave -radix binary       /fpga_system_tb/rx/u_top/in_flit_ready

add wave -divider "=== RX: top_chip Output ==="
add wave -radix hex          /fpga_system_tb/rx/u_top/link_out_data_o
add wave -radix binary       /fpga_system_tb/rx/u_top/link_out_v_o
add wave -radix binary       /fpga_system_tb/rx/u_top/link_out_yumi_i

# ============================================================
# Wave display settings
# ============================================================
WaveRestoreZoom {0 ps} {5000 ns}
configure wave -namecolwidth  200
configure wave -valuecolwidth 100
configure wave -justifyvalue  left
configure wave -signalnamewidth 1
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2