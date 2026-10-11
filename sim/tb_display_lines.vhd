--
-- The SCLD takes the video RAM, and holds the CPU off it, on the 192 display
-- lines only.
--
-- The SCLD runs for one frame with 4000h parked on the address bus and no
-- request active, which is enough to be contended: contention looks at the
-- address, not at /MREQ. Per scanline the bench counts
--
--   TS pulses        16 on a display line, 0 on a border or blanking line
--   CPUCLK periods   224 when nothing is stretched, fewer when the CPU is held
--
-- and fails unless the first 192 lines are contended and the rest are not.
--
-- Lines marked --SIMCTL are enabled by run_display_lines.sh when the SCLD has
-- its simulation-only 'simcontrol' port.
--
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
--SIMCTL use work.scldpkg.all;

entity tb_display_lines is
  generic (
    HZ50 : boolean := true    -- false: 60 Hz, 262 lines
  );
end entity tb_display_lines;

architecture sim of tb_display_lines is

  constant CLK_HALF  : time    := 35 ns;      -- 14 MHz
  constant H_TOTAL   : natural := 896;        -- 14 MHz clocks per line
  constant V_DISPLAY : natural := 192;

  --SIMCTL signal simcontrol : simcontrol_in_type := (cmd => NONE, data => x"00");
  signal clk     : std_logic := '0';
  signal p5060   : std_logic;
  signal ts      : std_logic;
  signal cpuclk  : std_logic;
  signal done    : boolean := false;

  function v_total return natural is
  begin
    if HZ50 then return 312; else return 262; end if;
  end function;

begin

  clk   <= not clk after CLK_HALF when not done else '0';
  p5060 <= '1' when HZ50 else '0';   -- SCLD: '1' is 312 lines, '0' is 262

  dut: entity work.scld
    port map (
      --SIMCTL simcontrol => simcontrol,
      SCLD_CLK  => clk,
      A_i       => x"4000",
      D_i       => x"00",
      KB_i      => "11111",
      TPIN_i    => '0',
      MREQ_i    => '1',
      IORQ_i    => '1',
      RD_i      => '1',
      WR_i      => '1',
      RFSH_i    => '1',
      P5060_i   => p5060,
      BE_i      => '1',
      TS_o      => ts,
      CPUCLK_o  => cpuclk
    );

  process
    variable ts_prev, ck_prev : std_logic;
    variable n_ts, n_ck       : natural;
    variable bad              : natural := 0;
    variable ts_frame         : natural := 0;
  begin
    -- The counters start at line 0, count 0, and advance on the falling edge.
    ts_prev := '0';
    ck_prev := '0';
    for line in 0 to v_total - 1 loop
      n_ts := 0;
      n_ck := 0;
      for i in 1 to H_TOTAL loop
        wait until falling_edge(clk);
        wait for 1 ns;
        if ts = '1' and ts_prev = '0' then n_ts := n_ts + 1; end if;
        if cpuclk = '1' and ck_prev = '0' then n_ck := n_ck + 1; end if;
        ts_prev := ts;
        ck_prev := cpuclk;
      end loop;
      ts_frame := ts_frame + n_ts;

      if line < V_DISPLAY then
        if n_ts /= 16 or n_ck >= 224 then
          bad := bad + 1;
          report "display line " & integer'image(line) & ": TS pulses="
               & integer'image(n_ts) & " (want 16), CPUCLK periods="
               & integer'image(n_ck) & " (want fewer than 224)" severity error;
        end if;
      else
        if n_ts /= 0 or n_ck /= 224 then
          bad := bad + 1;
          report "border line " & integer'image(line) & ": TS pulses="
               & integer'image(n_ts) & " (want 0), CPUCLK periods="
               & integer'image(n_ck) & " (want 224)" severity error;
        end if;
      end if;
    end loop;

    report "TS pulses in the frame: " & integer'image(ts_frame)
         & " (192 lines x 16 = 3072)" severity note;
    if bad = 0 then
      report "PASS: video RAM taken and CPU held on the 192 display lines only"
        severity note;
    else
      report "FAIL: " & integer'image(bad) & " of " & integer'image(v_total)
           & " lines wrong" severity error;
    end if;
    done <= true;
    wait;
  end process;

end architecture sim;
