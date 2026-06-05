#!/bin/bash
# Fetch riscv-formal (the ISA reference checks + genchecks.py). Pinned commit so
# proofs are reproducible. The core already vendors riscv-formal's *monitor*
# (hvl/common/rvfimon.v) for simulation; this brings in the *formal* checks.
set -e
RVF_DIR="$(dirname "$0")/checkout"
RVF_COMMIT="${RVF_COMMIT:-a64b696}"   # pin; bump deliberately
if [ ! -d "$RVF_DIR/.git" ]; then
  git clone https://github.com/YosysHQ/riscv-formal.git "$RVF_DIR"
fi
git -C "$RVF_DIR" fetch --all
git -C "$RVF_DIR" checkout "$RVF_COMMIT"
echo "riscv-formal at $RVF_DIR ($(git -C "$RVF_DIR" rev-parse --short HEAD))"
echo "next: make   (runs genchecks.py + sby per check)"
