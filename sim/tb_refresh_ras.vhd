--
-- A Z80 refresh cycle gives the video RAM a whole RAS pulse or none.
--
-- The SCLD passes Z80 refresh cycles to the video RAM only outside its own
-- fetch window. The bench plays three refresh cycles into the SCLD, with the
-- bus timing of a Z80 whose /MREQ rises MREQ_DELAY after the clock edge, and
-- measures every RAS pulse:
--
--   well outside the window        one full pulse
--   across the 511 -> 512 edge     no pulse at all
--   across the 895 -> 0 edge       one full pulse
--
-- A pulse that starts or ends at the edge instead of with the cycle is
-- shorter than a full one, and fails the check.
--
-- Lines marked --SIMCTL are enabled by run_refresh_ras.sh when the SCLD has
-- its simulation-only 'simcontrol' port.
--
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
--SIMCTL use work.scldpkg.all;

entity tb_refresh_ras is
end entity tb_refresh_ras;

architecture sim of tb_refresh_ras is

  constant CLK_HALF   : time    := 35 ns;      -- 14 MHz
  constant H_TOTAL    : natural := 896;        -- 14 MHz clocks per line
  constant MREQ_DELAY : time    := 30 ns;      -- Z80 clock edge to /MREQ high
  -- /MREQ is low for one CPU clock period; RAS follows half-way through it
  constant FULL_PULSE : time    := 4 * CLK_HALF + MREQ_DELAY;

  --SIMCTL signal simcontrol : simcontrol_in_type := (cmd => NONE, data => x"00");
  signal clk     : std_logic := '0';
  signal mreq_n  : std_logic := '1';
  signal rfsh_n  : std_logic := '1';
  signal ras     : std_logic;
  signal ts      : std_logic;
  signal cnt     : natural := 0;     -- 14 MHz clocks since the start
  signal pulses  : natural := 0;     -- RAS pulses seen with TS low
  signal width   : time := 0 ns;     -- width of the last one
  signal done    : boolean := false;

begin

  clk <= not clk after CLK_HALF when not done else '0';

  -- The SCLD's counters start at line 0, count 0, and advance on this edge.
  process(clk)
  begin
    if falling_edge(clk) then
      cnt <= cnt + 1;
    end if;
  end process;

  dut: entity work.scld
    port map (
      --SIMCTL simcontrol => simcontrol,
      SCLD_CLK  => clk,
      A_i       => x"0000",
      D_i       => x"00",
      KB_i      => "11111",
      TPIN_i    => '0',
      MREQ_i    => mreq_n,
      IORQ_i    => '1',
      RD_i      => '1',
      WR_i      => '1',
      RFSH_i    => rfsh_n,
      P5060_i   => '1',
      BE_i      => '1',
      RAS_o     => ras,
      TS_o      => ts
    );

  -- Every RAS pulse the video RAM sees from the CPU side
  process
    variable t0 : time;
  begin
    wait until falling_edge(ras);
    if ts = '0' then
      t0 := now;
      wait until rising_edge(ras);
      width  <= now - t0;
      pulses <= pulses + 1;
    end if;
  end process;

  process
    variable bad : natural := 0;

    -- One refresh cycle, /RFSH falling when the line counter reads 'start'
    -- (a rising edge of the CPU clock: counts 2, 6, 10 ...).
    procedure refresh(line, start : natural) is
      constant base : natural := line * H_TOTAL + start;
    begin
      wait until cnt = base;      rfsh_n <= '0';
      wait until cnt = base + 2;  mreq_n <= '0';
      wait until cnt = base + 6;
      wait for MREQ_DELAY;        mreq_n <= '1';
      wait until cnt = base + 8;  rfsh_n <= '1';
      wait until cnt = base + 12;
    end procedure;

    procedure expect(what : string; n_before, n_want : natural) is
    begin
      if pulses - n_before /= n_want then
        bad := bad + 1;
        report what & ": " & integer'image(pulses - n_before)
             & " RAS pulse(s), want " & integer'image(n_want) severity error;
      elsif n_want = 1 and width /= FULL_PULSE then
        bad := bad + 1;
        report what & ": RAS pulse of " & time'image(width) & ", want "
             & time'image(FULL_PULSE) severity error;
      else
        report what & ": ok" severity note;
      end if;
    end procedure;

    variable n0 : natural;
  begin
    n0 := pulses;
    refresh(2, 598);
    expect("refresh outside the window (counts 598-606)", n0, 1);

    n0 := pulses;
    refresh(3, 506);
    expect("refresh across 511->512", n0, 0);

    n0 := pulses;
    refresh(4, 890);
    expect("refresh across 895->0", n0, 1);

    if bad = 0 then
      report "PASS: every refresh RAS pulse is whole" severity note;
    else
      report "FAIL: " & integer'image(bad) & " of 3 cases wrong" severity error;
    end if;
    done <= true;
    wait;
  end process;

end architecture sim;
