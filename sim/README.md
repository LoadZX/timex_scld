# TC2068 boot bench

Boots a minimal TC2068 around the SCLD in `../rtl` with the real HOME ROM and
EXROM, and writes the last video frame the SCLD produced as a PNG.

```sh
T80=/path/to/t80 MODELS=/path/to/models ROMS=/path/to/roms ./run.sh
```

| Variable | What it points at |
| --- | --- |
| `T80` | The T80 core: `T80_Pack`, `T80_ALU`, `T80_MCode`, `T80_Reg`, `T80`, `T80a` |
| `MODELS` | `hct245.vhd`, `mem_4416.vhd`, `mem_vram_16k.vhd`, `txt_util.vhd` |
| `ROMS` | `tc2068-0.rom` (HOME, 16K) and `tc2068-1.rom` (EXROM, 8K) |
| `RTL` | SCLD sources to test. Default `../rtl` |
| `MS` | Simulated milliseconds. Default 2000 |
| `HZ` | `50` or `60`: the SCLD's frame-rate strap, 312 or 262 lines. Default 50 |
| `OUT` | Work and output directory. Default `./work` |

None of the three inputs is in this repository. The ROMs are the ones Fuse
ships. GHDL and Python 3 are needed; nothing else.

The RAM test takes 1.7 s of simulated time, and the copyright screen is up by
2.0 s. A run of 2000 ms takes about six minutes.

## Reading the result

`work/frame.png` is the screen: exactly one frame, sync drawn black, so the
vertical sync is the black band along the bottom edge. `work/run.log` holds, in order:

- `IO  IN/OUT FF|F4 = ..` — every access to the two banking ports, with
  `READBACK MISMATCH` when a read does not return the last value written.
- `BUS FIGHT` — two outputs enabled at the instant the Z80 latched the bus.
- `T+nnn ms  PC=....  interrupts taken=n` — progress every 100 ms.

A good boot has no mismatch, no bus fight, and interrupts being taken from
about 1.8 s on.

`undefined byte read back` and `Z80 wrote an undefined byte` are about the CPU
model, not the SCLD: T80 leaves its registers uninitialised, and the ROM
pushes some of them before loading them.

## What is real and what is assumed

The SCLD, the Z80 bus timing (T80a), the 4416 DRAMs and the 74LS245 are
instantiated as they are. The board around them — address multiplexer, upper
RAM strobes, ROM enables — is a reconstruction and is not taken from a TC2068
netlist. The header of `tb_tc2068_boot.vhd` lists each assumption.

Nothing electrical is modelled. The bench cannot tell an NMOS Z80 from a CMOS
one, and it has no model of the boards that use series resistors in place of
the 74LS245.
