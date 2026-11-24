# Nominal, ideal-clock, no routed parasitics. Units follow the Sky130A HD Liberty.
read_liberty /foss/pdks/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib
read_verilog build/eeg_challenge.v
link_design eeg_challenge
read_sdc tools/endpoint.sdc
check_setup -verbose
report_checks -path_delay max -sort_by_slack -group_path_count 1 -digits 3
report_worst_slack -max -digits 3
exit
