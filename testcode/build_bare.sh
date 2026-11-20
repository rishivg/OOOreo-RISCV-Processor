#!/bin/bash
# Build a self-checking fixture at the default reset PC with 32-byte section padding.
# Usage: testcode/build_bare.sh testcode/csr_test.s [march]
set -e
SRC="$1"; ARCH="${2:-rv32imac_zicsr_zifencei}"
OUT="${SRC%.s}.elf"
HERE="$(cd "$(dirname "$0")" && pwd)"
riscv64-unknown-elf-gcc -march="$ARCH" -mabi=ilp32 -nostdlib -nostartfiles -mcmodel=medany \
  -Wl,--no-relax -T "$HERE/bare.ld" "$SRC" -o "$OUT"
riscv64-unknown-elf-objcopy -R .riscv.attributes -R .comment "$OUT"
riscv64-unknown-elf-objdump -h "$OUT" | grep -E '^\s+[0-9]+ \.' | awk '{print "  " $2, $3, $4}'
