#!/bin/sh
# Boot a TC2068 around the SCLD in ../rtl (or the directory given in RTL).
#
#   T80   directory holding the T80 core (T80_Pack.vhd ... T80a.vhd)
#   MODELS directory holding hct245.vhd, mem_4416.vhd, mem_vram_16k.vhd
#          and txt_util.vhd
#   ROMS  directory holding tc2068-0.rom (HOME, 16K) and tc2068-1.rom
#          (EXROM, 8K). The ROMs are not part of this repository.
#   RTL   SCLD sources to test                       (default ../rtl)
#   MS    simulated milliseconds                     (default 2000)
#   OUT   work/output directory                      (default ./work)
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
: "${T80:?set T80 to the T80 core directory}"
: "${MODELS:?set MODELS to the directory with hct245/mem_4416/mem_vram_16k/txt_util}"
: "${ROMS:?set ROMS to the directory with tc2068-0.rom and tc2068-1.rom}"
RTL=${RTL:-$HERE/../rtl}
MS=${MS:-2000}
OUT=${OUT:-$HERE/work}
mkdir -p "$OUT"
cd "$OUT"

F="--std=93 -fsynopsys -fexplicit -Wno-hide --workdir=. -P."
ghdl -a $F "$T80/T80_Pack.vhd" "$T80/T80_ALU.vhd" "$T80/T80_MCode.vhd" \
           "$T80/T80_Reg.vhd" "$T80/T80.vhd" "$T80/T80a.vhd"
TXT=$(find "$MODELS" -name txt_util.vhd | head -1)
ghdl -a $F "$TXT" "$RTL/scldpkg.vhd" "$RTL/scld_timing.vhd" \
           "$RTL/scld_contention.vhd" "$RTL/scld_regs.vhd" "$RTL/scld.vhd"
ghdl -a $F "$MODELS/hct245.vhd" "$MODELS/mem_4416.vhd" "$MODELS/mem_vram_16k.vhd"

# The SCLD has a simulation-only 'simcontrol' port; connect it if present.
if grep -q "simcontrol *: *in" "$RTL/scld.vhd"; then
  sed 's/--SIMCTL //' "$HERE/tb_tc2068_boot.vhd" > tb_tc2068_boot.vhd
else
  cp "$HERE/tb_tc2068_boot.vhd" tb_tc2068_boot.vhd
fi
ghdl -a $F tb_tc2068_boot.vhd
ghdl -e $F --syn-binding tb_tc2068_boot
ghdl -r $F --syn-binding tb_tc2068_boot \
     -gSIM_MS="$MS" -gHOME_ROM="$ROMS/tc2068-0.rom" -gEX_ROM="$ROMS/tc2068-1.rom" \
     -gFRAME_FILE=frame.txt --ieee-asserts=disable-at-0 --stop-time="$((MS + 5))ms" 2>&1 | tee run.log
python3 "$HERE/frame2png.py" frame.txt frame.png
