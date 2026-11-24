#!/bin/sh
# Run inside the proposal's SKY130 EDA image. All outputs are pre-route estimates.
set -eu
cd "$(dirname "$0")/.."
mkdir -p build
unset EEG_PERIOD_NS
sh tools/map_area.sh
sta -exit tools/timing.tcl > build/unbuffered.log
openroad -threads 3 -exit tools/place.tcl > build/placement.log
openroad -threads 3 -exit tools/repair_slow.tcl > build/repair.log
openroad -exit tools/placement_view.tcl
for mhz in 10 12; do
    case $mhz in 10) period=100;; 12) period=83.333;; esac
    report="build/placed-${mhz}mhz.log"
    : > "$report"
    for corner in tt_025C_1v80 ss_n40C_1v60 ss_100C_1v60 ff_n40C_1v95 ff_100C_1v95; do
        EEG_LIB_CORNER=$corner EEG_PERIOD_NS=$period EEG_PLACEMENT_DB=build/corner-optimized.odb \
            openroad -threads 2 -exit tools/corners.tcl >> "$report"
    done
done
python3 tools/plot_timing.py build/placed-12mhz.log build/placed-10mhz.log
cat proposal/timing.csv
