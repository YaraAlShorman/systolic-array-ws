################################################################################
#
# Init setup file
# Created by Genus(TM) Synthesis Solution on 03/13/2026 21:49:02
#
################################################################################
if { ![is_common_ui_mode] } { error "ERROR: This script requires common_ui to be active."}

read_mmmc genus_invs_des/genus.mmmc.tcl

read_physical -lef {/home/rmaiti/EE477_VLSI/systolic-array-ws/src/sys_array/build/tech-sky130-cache/sky130_fd_sc_hd__nom.tlef /home/projects/ee477.2025wtr/cad/pdk/sky130A/libs.ref/sky130_fd_sc_hd/lef/sky130_fd_sc_hd.lef}

read_netlist genus_invs_des/genus.v.gz

init_design
