#!/bin/sh
# Run in the pinned EDA environment, from the project root. Cell area only.
set -eu
lib=${PDK_ROOT:-/foss/pdks}/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib
mkdir -p build
cat > build/map.ys <<EOF
read_liberty -lib -ignore_miss_dir -ignore_miss_func $lib
read_verilog -sv rtl/*.sv
hierarchy -check -top eeg_challenge
synth -top eeg_challenge -flatten -noabc
dfflibmap -liberty $lib
abc -liberty $lib
clean
check -assert
stat -liberty $lib
write_verilog -noattr -noexpr -nohex -nodec build/eeg_challenge.v
EOF
yosys -l build/map.log -Q -q build/map.ys
grep -E 'Chip area for module|of which used for sequential elements' build/map.log
