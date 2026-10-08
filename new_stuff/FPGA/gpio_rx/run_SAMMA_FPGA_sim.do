# Create work library
vlib work


# Global include path for BSG headers
set BSG_MISC "./basejump_stl-uw_ee477_wi23/basejump_stl-uw_ee477_wi23/bsg_misc"


# Compile Verilog
#     All Verilog files that are part of this design should have
#     their own "vlog" line below.

# packages
vlog "./Torus-Sys-Array-main/Torus-Sys-Array-main/v/memory/scratchpad_pkg.sv"
vlog "./Torus-Sys-Array-main/Torus-Sys-Array-main/v/controller/ctrl_pkg.sv"
vlog "./Torus-Sys-Array-main/Torus-Sys-Array-main/v/memory/mem_pkg.sv"
vlog "./Torus-Sys-Array-main/Torus-Sys-Array-main/v/PE/PE_pkg.sv"

# BSG
vlog -sv +incdir+$BSG_MISC "./basejump_stl-uw_ee477_wi23/basejump_stl-uw_ee477_wi23/bsg_misc/bsg_defines.v"
vlog -sv +incdir+$BSG_MISC "./basejump_stl-uw_ee477_wi23/basejump_stl-uw_ee477_wi23/bsg_mem/bsg_mem_1r1w_synth.v"
vlog -sv +incdir+$BSG_MISC "./basejump_stl-uw_ee477_wi23/basejump_stl-uw_ee477_wi23/bsg_mem/bsg_mem_1r1w_sync.v"
vlog -sv +incdir+$BSG_MISC "./basejump_stl-uw_ee477_wi23/basejump_stl-uw_ee477_wi23/bsg_mem/bsg_mem_1r1w_sync_synth.v"
vlog -sv +incdir+$BSG_MISC "./basejump_stl-uw_ee477_wi23/basejump_stl-uw_ee477_wi23/bsg_mem/bsg_mem_1r1w.v"
vlog -sv +incdir+$BSG_MISC "./basejump_stl-uw_ee477_wi23/basejump_stl-uw_ee477_wi23/bsg_dataflow/bsg_two_fifo.v"
vlog -sv +incdir+$BSG_MISC "./basejump_stl-uw_ee477_wi23/basejump_stl-uw_ee477_wi23/bsg_dataflow/bsg_serial_in_parallel_out_full.v"
vlog -sv +incdir+$BSG_MISC "./basejump_stl-uw_ee477_wi23/basejump_stl-uw_ee477_wi23/bsg_dataflow/bsg_serial_in_parallel_out.v"
vlog -sv +incdir+$BSG_MISC "./basejump_stl-uw_ee477_wi23/basejump_stl-uw_ee477_wi23/bsg_dataflow/bsg_round_robin_1_to_n.v"
vlog -sv +incdir+$BSG_MISC "./basejump_stl-uw_ee477_wi23/basejump_stl-uw_ee477_wi23/bsg_dataflow/bsg_parallel_in_serial_out.v"
vlog -sv +incdir+$BSG_MISC "./basejump_stl-uw_ee477_wi23/basejump_stl-uw_ee477_wi23/bsg_dataflow/bsg_one_fifo.v"
vlog -sv +incdir+$BSG_MISC "./basejump_stl-uw_ee477_wi23/basejump_stl-uw_ee477_wi23/bsg_dataflow/bsg_fifo_tracker.v"
vlog -sv +incdir+$BSG_MISC "./basejump_stl-uw_ee477_wi23/basejump_stl-uw_ee477_wi23/bsg_dataflow/bsg_fifo_1r1w_small_hardened.v"
vlog -sv +incdir+$BSG_MISC "./basejump_stl-uw_ee477_wi23/basejump_stl-uw_ee477_wi23/bsg_dataflow/bsg_fifo_1r1w_small_unhardened.v"
vlog -sv +incdir+$BSG_MISC "./basejump_stl-uw_ee477_wi23/basejump_stl-uw_ee477_wi23/bsg_dataflow/bsg_fifo_1r1w_small.v"
vlog -sv +incdir+$BSG_MISC "./basejump_stl-uw_ee477_wi23/basejump_stl-uw_ee477_wi23/bsg_async/bsg_sync_sync.v"
vlog -sv +incdir+$BSG_MISC "./basejump_stl-uw_ee477_wi23/basejump_stl-uw_ee477_wi23/bsg_async/bsg_launch_sync_sync.v"
vlog -sv +incdir+$BSG_MISC "./basejump_stl-uw_ee477_wi23/basejump_stl-uw_ee477_wi23/bsg_async/bsg_async_ptr_gray.v"
vlog -sv +incdir+$BSG_MISC "./basejump_stl-uw_ee477_wi23/basejump_stl-uw_ee477_wi23/bsg_async/bsg_async_fifo.v"
vlog -sv +incdir+$BSG_MISC "./basejump_stl-uw_ee477_wi23/basejump_stl-uw_ee477_wi23/bsg_async/bsg_async_credit_counter.v"
vlog -sv +incdir+$BSG_MISC "./basejump_stl-uw_ee477_wi23/basejump_stl-uw_ee477_wi23/bsg_misc/bsg_scan.v"
vlog -sv +incdir+$BSG_MISC "./basejump_stl-uw_ee477_wi23/basejump_stl-uw_ee477_wi23/bsg_misc/bsg_gray_to_binary.v"
vlog -sv +incdir+$BSG_MISC "./basejump_stl-uw_ee477_wi23/basejump_stl-uw_ee477_wi23/bsg_misc/bsg_dff_en.v"
vlog -sv +incdir+$BSG_MISC "./basejump_stl-uw_ee477_wi23/basejump_stl-uw_ee477_wi23/bsg_misc/bsg_dff.v"
vlog -sv +incdir+$BSG_MISC "./basejump_stl-uw_ee477_wi23/basejump_stl-uw_ee477_wi23/bsg_misc/bsg_counter_clear_up.v"
vlog -sv +incdir+$BSG_MISC "./basejump_stl-uw_ee477_wi23/basejump_stl-uw_ee477_wi23/bsg_misc/bsg_circular_ptr.v"
vlog -sv +incdir+$BSG_MISC "./basejump_stl-uw_ee477_wi23/basejump_stl-uw_ee477_wi23/bsg_misc/bsg_dff_reset.v"

