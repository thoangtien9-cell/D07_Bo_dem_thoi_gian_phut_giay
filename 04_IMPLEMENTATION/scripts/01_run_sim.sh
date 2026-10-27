#!/usr/bin/env bash
# =====================================================================
#  D07 · Buoc 1 — Mo phong chuc nang (Icarus Verilog)
#  Chay tu THU MUC GOC cua du an:
#      bash 04_IMPLEMENTATION/scripts/01_run_sim.sh
# =====================================================================
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"; cd "$ROOT"
OUT=05_VERIFICATION
mkdir -p "$OUT/waveforms"

command -v iverilog >/dev/null || { echo "[LOI] thieu 'iverilog' (sudo apt install iverilog)"; exit 2; }

iverilog -V | head -1 | tee "$OUT/tool_versions.txt"

iverilog -g2012 -o "$OUT/sim.vvp" \
    04_IMPLEMENTATION/rtl/d07_bcd_core.sv \
    04_IMPLEMENTATION/rtl/d07_binary_core.sv \
    05_VERIFICATION/golden_model/d07_reference.sv \
    05_VERIFICATION/testbench/d07_bcd_tb.sv

cd "$OUT" && vvp sim.vvp | tee simulation.log; cd "$ROOT"
mv -f "$OUT"/*.vcd "$OUT/waveforms/" 2>/dev/null || true

echo
echo "Bang chung: $OUT/simulation.log"
echo "Waveform  : $OUT/waveforms/"
