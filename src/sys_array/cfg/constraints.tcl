# constraints.tcl
#
# This file is where design timing constraints are defined for Genus and Innovus.
# Many constraints can be written directly into the Hammer config files. However, 
# you may manually define constraints here as well.

# TODO: add constraints.
create_clock -name clk -period 20.0 [get_ports clk_i]
set_clock_uncertainty 0.6 [get_clocks clk]

# Always set the input/output delay as half periods for clock setup checks
set_input_delay  4.0 -max -clock [get_clocks clk] [remove_from_collection [all_inputs] [get_ports clk_i]]
set_output_delay 4.0 -max -clock [get_clocks clk] [all_outputs]

# Always set the input/output delay as 0 for clock hold checks
set_input_delay  0.0 -min -clock [get_clocks clk] [remove_from_collection [all_inputs] [get_ports clk_i]]
set_output_delay 0.0 -min -clock [get_clocks clk] [all_outputs]

#set area_storage_inst [get_db insts "u_area_storage"]
#if {[llength $area_storage_inst] == 0} {
#  puts "WARN: u_area_storage instance not found in current design."
#  puts "      Run after elaborate/current_design top_mod."
#} else {
#  # Preserve hierarchy and disable structural changes on this block.
#  catch {set_db $area_storage_inst .dont_touch true}
#  catch {set_db $area_storage_inst .preserve true}
#  catch {set_db $area_storage_inst .ungroup false}
#  catch {set_db $area_storage_inst .delete_unloaded_seqs false}
#
#  # Apply dont_touch recursively to descendants (regs/combinational logic).
#  set area_desc [get_db [get_db $area_storage_inst .hinsts] .insts]
#  if {[llength $area_desc] > 0} {
#    catch {set_db $area_desc .dont_touch true}
#    catch {set_db $area_desc .preserve true}
#  }
#
#  # Extra belt-and-suspenders for sequential storage elements.
#  set area_regs [get_db regs -if {.inst.name =~ "u_area_storage*"}]
#  if {[llength $area_regs] > 0} {
#    catch {set_db $area_regs .dont_touch true}
#    catch {set_db $area_regs .preserve true}
#  }
#
#  puts "INFO: Applied Genus preserve constraints to u_area_storage."
#}
