simSetSimulator "-vcssv" -exec \
           "/home/yarasho/vlsi_lab/ee477-designs-module2/bsg_guts_gcd/build/sim-par-rundir/simv" \
           -args
debImport "-full64" "-dbdir" \
          "/home/yarasho/vlsi_lab/ee477-designs-module2/bsg_guts_gcd/build/sim-par-rundir/simv.daidir"
debLoadSimResult \
           /home/yarasho/vlsi_lab/ee477-designs-module2/bsg_guts_gcd/build/sim-par-rundir/waveform.fsdb
debLoadSDFFile \
           "/home/yarasho/vlsi_lab/ee477-designs-module2/bsg_guts_gcd/build/par-rundir/bsg_chip.par.sdf" \
           -design bsg_chip
wvCreateWindow
verdiDockWidgetSetCurTab -dock widgetDock_<Decl._Tree>
srcTBBTreeSelect -win $_nTrace1 -path "gcd_mapped"
srcTBBTreeSelect -win $_nTrace1 -path "gcd_mapped"
srcTBTreeAction -win $_nTrace1 -path "gcd_mapped"
srcDeselectAll -win $_nTrace1
srcSelect -signal "A_i" -line 33629 -pos 1 -win $_nTrace1
srcSelect -signal "B_i" -line 33630 -pos 1 -win $_nTrace1
srcSelect -signal "Y_o" -line 33635 -pos 1 -win $_nTrace1
srcSelect -signal "clk_i" -line 33649 -pos 1 -win $_nTrace1
wvAddSignal -win $_nWave2 \
           "/bsg_double_trouble_pcb/asic/ASIC/guts/\\n\[0\].clnt.clnt /\\genblk1.node /A_i\[31:0\]" \
           "/bsg_double_trouble_pcb/asic/ASIC/guts/\\n\[0\].clnt.clnt /\\genblk1.node /B_i\[31:0\]" \
           "/bsg_double_trouble_pcb/asic/ASIC/guts/\\n\[0\].clnt.clnt /\\genblk1.node /Y_o\[31:0\]" \
           "/bsg_double_trouble_pcb/asic/ASIC/guts/\\n\[0\].clnt.clnt /\\genblk1.node /clk_i"
wvSetPosition -win $_nWave2 {("G1" 0)}
wvSetPosition -win $_nWave2 {("G1" 4)}
wvSetPosition -win $_nWave2 {("G1" 4)}
wvSetPosition -win $_nWave2 {("G1" 3)}
wvSetPosition -win $_nWave2 {("G1" 2)}
wvSetPosition -win $_nWave2 {("G1" 1)}
wvSetPosition -win $_nWave2 {("G1" 0)}
wvMoveSelected -win $_nWave2
wvSetPosition -win $_nWave2 {("G1" 0)}
wvSetPosition -win $_nWave2 {("G1" 4)}
srcSelect -signal "v_o" -line 33634 -pos 1 -win $_nTrace1
srcSelect -signal "ready_o" -line 33633 -pos 1 -win $_nTrace1
srcSelect -signal "v_i" -line 33632 -pos 1 -win $_nTrace1
srcSelect -signal "yumi_i" -line 33631 -pos 1 -win $_nTrace1
srcDeselectAll -win $_nTrace1
srcSelect -signal "Y_o" -line 33635 -pos 1 -win $_nTrace1
srcDeselectAll -win $_nTrace1
srcDeselectAll -win $_nTrace1
srcSelect -signal "v_o" -line 33634 -pos 1 -win $_nTrace1
srcSelect -signal "ready_o" -line 33633 -pos 1 -win $_nTrace1
srcSelect -signal "v_i" -line 33632 -pos 1 -win $_nTrace1
srcSelect -signal "yumi_i" -line 33631 -pos 1 -win $_nTrace1
wvSetPosition -win $_nWave2 {("G2" 0)}
wvAddSignal -win $_nWave2 \
           "/bsg_double_trouble_pcb/asic/ASIC/guts/\\n\[0\].clnt.clnt /\\genblk1.node /v_o" \
           "/bsg_double_trouble_pcb/asic/ASIC/guts/\\n\[0\].clnt.clnt /\\genblk1.node /ready_o" \
           "/bsg_double_trouble_pcb/asic/ASIC/guts/\\n\[0\].clnt.clnt /\\genblk1.node /v_i" \
           "/bsg_double_trouble_pcb/asic/ASIC/guts/\\n\[0\].clnt.clnt /\\genblk1.node /yumi_i"
