#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

for tool in verilator yosys iverilog vvp; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        printf 'ERROR: %s is required.\n' "$tool" >&2
        exit 1
    fi
done

mkdir -p build/synthesis netlist

RTL_FILES=(
    rtl/program_counter.v rtl/instruction_memory.v rtl/control_unit.v
    rtl/register_file.v rtl/immediate_generator.v rtl/alu_src_mux.v
    rtl/alu_control.v rtl/alu.v rtl/data_memory.v rtl/writeback_mux.v
    rtl/branch_target.v rtl/next_pc_mux.v rtl/rv32i_core.v rtl/rv32i_top.v
)

printf '[1/4] Verilator lint\n'
verilator --lint-only -Wall --top-module rv32i_top "${RTL_FILES[@]}"

printf '[2/4] ALU integration simulation\n'
bash scripts/run_alu_integration.sh > build/synthesis/alu_integration.log
grep 'ALU INTEGRATION TEST PASSED' build/synthesis/alu_integration.log

printf '[3/4] Yosys synthesis and netlist generation\n'
yosys -Q -l build/synthesis/yosys.log -p "
    read_verilog -DSYNTHESIS ${RTL_FILES[*]};
    hierarchy -check -top rv32i_core;
    synth -top rv32i_core;
    check -assert;
    tee -o build/synthesis/stat.txt stat -top rv32i_core;
    write_verilog -noattr netlist/rv32i_core_netlist.v;
" > /dev/null

printf '[4/4] Generic logic-depth analysis\n'
: > build/synthesis/logic_depth.txt
for top in alu alu_control register_file data_memory writeback_mux \
           branch_target next_pc_mux immediate_generator control_unit; do
    yosys -Q -p "
        read_verilog -DSYNTHESIS rtl/*.v;
        hierarchy -check -top ${top};
        synth -top ${top} -flatten;
        ltp -noff;
    " > "build/synthesis/ltp_${top}.log"
    grep 'Longest topological path' "build/synthesis/ltp_${top}.log" \
        >> build/synthesis/logic_depth.txt
done

{
    printf 'RV32I CORE SYNTHESIS REPORT\n'
    printf '============================\n\n'
    yosys -V
    printf '\nTop module: rv32i_core\n'
    printf 'Netlist: netlist/rv32i_core_netlist.v\n'
    printf 'Lint: PASS (Verilator -Wall)\n'
    printf 'ALU integration simulation: PASS\n'
    printf 'Yosys structural check: PASS (no conflicts or undriven wires)\n\n'
    printf 'RESOURCE STATISTICS\n'
    printf '%s\n' '-------------------'
    # Yosys uses a trailing space on the vertical separator in its ASCII
    # tables. Strip line-end whitespace so the checked-in report stays clean.
    sed 's/[[:space:]]*$//' build/synthesis/stat.txt
    printf '\nGENERIC COMBINATIONAL LOGIC DEPTH\n'
    printf '%s\n' '---------------------------------'
    cat build/synthesis/logic_depth.txt
    printf '\nThese are generic mapped gate levels, not nanoseconds. A target-cell\n'
    printf 'library, placement, routing, and static timing constraints are required\n'
    printf 'for a technology-specific maximum clock frequency.\n'
} > synthesis_report.txt

printf '\nPASS: lint, simulation, synthesis, and structural checks completed.\n'
printf 'Report: %s/synthesis_report.txt\n' "$ROOT_DIR"
printf 'Netlist: %s/netlist/rv32i_core_netlist.v\n' "$ROOT_DIR"
