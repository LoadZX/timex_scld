--
-- TIMEX(tm) SCLD timing
--
--  (c) by Load ZX Museum <curator@loadzx.com>
--  (c) by Alvaro Lopes <alvieboy@alvie.com>
--  (c) by Paulo Cortesao <cortesao.paulo@outlook.pt>
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

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.numeric_std.all;

entity scld_timing is
  generic (
    ENABLE_FLASH: boolean := false;
    FLASH_BIT   : natural := 4
  );
  port (
    scldclk_i       : in std_logic;
    p5060_i         : in std_logic;
    contention_i    : in std_logic;

    vdisplay_o      : out std_logic;
    hdisplay_o      : out std_logic;
    hblank_o        : out std_logic;
    hcounter_o      : out unsigned(9 downto 0);
    vcounter_o      : out unsigned(8 downto 0);
    flash_o         : out std_logic;
    csync_o         : out std_logic;
    prevsync_o      : out std_logic;

    cpuclk_o        : out std_logic;
    cpuclkb_o       : out std_logic;
    ayclk_o         : out std_logic
  );
end entity scld_timing;

architecture beh of scld_timing is

  signal hcounter_max_s           : unsigned(9 downto 0);
  signal vcounter_max_s           : unsigned(8 downto 0);

  -- Registers
  signal hcounter_r               : unsigned(9 downto 0) := (others => '0');
  signal hoverflow                : boolean;
  signal hpreoverflow             : boolean;

  signal vcounter_r               : unsigned(8 downto 0) := (others => '0');
  signal cpuclk_r                 : std_logic := '0';

  -- Flash
  signal flash_r                  : unsigned(FLASH_BIT downto 0) := (others => '0');

  -- Syncs
  signal next_vcounter_s          : unsigned(8 downto 0);
  signal prevsync_s               : std_logic;
  signal prehsync_s               : std_logic;
  signal csync_r                  : std_logic := '1';

begin

  hcounter_max_s            <= to_unsigned(895,hcounter_max_s'length);

  vcounter_max_s            <= to_unsigned(311,vcounter_max_s'length) when P5060_i='1' else
                               to_unsigned(261,vcounter_max_s'length);


  -- Horizontal counter
  
  hoverflow <= hcounter_r=hcounter_max_s;
  hpreoverflow <= hcounter_r=(hcounter_max_s-1);

  process(scldclk_i)
  begin
    if falling_edge(scldclk_i) then
      if hoverflow then
        hcounter_r <= (others => '0');
      else
        hcounter_r <= hcounter_r + 1;
      end if;
    end if;
  end process;

  -- Vertical counter.
  -- Note that vertical counter increases before the horizontal counter
  -- changes.

  next_vcounter_s <= vcounter_r + 1;

  process(scldclk_i)
  begin
    if falling_edge(scldclk_i) then
      if hpreoverflow then
        if vcounter_r=vcounter_max_s then
          vcounter_r <= (others => '0');
          --flash_r <= flash_r + 1;
        else
          vcounter_r <= next_vcounter_s;
        end if;
      end if;
    end if;
  end process;

  process(flash_r, vcounter_r(8))
  begin
    if falling_edge(vcounter_r(8)) then
      flash_r(0) <= not flash_r(0);
    end if;
  end process;

  l: for i in 1 to FLASH_BIT generate
  process(flash_r(i-1))
  begin
      if falling_edge(flash_r(i-1)) then
        flash_r(i) <= not flash_r(i);
      end if;
  end process;
  end generate;

  process(scldclk_i)
  begin
    if falling_edge(scldclk_i) then
      if hcounter_r(0)='1' then
        if contention_i='0' then
          cpuclk_r <= not hcounter_r(1);
        else
          cpuclk_r <= '1';
        end if;
      end if;
    end if;
  end process;

  process(hcounter_r)
    variable hc: unsigned(8 downto 0);
  begin
    hc := hcounter_r(9 downto 1);
    if hc >= 335 and hc<367 then    -- ULA is 344/375
      prehsync_s <= '0';
    else
      prehsync_s <= '1';
    end if;
  end process;


  process(scldclk_i)
  begin
    if falling_edge(scldclk_i) then
      if hcounter_r(0)='1' then
        csync_r <= prehsync_s xor prevsync_s;
      end if;
    end if;
  end process;

  -- 50/60Hz.
  prevsync_s  <= '1' when vcounter_r(7 downto 2)="111"&p5060_i&p5060_i&"0" else '0';


  -- OUTPUTS
  hdisplay_o  <= '1' when hcounter_r<536 and hcounter_r>23 else '0';
  hblank_o    <= '1' when hcounter_r>=640 and hcounter_r<832 else '0';
  vdisplay_o  <= '1' when vcounter_r<192 else '0';
  hcounter_o  <= hcounter_r;
  vcounter_o  <= vcounter_r;

  cpuclk_o    <= cpuclk_r;
  cpuclkb_o   <= not cpuclk_r;
  ayclk_o     <= hcounter_r(2);
  flash_o     <= flash_r(FLASH_BIT) when ENABLE_FLASH else '0';
  csync_o     <= csync_r;
  prevsync_o  <= prevsync_s;

end beh;
