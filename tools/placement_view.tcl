# From the repo root, after repair_slow.tcl: openroad -exit tools/placement_view.tcl
# Stream only physical extents (integer database units), not the netlist or names.
read_db build/corner-optimized.odb
set block [ord::get_db_block]
proc bounds {box} {
    return [list [$box xMin] [$box yMin] [$box xMax] [$box yMax]]
}
set insts [$block getInsts]
set render [open {|python3 tools/placement_view.py} w]
puts $render "[$block getDbUnitsPerMicron] [llength $insts] [bounds [$block getDieArea]] [bounds [$block getCoreArea]]"
foreach inst $insts {
    if {![$inst isPlaced] || ![string match sky130_fd_sc_hd__* [[$inst getMaster] getName]]} {
        error "Expected only placed SKY130 HD standard cells; unexpected instance [$inst getName]"
    }
    puts $render [bounds [$inst getBBox]]
}
close $render