# BSG testbench only
vlog -sv +incdir+$BSG_MISC "./basejump_stl-uw_ee477_wi23/basejump_stl-uw_ee477_wi23/bsg_test/bsg_nonsynth_clock_gen.v"
vlog -sv +incdir+$BSG_MISC "./basejump_stl-uw_ee477_wi23/basejump_stl-uw_ee477_wi23/bsg_test/bsg_nonsynth_reset_gen.v"
vlog -sv +incdir+$BSG_MISC "./basejump_stl-uw_ee477_wi23/basejump_stl-uw_ee477_wi23/bsg_fsb/bsg_fsb_node_trace_replay.v"

# ROMs
vlog -sv +incdir+$BSG_MISC "./benchmark4_recv_trace_rom.sv"
vlog -sv +incdir+$BSG_MISC "./benchmark4_send_trace_rom.sv"

# submodules
vlog "./Torus-Sys-Array-main/Torus-Sys-Array-main/v/controller/write_ctrl.sv"
vlog "./Torus-Sys-Array-main/Torus-Sys-Array-main/v/controller/read_ctrl.sv"
vlog "./Torus-Sys-Array-main/Torus-Sys-Array-main/v/controller/mesh_driver.sv"
vlog "./Torus-Sys-Array-main/Torus-Sys-Array-main/v/controller/mem_arbiter.sv"
vlog "./Torus-Sys-Array-main/Torus-Sys-Array-main/v/controller/exec_ctrl.sv"
vlog "./Torus-Sys-Array-main/Torus-Sys-Array-main/v/controller/dispatch.sv"
vlog "./Torus-Sys-Array-main/Torus-Sys-Array-main/v/controller/ctrl_pkg.sv"
vlog "./Torus-Sys-Array-main/Torus-Sys-Array-main/v/controller/csr_router.sv"
vlog "./Torus-Sys-Array-main/Torus-Sys-Array-main/v/controller/cmd_queue.sv"
vlog "./Torus-Sys-Array-main/Torus-Sys-Array-main/v/controller/cmd_decoder.sv"
vlog "./Torus-Sys-Array-main/Torus-Sys-Array-main/v/CSR/csr.sv"
vlog "./Torus-Sys-Array-main/Torus-Sys-Array-main/v/memory/zero_gen.sv"
vlog "./Torus-Sys-Array-main/Torus-Sys-Array-main/v/memory/sp_bank.sv"
vlog "./Torus-Sys-Array-main/Torus-Sys-Array-main/v/memory/scratchpad_pkg.sv"
vlog "./Torus-Sys-Array-main/Torus-Sys-Array-main/v/memory/scratchpad.sv"
vlog "./Torus-Sys-Array-main/Torus-Sys-Array-main/v/memory/partition_mem.sv"
vlog "./Torus-Sys-Array-main/Torus-Sys-Array-main/v/memory/memory_sync.sv"
vlog "./Torus-Sys-Array-main/Torus-Sys-Array-main/v/memory/memory.sv"
vlog "./Torus-Sys-Array-main/Torus-Sys-Array-main/v/memory/mem_pkg.sv"
vlog "./Torus-Sys-Array-main/Torus-Sys-Array-main/v/memory/matrix_mem.sv"
vlog "./Torus-Sys-Array-main/Torus-Sys-Array-main/v/memory/lvt_mem.sv"
vlog "./Torus-Sys-Array-main/Torus-Sys-Array-main/v/memory/identity_gen.sv"
vlog "./Torus-Sys-Array-main/Torus-Sys-Array-main/v/memory/banked_mem.sv"
vlog "./Torus-Sys-Array-main/Torus-Sys-Array-main/v/PE/TwistPE.sv"
vlog "./Torus-Sys-Array-main/Torus-Sys-Array-main/v/PE/PE_pkg.sv"
vlog "./Torus-Sys-Array-main/Torus-Sys-Array-main/v/sys_array/TwistMesh.sv"
vlog "./Torus-Sys-Array-main/Torus-Sys-Array-main/v/transpose/transpose.sv"
vlog "./Torus-Sys-Array-main/Torus-Sys-Array-main/v/transpose/tp_node.sv"
vlog "./Torus-Sys-Array-main/Torus-Sys-Array-main/v/transpose/shift_reg_simple.sv"
vlog -sv +incdir+$BSG_MISC "./Torus-Sys-Array-main/Torus-Sys-Array-main/v/Top_level/upstream_wrapper.sv"
vlog "./Torus-Sys-Array-main/Torus-Sys-Array-main/v/Top_level/parity_generator.sv"
vlog "./Torus-Sys-Array-main/Torus-Sys-Array-main/v/Top_level/parity_checker.sv"
vlog "./Torus-Sys-Array-main/Torus-Sys-Array-main/v/Top_level/functional_top.sv"
vlog -sv +incdir+$BSG_MISC "./Torus-Sys-Array-main/Torus-Sys-Array-main/v/Top_level/downstream_wrapper.sv"
vlog "./Torus-Sys-Array-main/Torus-Sys-Array-main/v/Top_level/depacketizer_mux.sv"
vlog "./Torus-Sys-Array-main/Torus-Sys-Array-main/v/Top_level/depacketizer.sv"
vlog -sv +incdir+$BSG_MISC "./Torus-Sys-Array-main/Torus-Sys-Array-main/v/Top_level/bsg_link_parity_wrapper.sv"
vlog "./Torus-Sys-Array-main/Torus-Sys-Array-main/v/Top_level/top_chip.sv"


