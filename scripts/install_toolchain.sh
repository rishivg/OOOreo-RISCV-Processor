#!/usr/bin/env bash
# Install host dependencies; sbt must already be available.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/tools/versions.lock"
packages=(build-essential python3 make verilator iverilog yosys zstd gcc-riscv64-unknown-elf)
command -v javac >/dev/null || packages+=(default-jdk-headless)
sudo apt-get update
sudo apt-get install -y "${packages[@]}"
command -v sbt >/dev/null || { echo "Install sbt (hdl/project/build.properties)." >&2; exit 1; }
if [[ ${NO_DOCKER:-1} == 0 ]]; then
    docker pull "$ORFS_IMAGE"
fi
verilator --version
yosys -V
