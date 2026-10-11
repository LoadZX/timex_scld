#!/bin/sh
# Check that a Z80 refresh cycle gives the video RAM a whole RAS pulse or
# none. See the header of tb_refresh_ras.vhd.
#
#   MODELS directory holding txt_util.vhd (the SCLD's only outside dependency)
#   RTL    SCLD sources to test                       (default ../rtl)
#   OUT    work/output directory                      (default ./work)
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
: "${MODELS:?set MODELS to the directory with txt_util.vhd}"
RTL=${RTL:-$HERE/../rtl}
OUT=${OUT:-$HERE/work}
mkdir -p "$OUT"
cd "$OUT"

F="--std=93 -fsynopsys -fexplicit -Wno-hide --workdir=. -P."
TXT=$(find "$MODELS" -name txt_util.vhd | head -1)
ghdl -a $F "$TXT" "$RTL/scldpkg.vhd" "$RTL/scld_timing.vhd" \
           "$RTL/scld_contention.vhd" "$RTL/scld_regs.vhd" "$RTL/scld.vhd"

# The SCLD has a simulation-only 'simcontrol' port; connect it if present.
if grep -q "simcontrol *: *in" "$RTL/scld.vhd"; then
  sed 's/--SIMCTL //' "$HERE/tb_refresh_ras.vhd" > tb_refresh_ras.vhd
else
  cp "$HERE/tb_refresh_ras.vhd" tb_refresh_ras.vhd
fi
ghdl -a $F tb_refresh_ras.vhd
ghdl -e $F tb_refresh_ras
ghdl -r $F tb_refresh_ras --ieee-asserts=disable-at-0 2>&1 | tee refresh_ras.log
if grep -q "PASS:" refresh_ras.log && ! grep -q "(report error)" refresh_ras.log; then
  exit 0
fi
exit 1
