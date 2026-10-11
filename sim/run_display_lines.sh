#!/bin/sh
# Check that the SCLD takes the video RAM, and holds the CPU, on the 192
# display lines only. See the header of tb_display_lines.vhd.
#
#   MODELS directory holding txt_util.vhd (the SCLD's only outside dependency)
#   RTL    SCLD sources to test                       (default ../rtl)
#   HZ     50 or 60: frame rate strap, 312 or 262 lines (default 50)
#   OUT    work/output directory                      (default ./work)
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
: "${MODELS:?set MODELS to the directory with txt_util.vhd}"
RTL=${RTL:-$HERE/../rtl}
HZ=${HZ:-50}
if [ "$HZ" = 60 ]; then HZ50=false; else HZ50=true; fi
OUT=${OUT:-$HERE/work}
mkdir -p "$OUT"
cd "$OUT"

F="--std=93 -fsynopsys -fexplicit -Wno-hide --workdir=. -P."
TXT=$(find "$MODELS" -name txt_util.vhd | head -1)
ghdl -a $F "$TXT" "$RTL/scldpkg.vhd" "$RTL/scld_timing.vhd" \
           "$RTL/scld_contention.vhd" "$RTL/scld_regs.vhd" "$RTL/scld.vhd"

# The SCLD has a simulation-only 'simcontrol' port; connect it if present.
if grep -q "simcontrol *: *in" "$RTL/scld.vhd"; then
  sed 's/--SIMCTL //' "$HERE/tb_display_lines.vhd" > tb_display_lines.vhd
else
  cp "$HERE/tb_display_lines.vhd" tb_display_lines.vhd
fi
ghdl -a $F tb_display_lines.vhd
ghdl -e $F tb_display_lines
ghdl -r $F tb_display_lines -gHZ50="$HZ50" --ieee-asserts=disable-at-0 \
     2>&1 | tee display_lines.log
if grep -q "PASS:" display_lines.log && ! grep -q "(report error)" display_lines.log; then
  exit 0
fi
exit 1
