#!/bin/bash
# Script to install dependencies for OOOreo development
# Supported OS: Ubuntu 22.04+ / Debian 12+

set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOOLS_DIR="$PROJECT_ROOT/fpga/tools"

# Pinned versions — single source of truth (see tools/versions.lock).
# shellcheck disable=SC1090
set -a; . "$PROJECT_ROOT/tools/versions.lock"; set +a

echo "====================================================================="
echo "  OOOreo Development Environment Setup"
echo "  Pins: verilator $VERILATOR_VERSION | yosys(lint) $YOSYS_LINT_VERSION |"
echo "        sv2v $SV2V_VERSION | riscv-gcc $RISCV_GCC_VERSION"
echo "        synth/PPA via $ORFS_IMAGE (yosys $YOSYS_SYNTH_VERSION + OpenROAD)"
echo "====================================================================="

# 1. System Dependencies (APT)
echo "[1/3] Installing System Dependencies (Requires Sudo)..."
sudo apt-get update
sudo apt-get install -y \
    git build-essential python3 python3-pip make curl unzip tar bc \
    verilator yosys \
    gcc-riscv64-unknown-elf \
    gdb-multiarch

# 2. SV2V Installation (SystemVerilog to Verilog)
echo "[2/3] Installing sv2v (SystemVerilog Frontend)..."
mkdir -p "$TOOLS_DIR"

if [ -f "$TOOLS_DIR/sv2v-Linux/sv2v" ]; then
    echo "  - sv2v already installed."
else
    echo "  - Downloading sv2v v0.0.13..."
    wget -q https://github.com/zachjs/sv2v/releases/download/v0.0.13/sv2v-Linux.zip -O "$TOOLS_DIR/sv2v.zip"
    unzip -q -o "$TOOLS_DIR/sv2v.zip" -d "$TOOLS_DIR"
    rm "$TOOLS_DIR/sv2v.zip"
    chmod +x "$TOOLS_DIR/sv2v-Linux/sv2v"
    echo "  - sv2v installed successfully."
fi

# 3. Synthesis / PPA container (pinned by digest). Optional: skip with NO_DOCKER=1.
echo "[3/4] Pulling pinned OpenROAD image for synth/PPA..."
if [ -z "${NO_DOCKER:-}" ] && command -v docker >/dev/null 2>&1; then
    docker pull "$ORFS_IMAGE" || echo "  - WARN: could not pull $ORFS_IMAGE (synth/PPA will fail until pulled)"
else
    echo "  - docker not present or NO_DOCKER set; skipping (synth/PPA needs it)."
fi

# 4. Python Dependencies
echo "[4/4] Installing Python Dependencies..."
# Install user-level python packages if needed (e.g., for sophisticated test runners)
# pip3 install -r requirements.txt 2>/dev/null || echo "  - No requirements.txt found, skipping."

echo "====================================================================="
echo "  Setup Complete!"
echo "  - Tools Location: $TOOLS_DIR"
echo "  - Verilator Version: $(verilator --version)"
echo "  - Yosys Version: $(yosys -V | awk '{print $2}')"
echo "====================================================================="

