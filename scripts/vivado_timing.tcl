# Routed core timing on the selected Artix-7 device; no board pin assignment.
# Run from the repository root: vivado -mode batch -source scripts/vivado_timing.tcl
# Optional first Tcl argument: target clock period in ns (default 20).
set root [file normalize [file join [file dirname [info script]] ..]]
cd $root
set period 20.0
if {[llength $argv] > 0} { set period [lindex $argv 0] }
if {![string is double -strict $period] || $period <= 0} {
    error "Clock period must be a positive number of nanoseconds"
}
set out [file join $root build vivado]
file mkdir $out
set part xc7a35tcpg236-1
read_verilog [glob [file join $root rtl *.v]]
synth_design -top rv32i_top -part $part -mode out_of_context
create_clock -name clk -period $period [get_ports clk]
# This is core register-to-register characterization. External reset/observation
# ports have no invented board I/O budget. Inspect check_timing for those limits.
opt_design
place_design
phys_opt_design
route_design
report_route_status -file [file join $out route_status.rpt]
report_utilization -file [file join $out utilization.rpt]
report_drc -file [file join $out drc.rpt]
check_timing -verbose -file [file join $out check_timing.rpt]
report_timing_summary -delay_type min_max -report_unconstrained \
    -file [file join $out timing_summary.rpt]
set qpins [all_registers -clock clk -output_pins]
set dpins [all_registers -clock clk -data_pins]
if {[llength $qpins] == 0 || [llength $dpins] == 0} {
    error "No registers found in the clk domain"
}
set setup [get_timing_paths -from $qpins -to $dpins -delay_type max -max_paths 1]
set hold [get_timing_paths -from $qpins -to $dpins -delay_type min -max_paths 1]
if {[llength $setup] != 1 || [llength $hold] != 1} {
    error "Cannot extract a constrained register-to-register setup/hold path"
}
report_timing -from $qpins -to $dpins -delay_type max -max_paths 10 \
    -file [file join $out core_setup.rpt]
report_timing -from $qpins -to $dpins -delay_type min -max_paths 10 \
    -file [file join $out core_hold.rpt]
write_checkpoint -force [file join $out routed.dcp]
set slack [get_property SLACK $setup]
set hold_slack [get_property SLACK $hold]
set required_period [expr {$period - $slack}]
if {$required_period <= 0} { error "Invalid setup-derived period" }
set f [open [file join $out core_timing.txt] w]
puts $f "Vivado: [version -short]"
puts $f "Part: $part; top: rv32i_top; mode: out_of_context"
puts $f "Target period (ns): $period"
puts $f "Core setup slack (ns): $slack"
puts $f "Core hold slack (ns): $hold_slack"
puts $f "Setup-derived period bound (ns): $required_period"
puts $f "Setup-derived frequency bound (MHz): [expr {1000.0 / $required_period}]"
puts $f "Single routed implementation; rerun at the chosen clock to establish closure."
puts $f "No board I/O budget or bitstream. See DRC, route status and check_timing."
close $f
if {$slack < 0 || $hold_slack < 0} {
    error "Core timing does not close at target period; inspect build/vivado reports"
}
puts "Core setup and hold pass at target period $period ns; inspect all reports."
