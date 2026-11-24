# Gate placement and physical buffering trial; standalone rectangle, NOT a shuttle slot.
set hd /foss/pdks/sky130A/libs.ref/sky130_fd_sc_hd
read_lef $hd/techlef/sky130_fd_sc_hd__nom.tlef
read_lef $hd/lef/sky130_fd_sc_hd.lef
read_liberty $hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib
read_verilog build/eeg_challenge.v
link_design eeg_challenge
read_sdc tools/endpoint.sdc
initialize_floorplan -utilization 50 -aspect_ratio 1 -core_space 12 -site unithd
make_tracks
place_pins -hor_layers met3 -ver_layers met2
set_wire_rc -signal -layer met2
set_wire_rc -clock -layer met3
repair_design -pre_placement
global_placement -density 0.58
estimate_parasitics -placement
repair_design
repair_timing -setup -max_passes 4 -max_iterations 12
detailed_placement
check_placement
estimate_parasitics -placement
report_design_area
report_checks -path_delay max -sort_by_slack -group_path_count 1 -digits 3
report_worst_slack -max -digits 3
write_db build/placement.odb
exit
