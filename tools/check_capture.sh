#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
mkdir -p build
python3 tools/reference_roots.py > build/reference-roots.txt
{ read -r zero; read -r one; read -r missing; } < build/reference-roots.txt
# Compile in local container storage if the project is on a slow bind mount.
vdir=${VERILATOR_DIR:-$PWD/build/verilated}
verilator --binary --timing -j 2 --top-module tb_capture --Mdir "$vdir" rtl/*.sv tests/tb_capture.sv
"$vdir/Vtb_capture" +ROOT0="$zero" +ROOT1="$one" +ROOT_MISSING="$missing"
