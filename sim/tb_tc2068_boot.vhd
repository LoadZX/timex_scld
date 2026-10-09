--
-- TC2068 boot testbench for the TIMEX(tm) SCLD model
--
--  (c) by Load ZX Museum <curator@loadzx.com>
--
-- This VHDL Model is licensed under a
-- Creative Commons Attribution-ShareAlike 4.0 International License.
--
-- You should have received a copy of the license along with this
-- work. If not, see <https://creativecommons.org/licenses/by-sa/4.0/>.
--
-- TIMEX is a trademark of TIMEX GROUP USA, INC
--
-- The authors of this work are not affiliated, sponsored or have any
-- partnership with the trademark holders. The trademark holders do not
-- sponsor or endorse this work or any of its authors.
--
-- ==========================================================================
-- What this bench is
-- ==========================================================================
-- The SCLD under test, unmodified, wired into a minimal TC2068 and booted
-- with the real TC2068 HOME ROM and EXROM. It answers one question: does
-- the machine get from reset to the BASIC copyright screen?
--
-- REAL parts (instantiated, not modelled here):
--   SCLD            work.SCLD, whichever rtl/ is on the analysis path
--   Z80             T80a -- the asynchronous, bus-accurate T80 wrapper, so
--                   /MREQ, /IORQ, /RD and /WR move on the half-cycles a real
--                   Z80 moves them on. Clocked straight from SCLD CPUCLK_o,
--                   so clock stretching (contention) is the SCLD's own.
--   Video RAM       2x 4416 (mem_vram_16k / mem_4416), multiplexed address,
--                   row latched on /RAS, column on /CAS
--   Upper RAM       2 more 2x4416 banks, one per /CAS1 and /CAS2
--   Data buffer     74LS245 between the Z80 bus and the video RAM bus,
--                   /G = TS, DIR = RDN  (hct245)
--
-- MODELLED here, and what was assumed. None of this is taken from a TC2068
-- netlist; it is a reconstruction, and it is the part of this bench to
-- distrust first:
--   Address mux     MUX=1 selects the row  (A7RB, A6..A0),
--                   MUX=0 selects the column (A7RB, A13..A8, A0).
--                   Onto the video RAM address bus only while TS=0.
--   Upper RAM /RAS  taken from /MREQ.
--   ROMs            /CE = ROMCS (HOME) or EXROM, /OE = /RD. Note that
--                   neither chip sees /MREQ: a chip select that is low
--                   during an I/O read makes the ROM drive the bus.
--   /INT            open drain with a pull-up.
--   Floating bus    reads as FFh.
--
-- NOT covered: anything electrical. Boards that replace the 74LS245 with
-- series resistors, NMOS-versus-CMOS Z80 margins, DRAM access times and the
-- drive strength of /INT are all outside what this bench can say.
-- ==========================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
--SIMCTL use work.scldpkg.all;

entity tb_tc2068_boot is
  generic (
    SIM_MS      : integer := 2000;
    HZ50        : boolean := true;    -- false: 60 Hz, 262 lines
    HOME_ROM    : string  := "tc2068-0.rom";
    EX_ROM      : string  := "tc2068-1.rom";
    FRAME_FILE  : string  := "frame.txt";
    IO_LOG_MAX  : integer := 60
  );
end entity tb_tc2068_boot;

