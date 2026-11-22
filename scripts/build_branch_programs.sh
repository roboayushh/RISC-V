#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

mode="${1:-build}"
if [[ $# -gt 1 || ( "$mode" != build && "$mode" != --check ) ]]; then
    printf 'Usage: bash scripts/build_branch_programs.sh [--check]\n' >&2
    exit 1
fi

if [[ -z "${CROSS_COMPILE:-}" ]]; then
    for prefix in riscv64-elf- riscv64-unknown-elf- riscv32-unknown-elf-; do
        if command -v "${prefix}as" >/dev/null 2>&1; then
            CROSS_COMPILE="$prefix"
            break
        fi
    done
fi
if [[ -z "${CROSS_COMPILE:-}" ]]; then
    printf 'RISC-V GNU Binutils is required. On macOS run brew install riscv64-elf-binutils.\n' >&2
    exit 1
fi
for tool in as ld objcopy objdump; do
    if ! command -v "${CROSS_COMPILE}${tool}" >/dev/null 2>&1; then
        printf 'Missing tool: %s%s\n' "$CROSS_COMPILE" "$tool" >&2
        exit 1
    fi
done
if ! command -v python3 >/dev/null 2>&1; then
    printf 'Python 3 is required to convert little-endian bytes to instruction words.\n' >&2
    exit 1
fi

build_dir="build/branch_programs"
mkdir -p "$build_dir"
programs=(arithmetic memory branch_equal branch_not_equal integration branch_offsets)

"${CROSS_COMPILE}as" --version | head -n 1
for program in "${programs[@]}"; do
    "${CROSS_COMPILE}as" -march=rv32i -mabi=ilp32 -mno-relax \
        -o "$build_dir/$program.o" "programs/$program.S"
    "${CROSS_COMPILE}ld" -melf32lriscv --no-relax -Ttext=0 --entry=_start \
        -o "$build_dir/$program.elf" "$build_dir/$program.o"
    "${CROSS_COMPILE}objcopy" --only-section=.text -O binary \
        "$build_dir/$program.elf" "$build_dir/$program.bin"
    "${CROSS_COMPILE}objdump" -d -M no-aliases,numeric "$build_dir/$program.elf" \
        > "$build_dir/$program.disasm"
    python3 - "$build_dir/$program.bin" "$build_dir/$program.hex" <<'PY'
import pathlib
import struct
import sys

binary = pathlib.Path(sys.argv[1]).read_bytes()
if not binary or len(binary) % 4:
    raise SystemExit("Expected a nonempty image of four-byte RV32I instructions")
words = (f"{word:08x}\n" for (word,) in struct.iter_unpack("<I", binary))
pathlib.Path(sys.argv[2]).write_text("".join(words), encoding="ascii")
PY
done

# Finish all assembly/link steps before updating the checked-in images.
for program in "${programs[@]}"; do
    if [[ "$mode" == --check ]]; then
        diff -u "programs/$program.hex" "$build_dir/$program.hex"
    else
        cp "$build_dir/$program.hex" "programs/$program.hex"
    fi
    printf 'PASS: %s source and hex match\n' "$program"
done