#vlog "./Torus-Sys-Array-main/Torus-Sys-Array-main/v/controller/*.sv"
#vlog "./Torus-Sys-Array-main/Torus-Sys-Array-main/v/CSR/*.sv"
#vlog "./Torus-Sys-Array-main/Torus-Sys-Array-main/v/memory/*.sv"
#vlog "./Torus-Sys-Array-main/Torus-Sys-Array-main/v/PE/*.sv"
#vlog "./Torus-Sys-Array-main/Torus-Sys-Array-main/v/sys_array/*.sv"
#vlog "./Torus-Sys-Array-main/Torus-Sys-Array-main/v/transpose/*.sv"
#vlog -sv +incdir+$BSG_MISC "./Torus-Sys-Array-main/Torus-Sys-Array-main/v/Top_level/*.sv"


# wrappers and tb
vlog "./fpga_rx.sv"
vlog "./fpga_tx.sv"
vlog "./fpga_system_tb.sv"


# Call vsim to invoke simulator
#     Make sure the last item on the line is the name of the
#     testbench module you want to execute.
vsim -voptargs="+acc" -t 1ps -lib work fpga_system_tb

# Source the wave do file
#     This should be the file that sets up the signal window for
#     the module you are testing.
do fpga_system_wave.do

# Set the window types
view wave
view structure
view signals

# Run the simulation
run -all

# End