architecture sim of tb_tc2068_boot is

  constant CLK_HALF : time := 35431 ps;   -- 14.112 MHz

  type rom_t is array (natural range <>) of std_logic_vector(7 downto 0);

  impure function load_rom(name : string; size : natural) return rom_t is
    type bin_t is file of character;
    file f      : bin_t open read_mode is name;
    variable r  : rom_t(0 to size - 1) := (others => x"FF");
    variable c  : character;
  begin
    for i in 0 to size - 1 loop
      exit when endfile(f);
      read(f, c);
      r(i) := std_logic_vector(to_unsigned(character'pos(c), 8));
    end loop;
    return r;
  end function;

  signal home_rom_c : rom_t(0 to 16383) := load_rom(HOME_ROM, 16384);
  signal ex_rom_c   : rom_t(0 to 8191)  := load_rom(EX_ROM, 8192);

  signal clk14      : std_logic := '0';
  signal p5060      : std_logic;
  signal reset_n    : std_logic := '0';
  signal running    : boolean := true;

  -- Z80
  signal cpuclk     : std_logic;
  signal a          : std_logic_vector(15 downto 0);
  signal d          : std_logic_vector(7 downto 0);
  signal m1_n, mreq_n, iorq_n, rd_n, wr_n, rfsh_n : std_logic;
  signal int_n      : std_logic;

  -- SCLD
  signal ras, cas, ts, rdn, mux, cas1, cas2, mwe : std_logic;
  signal ma_o       : std_logic_vector(7 downto 0);
  signal ma_oe      : std_logic;
  signal a7rb       : std_logic;
  signal romcs, roscs, exrom : std_logic;
  signal scld_d     : std_logic_vector(7 downto 0);
  signal scld_d_oe  : std_logic;
  signal int_oe     : std_logic;
  signal r_o, g_o, b_o, bright_o, csync : std_logic;
  --SIMCTL signal simcontrol : simcontrol_in_type := (cmd => NONE, data => x"00");

  -- Video RAM side
  signal vd         : std_logic_vector(7 downto 0);
  signal vd_x01     : std_logic_vector(7 downto 0);
  signal vma        : std_logic_vector(7 downto 0);
  signal vram_q     : std_logic_vector(7 downto 0);
  signal vram_oe    : std_logic;

  -- Board address multiplexer
  signal bmux       : std_logic_vector(7 downto 0);

  -- Upper RAM
  signal ram1_q, ram2_q   : std_logic_vector(7 downto 0);
  signal ram1_oe, ram2_oe : std_logic;

  signal rom_oe, exrom_oe : boolean;
  signal d_driven         : boolean;

  signal d_read           : std_logic_vector(7 downto 0) := x"00";
  signal rd_rom, rd_ex, rd_245, rd_ram : boolean := false;

  function hex(v : std_logic_vector) return string is
    constant digits : string(1 to 16) := "0123456789ABCDEF";
    variable s  : string(1 to v'length / 4);
    variable x  : std_logic_vector(v'length - 1 downto 0) := v;
    variable n  : std_logic_vector(3 downto 0);
  begin
    for i in s'range loop
      n := x(x'length - 1 - (i - 1) * 4 downto x'length - i * 4);
      if is_x(n) then
        s(i) := 'X';
      else
        s(i) := digits(to_integer(unsigned(n)) + 1);
      end if;
    end loop;
    return s;
  end function;

begin

  clk14   <= not clk14 after CLK_HALF when running else '0';
  p5060   <= '1' when HZ50 else '0';   -- SCLD: '1' is 312 lines, '0' is 262
  reset_n <= '1' after 50 us;

  -- ------------------------------------------------------------------ Z80
  u_cpu : entity work.T80a
    generic map (Mode => 0, IOWait => 1)
    port map (
      RESET_n   => reset_n,
      R800_mode => '0',
      CLK_n     => cpuclk,
      WAIT_n    => '1',
      INT_n     => int_n,
      NMI_n     => '1',
      BUSRQ_n   => '1',
      M1_n      => m1_n,
      MREQ_n    => mreq_n,
      IORQ_n    => iorq_n,
      RD_n      => rd_n,
      WR_n      => wr_n,
      RFSH_n    => rfsh_n,
      HALT_n    => open,
      BUSAK_n   => open,
      A         => a,
      D         => d
    );

  int_n <= '0' when int_oe = '1' else '1';

  -- ----------------------------------------------------------------- SCLD
  vd_x01 <= to_x01(vd);

  u_scld : entity work.SCLD
    port map (
      --SIMCTL simcontrol => simcontrol,
      SCLD_CLK  => clk14,
      A_i       => a,
      D_i       => vd_x01,
      KB_i      => "11111",
      TPIN_i    => '0',
      MREQ_i    => mreq_n,
      IORQ_i    => iorq_n,
      RD_i      => rd_n,
      WR_i      => wr_n,
      RFSH_i    => rfsh_n,
      P5060_i   => p5060,
      BE_i      => '1',
      RAS_o     => ras,
      CAS_o     => cas,
      TS_o      => ts,
      RDN_o     => rdn,
      MUX_o     => mux,
      CAS2_o    => cas2,
      CAS1_o    => cas1,
      MWE_o     => mwe,
      CPUCLK_o  => cpuclk,
      CPUCLKB_o => open,
      CSYNC_o   => csync,
      TPOUT_o   => open,
      MA_o      => ma_o,
      MA_oe_o   => ma_oe,
      R_o       => r_o,
      G_o       => g_o,
      B_o       => b_o,
      BRIGHT_o  => bright_o,
      A7RB_o    => a7rb,
      ROMCS_o   => romcs,
      ROSCS_o   => roscs,
      EXROM_o   => exrom,
      AYCLK_o   => open,
      BC1_o     => open,
      BDIR_o    => open,
      D_o       => scld_d,
      D_oe_o    => scld_d_oe,
      INT_oe_o  => int_oe,
      HSYNC_o   => open,
      VSYNC_o   => open
    );

  -- ---------------------------------------------- board address multiplexer
  bmux <= a7rb & a(6 downto 0) when mux = '1' else
          a7rb & a(13 downto 8) & a(0);

  vma <= ma_o when ma_oe = '1' else
         bmux when ts = '0'    else
         (others => 'H');

  -- ------------------------------------------------- 74LS245 and video RAM
  u_245 : entity work.hct245
    port map (a => d, b => vd, dir => rdn, oe_n => ts);

  u_vram : entity work.mem_vram_16k
    port map (
      addr     => vma,
      ras_n    => ras,
      cas_n    => cas,
      we_n     => mwe,
      data_in  => vd,
      data_out => vram_q,
      data_oe  => vram_oe
    );

  vd <= vram_q when vram_oe = '1' else (others => 'Z');
  vd <= scld_d when scld_d_oe = '1' else (others => 'Z');
  vd <= (others => 'H');

  -- ------------------------------------------------------------ upper RAM
  u_ram1 : entity work.mem_vram_16k     -- 8000h-BFFFh
    port map (
      addr => bmux, ras_n => mreq_n, cas_n => cas1, we_n => wr_n,
      data_in => d, data_out => ram1_q, data_oe => ram1_oe
    );

  u_ram2 : entity work.mem_vram_16k     -- C000h-FFFFh
    port map (
      addr => bmux, ras_n => mreq_n, cas_n => cas2, we_n => wr_n,
      data_in => d, data_out => ram2_q, data_oe => ram2_oe
    );

  d <= ram1_q when ram1_oe = '1' else (others => 'Z');
  d <= ram2_q when ram2_oe = '1' else (others => 'Z');

  -- ----------------------------------------------------------------- ROMs
  rom_oe   <= romcs = '0' and rd_n = '0';
  exrom_oe <= exrom = '0' and rd_n = '0';

  d <= home_rom_c(to_integer(unsigned(a(13 downto 0)))) when rom_oe and not is_x(a)
       else (others => 'Z');
  d <= ex_rom_c(to_integer(unsigned(a(12 downto 0)))) when exrom_oe and not is_x(a)
       else (others => 'Z');

  -- A floating bus reads FFh. T80 decodes its instruction register straight
  -- from the pins, so an undriven read is forced to a strong value.
  d_driven <= rom_oe or exrom_oe or ram1_oe = '1' or ram2_oe = '1'
              or (ts = '0' and rdn = '0' and (vram_oe = '1' or scld_d_oe = '1'));
  d <= (others => '1') when rd_n = '0' and not d_driven else (others => 'Z');
  d <= (others => 'H');

  -- ============================================================== monitors

  -- What the Z80 actually latches on a read: the bus at the falling clock
  -- edge of the last T-state with /RD low (T80a samples there). Looking at
  -- the bus as /RD rises instead would catch the 245 turning around.
  p_sample : process(cpuclk)
  begin
    if falling_edge(cpuclk) and rd_n = '0' then
      d_read <= to_x01(d);
      rd_rom <= rom_oe;
      rd_ex  <= exrom_oe;
      rd_245 <= ts = '0' and rdn = '0';
      rd_ram <= ram1_oe = '1' or ram2_oe = '1';
    end if;
  end process;

  -- Port FFh / F4h traffic as the Z80 sees it, and a check the ROM itself
  -- relies on: what was last written to a port is what reads back.
  p_io : process(rd_n, wr_n)
    variable n      : integer := 0;
    variable bad    : integer := 0;
    variable l      : line;
    variable ff, f4 : std_logic_vector(7 downto 0) := x"00";
    variable want   : std_logic_vector(7 downto 0);
    variable is_in  : boolean;
    variable v      : std_logic_vector(7 downto 0);
  begin
    if iorq_n = '0' and m1_n = '1' and (a(7 downto 0) = x"FF" or a(7 downto 0) = x"F4")
       and (rising_edge(rd_n) or falling_edge(wr_n)) then
      is_in := rd_n'event;
      if a(0) = '1' then want := ff; else want := f4; end if;
      if is_in then v := d_read; else v := to_x01(d); end if;
      n := n + 1;
      if n <= IO_LOG_MAX or (is_in and v /= want and bad < 20) then
        if is_in then write(l, string'("IO  IN  ")); else write(l, string'("IO  OUT ")); end if;
        write(l, hex(a(7 downto 0)) & " = " & hex(v));
        if is_in and v /= want then
          bad := bad + 1;
          write(l, string'("  <-- READBACK MISMATCH, last written ") & hex(want));
        end if;
        write(l, string'("   A=") & hex(a) & "   @ ");
        write(l, now);
        writeline(output, l);
      end if;
      if not is_in then
        if a(0) = '1' then ff := v; else f4 := v; end if;
      end if;
    end if;
  end process;

  -- Undefined data latched by the Z80. With two or more outputs enabled it
  -- is a bus fight. With one, the byte was stored undefined in the first
  -- place: T80 does not initialise its registers, so the ROM pushing one it
  -- has not loaded yet writes 'U' -- see p_undef_wr. Only the first is a
  -- fault of the logic under test.
  p_fight : process(rd_n)
    variable n, m, drv : integer := 0;
    variable l : line;
  begin
    if rising_edge(rd_n) and reset_n = '1' and is_x(d_read) then
      drv := 0;
      if rd_rom then drv := drv + 1; end if;
      if rd_ex  then drv := drv + 1; end if;
      if rd_245 then drv := drv + 1; end if;
      if rd_ram then drv := drv + 1; end if;
      if drv >= 2 then
        n := n + 1;
      else
        m := m + 1;
      end if;
      if (drv >= 2 and n <= 20) or (drv < 2 and m <= 4) then
        if drv >= 2 then
          write(l, string'("BUS FIGHT  A="));
        else
          write(l, string'("undefined byte read back  A="));
        end if;
        write(l, hex(a) & " D=" & hex(d_read));
        if iorq_n = '0' then write(l, string'(" (I/O read)")); else write(l, string'(" (memory read)")); end if;
        if rd_rom then write(l, string'(" HOME-ROM")); end if;
        if rd_ex  then write(l, string'(" EXROM")); end if;
        if rd_245 then write(l, string'(" 245")); end if;
        if rd_ram then write(l, string'(" RAM")); end if;
        write(l, string'("   @ ")); write(l, now);
        writeline(output, l);
      end if;
    end if;
  end process;

  -- The Z80 writing a byte it never defined.
  p_undef_wr : process(wr_n)
    variable n : integer := 0;
    variable l : line;
  begin
    if falling_edge(wr_n) and mreq_n = '0' and is_x(to_x01(d)) then
      n := n + 1;
      if n <= 4 then
        write(l, string'("Z80 wrote an undefined byte  A=") & hex(a) & " D=" & hex(to_x01(d)) & "   @ ");
        write(l, now);
        writeline(output, l);
      end if;
    end if;
  end process;

  -- Progress: where the Z80 is, and whether it is taking interrupts.
  p_progress : process
    variable l       : line;
    variable acks    : integer := 0;
    variable fetches : integer := 0;
    variable pc      : std_logic_vector(15 downto 0) := (others => '0');
    variable t_next  : time := 100 ms;
  begin
    wait on m1_n, iorq_n, mreq_n;
    if falling_edge(iorq_n) and m1_n = '0' then acks := acks + 1; end if;
    if falling_edge(mreq_n) and m1_n = '0' then fetches := fetches + 1; pc := a; end if;
    if now >= t_next then
      write(l, string'("T+")); write(l, now / 1 ms); write(l, string'(" ms  PC=") & hex(pc));
      write(l, string'("  opcode fetches=")); write(l, fetches);
      write(l, string'("  interrupts taken=")); write(l, acks);
      writeline(output, l);
      t_next := t_next + 100 ms;
    end if;
  end process;

  -- A little over one frame of video, exactly as the SCLD emits it, taken
  -- from the end of the run. One character per 14 MHz clock: a hex digit
  -- (I G R B), or 's' while composite sync is low. sim/frame2png.py finds
  -- the line and frame boundaries from the sync characters.
  p_frame : process
    file f       : text;
    variable l   : line;
    variable px  : std_logic_vector(3 downto 0);
    variable n   : integer := 0;
    constant digits : string(1 to 16) := "0123456789ABCDEF";
  begin
    wait for (SIM_MS - 42) * 1 ms;
    file_open(f, FRAME_FILE, write_mode);
    loop
      wait until rising_edge(clk14);
      exit when not running;
      px := to_x01(bright_o) & to_x01(g_o) & to_x01(r_o) & to_x01(b_o);
      if csync = '0' then
        write(l, character'('s'));
      elsif is_x(px) then
        write(l, character'('x'));
      else
        write(l, digits(to_integer(unsigned(px)) + 1));
      end if;
      n := n + 1;
      if n = 4096 then
        writeline(f, l);
        n := 0;
      end if;
    end loop;
    writeline(f, l);
    file_close(f);
    wait;
  end process;

  p_stop : process
  begin
    wait for SIM_MS * 1 ms;
    running <= false;
    report "end of simulation" severity note;
    wait;
  end process;

end architecture sim;