wvSetPosition -win $_nWave2 {("G2" 0)}
wvSetPosition -win $_nWave2 {("G2" 4)}
wvSetPosition -win $_nWave2 {("G2" 4)}
wvSetCursor -win $_nWave2 12712306.618687 -snap {("G2" 2)}
wvSearchNext -win $_nWave2
wvSearchNext -win $_nWave2
wvSearchPrev -win $_nWave2
wvSetCursor -win $_nWave2 12713902.085720 -snap {("G1" 4)}
wvSearchNext -win $_nWave2
wvSearchNext -win $_nWave2
wvSearchNext -win $_nWave2
wvSearchNext -win $_nWave2
wvSearchPrev -win $_nWave2
wvSearchPrev -win $_nWave2
wvSelectSignal -win $_nWave2 {( "G1" 4 )} 
wvSearchNext -win $_nWave2
wvSearchNext -win $_nWave2
wvSetSearchMode -win $_nWave2 -posedge
wvSetCursor -win $_nWave2 12712306.618687 -snap {("G1" 4)}
wvSearchNext -win $_nWave2
wvSearchNext -win $_nWave2
wvSearchNext -win $_nWave2
wvSearchNext -win $_nWave2
wvSearchNext -win $_nWave2
wvSearchNext -win $_nWave2
wvSearchNext -win $_nWave2
wvSearchNext -win $_nWave2
wvSearchNext -win $_nWave2
wvSearchNext -win $_nWave2
wvSearchNext -win $_nWave2
wvSearchNext -win $_nWave2
wvSearchNext -win $_nWave2
wvSearchNext -win $_nWave2
wvSearchNext -win $_nWave2
wvSearchNext -win $_nWave2
wvSearchNext -win $_nWave2
wvSearchNext -win $_nWave2
wvSearchNext -win $_nWave2
wvSearchNext -win $_nWave2
wvSearchNext -win $_nWave2
wvSearchNext -win $_nWave2
wvSearchNext -win $_nWave2
wvSetCursor -win $_nWave2 15688601.964700 -snap {("G1" 3)}
wvSearchNext -win $_nWave2
wvSearchNext -win $_nWave2
wvSearchNext -win $_nWave2
wvSearchNext -win $_nWave2
wvSearchNext -win $_nWave2
wvSearchNext -win $_nWave2
wvSearchNext -win $_nWave2
wvSearchNext -win $_nWave2
wvSearchNext -win $_nWave2
wvSearchNext -win $_nWave2
wvSearchNext -win $_nWave2
wvSearchNext -win $_nWave2
wvSearchNext -win $_nWave2
wvSearchNext -win $_nWave2
wvSearchNext -win $_nWave2
wvSearchNext -win $_nWave2
wvSearchNext -win $_nWave2
wvSearchNext -win $_nWave2
wvSearchNext -win $_nWave2
wvSearchNext -win $_nWave2
wvSearchNext -win $_nWave2
wvSearchNext -win $_nWave2
wvSearchNext -win $_nWave2
wvSearchNext -win $_nWave2
wvSetCursor -win $_nWave2 18639135.175440 -snap {("G1" 3)}
wvSearchNext -win $_nWave2
wvSearchNext -win $_nWave2
wvSearchNext -win $_nWave2
wvSearchNext -win $_nWave2
wvSearchNext -win $_nWave2
wvSearchNext -win $_nWave2
wvSearchNext -win $_nWave2
wvSearchNext -win $_nWave2
wvSearchNext -win $_nWave2
wvSearchNext -win $_nWave2
wvSearchNext -win $_nWave2
wvSearchNext -win $_nWave2
wvSearchNext -win $_nWave2
wvSearchNext -win $_nWave2
wvSearchNext -win $_nWave2
wvSearchNext -win $_nWave2
wvSearchNext -win $_nWave2
wvSearchNext -win $_nWave2
wvSearchNext -win $_nWave2
wvSearchNext -win $_nWave2
wvSearchNext -win $_nWave2
wvSearchNext -win $_nWave2
wvSearchNext -win $_nWave2
wvSearchNext -win $_nWave2
wvSearchNext -win $_nWave2
wvSearchNext -win $_nWave2
wvSearchNext -win $_nWave2
wvSearchNext -win $_nWave2
wvSearchNext -win $_nWave2
wvSearchNext -win $_nWave2
wvSearchNext -win $_nWave2
wvSearchNext -win $_nWave2
wvSearchNext -win $_nWave2
wvSearchNext -win $_nWave2
wvSearchNext -win $_nWave2
wvSetCursor -win $_nWave2 21838612.710009 -snap {("G1" 4)}
wvSearchNext -win $_nWave2
wvSearchNext -win $_nWave2
wvSearchNext -win $_nWave2
wvSearchNext -win $_nWave2
wvSearchNext -win $_nWave2
wvSearchNext -win $_nWave2
wvSearchNext -win $_nWave2
wvSearchNext -win $_nWave2
wvSearchNext -win $_nWave2
wvSearchNext -win $_nWave2
wvSearchNext -win $_nWave2
wvSearchNext -win $_nWave2
wvSearchNext -win $_nWave2
wvSearchNext -win $_nWave2
wvSearchNext -win $_nWave2
wvSearchNext -win $_nWave2
wvSearchNext -win $_nWave2
wvSearchNext -win $_nWave2
wvSearchNext -win $_nWave2
wvSearchNext -win $_nWave2
wvSearchNext -win $_nWave2
wvSearchNext -win $_nWave2
wvSearchNext -win $_nWave2
wvSearchNext -win $_nWave2
wvSearchNext -win $_nWave2
wvSearchNext -win $_nWave2
wvSearchNext -win $_nWave2
wvSearchNext -win $_nWave2
wvSearchNext -win $_nWave2
wvSearchNext -win $_nWave2
wvSearchNext -win $_nWave2
wvSearchNext -win $_nWave2
wvSearchNext -win $_nWave2
wvSearchNext -win $_nWave2
wvSearchNext -win $_nWave2
wvSearchNext -win $_nWave2
wvSearchNext -win $_nWave2
wvSearchNext -win $_nWave2
wvSearchNext -win $_nWave2
wvSearchNext -win $_nWave2
wvSearchNext -win $_nWave2
wvSearchNext -win $_nWave2
wvSearchNext -win $_nWave2
wvSearchNext -win $_nWave2
wvSetCursor -win $_nWave2 25289865.235703 -snap {("G1" 3)}
wvSearchNext -win $_nWave2
wvSearchNext -win $_nWave2
wvSearchNext -win $_nWave2
wvSearchNext -win $_nWave2
wvSearchNext -win $_nWave2
wvSearchNext -win $_nWave2
wvSearchNext -win $_nWave2
wvSearchNext -win $_nWave2
wvSearchNext -win $_nWave2
wvSearchNext -win $_nWave2
wvSearchNext -win $_nWave2
wvSearchNext -win $_nWave2
wvSearchNext -win $_nWave2
wvSearchNext -win $_nWave2
wvSearchNext -win $_nWave2
wvSearchNext -win $_nWave2
wvSearchNext -win $_nWave2
wvSearchNext -win $_nWave2
wvSearchNext -win $_nWave2
wvSearchNext -win $_nWave2
wvSearchNext -win $_nWave2
wvSearchNext -win $_nWave2
wvSearchNext -win $_nWave2
wvSearchNext -win $_nWave2
wvSearchNext -win $_nWave2
wvSearchNext -win $_nWave2
wvSearchNext -win $_nWave2
wvSearchNext -win $_nWave2
wvSearchNext -win $_nWave2
wvSearchNext -win $_nWave2
wvSearchNext -win $_nWave2
debExit
