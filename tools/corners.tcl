# Run in a fresh OpenROAD process per Liberty so corners cannot silently mix.
set cor $::env(EEG_LIB_CORNER)
read_liberty /foss/pdks/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__${cor}.lib
read_db $::env(EEG_PLACEMENT_DB)
read_sdc tools/endpoint.sdc
set_wire_rc -signal -layer met2
set_wire_rc -clock -layer met3
estimate_parasitics -placement
puts "CORNER $cor (nominal layer RC estimate, ideal clock, no CTS/routing)"
report_worst_slack -max -digits 3
report_worst_slack -min -digits 3
exit
