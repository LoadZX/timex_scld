--
-- TIMEX(tm) SCLD 2068 Model
--
--  (c) by Load ZX Museum <curator@loadzx.com>
--  (c) by Alvaro Lopes <alvieboy@alvie.com>
--  (c) by Paulo Cortesao <cortesao.paulo@outlook.pt>
--
-- This TIMEX(tm) SCLD 2068 Model is licensed under a
-- Creative Commons Attribution-ShareAlike 4.0 International License.
--
-- You should have received a copy of the license along with this
-- work. If not, see <https://creativecommons.org/licenses/by-sa/4.0/>.
--
-- TIMEX is a trademark of TIMEX GROUP USA, INC
--
-- The authors of this work are not affiliated, sponsored or have any
-- partnership with the trademark holders. The trademark holders do not
-- sponsor or endorse this work or any of its authors
--


library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.numeric_std.all;
use IEEE.std_logic_misc.all;
library work;
-- synthesis translate_off
use work.SCLDPKG.all;
use work.txt_util.all;
-- synthesis translate_on

entity SCLD is
  port (
    -- synthesis translate_off
    simcontrol    : in simcontrol_in_type;
    -- synthesis translate_on
    SCLD_CLK      : in std_logic;
    A_i           : in std_logic_vector(15 downto 0);
    D_i           : in std_logic_vector(7 downto 0);
    KB_i          : in std_logic_vector(4 downto 0);
    TPIN_i        : in std_logic;
    MREQ_i        : in std_logic;
    IORQ_i        : in std_logic;
    RD_i          : in std_logic;
    WR_i          : in std_logic;
    RFSH_i        : in std_logic;
    P5060_i       : in std_logic;
    BE_i          : in std_logic; --TBD
    RAS_o         : out std_logic;
    CAS_o         : out std_logic;
    TS_o          : out std_logic;
    RDN_o         : out std_logic;
    MUX_o         : out std_logic;
    CAS2_o        : out std_logic;
    CAS1_o        : out std_logic;
    MWE_o         : out std_logic;
    CPUCLK_o      : out std_logic;
    CPUCLKB_o     : out std_logic;
    CSYNC_o       : out std_logic;
    TPOUT_o       : out std_logic;
    MA_o          : out std_logic_vector(7 downto 0);
    MA_oe_o       : out std_logic;
    R_o           : out std_logic;
    G_o           : out std_logic;
    B_o           : out std_logic;
    BRIGHT_o      : out std_logic;
    A7RB_o        : out std_logic;
    ROMCS_o       : out std_logic;
    ROSCS_o       : out std_logic;
    EXROM_o       : out std_logic;
    AYCLK_o       : out std_logic;
    BC1_o         : out std_logic;
    BDIR_o        : out std_logic;
    D_o           : out std_logic_vector(7 downto 0);
    D_oe_o        : out std_logic;
    INT_oe_o      : out std_logic;  -- Interrupt is open-drain. When 1 here, it should output zero.

    -- Other misc outputs
    HSYNC_o       : out std_logic;
    VSYNC_o       : out std_logic
  );
end entity SCLD;

architecture sim of SCLD is

  -- 'X' for synthesis, '0' for simulation
  constant DONTCARE               : std_logic := '0';

  signal vdisplay_s               : std_logic;
  signal TS_s                     : std_logic;
  signal hblank_s                 : std_logic;
  signal dlatch_s                 : std_logic;
  signal alatch_s                 : std_logic;
  signal contention_s             : std_logic;
  signal ras_address_s            : std_logic_vector(7 downto 0);
  signal cas_attribute_address_s  : std_logic_vector(6 downto 1); -- 6 bits only
  signal cas_bitmap_address_s     : std_logic_vector(6 downto 1);
  signal CPUCLK_s                 : std_logic;
  signal CPUCLKB_s                : std_logic;
  signal ayclk_s                  : std_logic;
  signal MA_s                     : std_logic_vector(7 downto 0);

  signal prevsync_s               : std_logic;
  signal VRAM_address_s           : std_logic;
  signal EXTRAM_address_s         : std_logic;

  signal hcounter_s               : unsigned(9 downto 0);
  signal vcounter_s               : unsigned(8 downto 0);
  signal flash_s                  : std_logic;

  signal CAS_r                    : std_logic := '1';
  signal CAS1_r                   : std_logic := '1';
  signal CAS2_r                   : std_logic := '1';
  signal RAS_r                    : std_logic := '1';

  signal csync_s                  : std_logic;
  signal shreg_r                  : std_logic_vector(11 downto 0);
  signal bitmap_data_r            : std_logic_vector(7 downto 0);
  signal MUX_r                    : std_logic := '1';
  signal A6_r                     : std_logic := '1';
  signal A7RB_r                   : std_logic := '1';
  signal RFSH_r                   : std_logic := '1';
                                  
  signal MUXDLY_r                 : std_logic := '1';
  signal MREQ_dly_r               : std_logic := '1';
  -- port FF registers
  signal screenmode_s             : std_logic_vector(2 downto 0);
  signal hirescolor_s             : std_logic_vector(2 downto 0);
  signal disableint_s             : std_logic;
  signal bank_s                   : std_logic; -- 0: dock, 1: exrom.

  -- port FE registers
  signal border_s                 : std_logic_vector(2 downto 0);
  signal ear_s                    : std_logic;

  -- port F4 registers
  signal banksel_s                : std_logic_vector(7 downto 0) := (others => '0'); -- '0': HOME, '1': DOCK/EXROM


  signal shreg_data_in_s          : std_logic_vector(7 downto 0);
  signal attr_r                   : std_logic_vector(7 downto 0); -- Current attribute being used
  signal attr_q_r                 : std_logic_vector(7 downto 0); -- Latched attribute for odd positions


  signal R_r                      : std_logic;
  signal G_r                      : std_logic;
  signal B_r                      : std_logic;
  signal BRIGHT_r                 : std_logic;
  signal request_wr_cleanup_r     : std_logic := '1';
  signal request_wr_cleanup2_r    : std_logic := '1';


  signal aload_s                  : std_logic;
  signal dload_s                  : std_logic;

  signal hdisplay_s               : std_logic;
  signal nrequest_rd_s            : std_logic;

  signal RDN_s                    : std_logic;

  signal CASCPU_s                 : std_logic;
  signal current_banksel_s        : std_logic;
  signal refresh_ras_s            : std_logic;

  signal bdir_s                   : std_logic;
  signal bc1_s                    : std_logic;
  signal bank_index_s             : std_logic_vector(2 downto 0);
  signal internal_io_port_s       : std_logic;

  alias highresmode_s             : std_logic is screenmode_s(2);
  alias highcolor_s               : std_logic is screenmode_s(1);
  alias altscreen_s               : std_logic is screenmode_s(0);

  constant OPTIMIZE_MA            : boolean := true;

begin

  -- -----------------------
  -- MISSING: flash support
  -- -----------------------

  process(A_i(15 downto 14))
  begin
    VRAM_address_s <= '0';
    EXTRAM_address_s <= '0';

    case A_i(15 downto 14) is
      when "00" => -- ROM  access  0x0000 -> 0x3FFF
      when "01" => -- VRAM access  0x4000 => 0x7FFF
        VRAM_address_s <= '1';
      when "10" | "11" => -- External RAM 0x8000 -> 0xFFFF
        EXTRAM_address_s <= '1';
      when others =>
    end case;
  end process;

  bank_index_s <= A_i(15 downto 13);

  current_banksel_s <= banksel_s( to_integer(unsigned(bank_index_s)) );

  -- CONTENTION module.
  contention_inst: entity work.scld_contention
  port map (
    clk_i         => SCLD_CLK,
    arst_i        => '0',--arst_s,
    hcounter_i    => hcounter_s,
    IORQ_i        => IORQ_i,
    MREQ_i        => MREQ_i,
    RD_i          => RD_i,
    WR_i          => WR_i,
    A_i           => A_i(15 downto 14),
    contention_o  => contention_s,
    nrequest_rd_o => nrequest_rd_s
  );

  -- Timing
  timing_inst: entity work.scld_timing
  generic map (
    ENABLE_FLASH => true,
    FLASH_BIT => 4
  )
  port map (
    scldclk_i       => SCLD_CLK,
    p5060_i         => P5060_i,
    contention_i    => contention_s, -- For CPU clock generation

    vdisplay_o      => vdisplay_s,
    hdisplay_o      => hdisplay_s,
    hblank_o        => hblank_s,
    hcounter_o      => hcounter_s,
    vcounter_o      => vcounter_s,
    csync_o         => csync_s,
    prevsync_o      => prevsync_s,
    flash_o         => flash_s,

    cpuclk_o        => CPUCLK_s,
    cpuclkb_o       => CPUCLKB_s,
    ayclk_o         => ayclk_s
  );

  -- Regs
  regs_inst: entity work.scld_regs
  port map (
    -- synthesis translate_off
    simcontrol    => simcontrol,
    -- synthesis translate_on
    clk_i         => SCLD_CLK,
    cpuclk_i      => CPUCLK_s,
    hcounter_i    => std_logic_vector(hcounter_s(1 downto 0)),
    D_i           => D_i,
    A_i           => A_i(7 downto 0),
    IORQ_i        => IORQ_i,
    WR_i          => WR_i,
    TS_i          => TS_s,
    screenmode_o  => screenmode_s,
    hirescolor_o  => hirescolor_s,
    disableint_o  => disableint_s,
    bank_o        => bank_s,
    border_o      => border_s,
    ear_o         => ear_s,
    banksel_o     => banksel_s
  );



  -- Write cleanup
  process(CPUCLK_s, IORQ_i)
  begin
    if IORQ_i='1' then
      request_wr_cleanup_r <= '1';
      request_wr_cleanup2_r <= '1';
    elsif rising_edge(CPUCLK_s) then
      if (IORQ_i='0') then
        if WR_i='0' then
          request_wr_cleanup_r <= '0';
          request_wr_cleanup2_r <= request_wr_cleanup_r;
        end if;
      end if;
    end if;
  end process;


  process(SCLD_CLK)
  begin
    if rising_edge(SCLD_CLK) then
      if hcounter_s(4)='0' or hcounter_s(9)='1' or vdisplay_s='0' then
        RAS_r <= '1';
      else
        case hcounter_s(2 downto 0) is
            when "001" | "010" | "011" | "100" | "101" | "110" => RAS_r <='0';
          when others => RAS_r <= '1';
        end case;
      end if;
    end if;
  end process;

  process(SCLD_CLK)
  begin
    if rising_edge(SCLD_CLK) then
      if hcounter_s(4)='0' or hcounter_s(9)='1' or vdisplay_s='0' then
        CAS_r <= '1';
      else
        case hcounter_s(2 downto 0) is
          when  "010" | "011" | "101" | "110" => CAS_r <='0';
          when others => CAS_r <= '1';
        end case;
      end if;
    end if;
  end process;

  process(hcounter_s)
  begin
    if hcounter_s(9)='1' then
      TS_s <= '0';
    else
      if hcounter_s(4)='1'  then
        TS_s<='1';
      else
        case hcounter_s(3 downto 1) is
          when "111" => TS_s<='1';
          when others => TS_s<='0';
        end case;
      end if;
    end if;
  end process;

  -- Bitmap data latching for 'odd' columns
  dlatch_s <= '1' when hcounter_s(4 downto 0) = "11011" else '0';
  process(SCLD_CLK)
  begin
    if falling_edge(SCLD_CLK) then
      if dlatch_s='1' then
        bitmap_data_r <= D_i;
      end if;
    end if;
  end process;

  -- Attribute data latching for 'odd' columns
  alatch_s <= '1' when hcounter_s(4 downto 0) = "11110" else '0';
  process(SCLD_CLK)
  begin
    if falling_edge(SCLD_CLK) then
      if alatch_s='1' then
        attr_q_r  <= D_i;
      end if;
    end if;
  end process;

  aload_s <= '1' when hcounter_s(3)='0' and hcounter_s(2 downto 0) = "110"  else '0';
  process(SCLD_CLK)
  begin
    if falling_edge(SCLD_CLK) then
      if aload_s='1' then
        if hcounter_s(4)='1' then
          attr_r <= D_i;
        else
          attr_r <= attr_q_r;
        end if;
      end if;
    end if;
  end process;


  -- Pixel data output
  dload_s <= '1' when (hcounter_s(3)='0' or highresmode_s='1') and hcounter_s(2 downto 0) = "011"  else '0';


  process(D_i, bitmap_data_r, hcounter_s, highresmode_s, attr_r)
  begin
    if highresmode_s='1' then
      case hcounter_s(4 downto 3) is
        when "10" =>
          shreg_data_in_s <= D_i;
        when "11" =>
          shreg_data_in_s <= attr_r;
        when "00" =>
          shreg_data_in_s <= bitmap_data_r;
        when others =>
          shreg_data_in_s <= attr_r;
      end case;
    else
      if hcounter_s(4)='1' then
        shreg_data_in_s <= D_i;
      else
        shreg_data_in_s <= bitmap_data_r;
      end if;
    end if;
  end process;

  process(SCLD_CLK)
  begin
    if falling_edge(SCLD_CLK) then
      if dload_s='1' then

        shreg_r(7 downto 0) <= shreg_data_in_s;

      elsif (hcounter_s(0)='0' or highresmode_s='1') then
        shreg_r(7 downto 0) <= shreg_r(6 downto 0) & '0';
      end if;

      if highresmode_s='1' then
        shreg_r(11 downto 8) <= shreg_r(10 downto 7);
      elsif hcounter_s(0)='0' then
        shreg_r(11 downto 10) <= shreg_r(10) & shreg_r(7);
        shreg_r(9 downto 8) <= (others => 'X');--shreg_r(8 downto 7);
      end if;

    end if;
  end process;

  process(SCLD_CLK)
    variable attr: std_logic_vector(7 downto 0);
    variable pixel: std_logic;
  begin
    if falling_edge(SCLD_CLK) then

      if highresmode_s='1' then
        attr(2 downto 0) := hirescolor_s;
        attr(5 downto 3) := not hirescolor_s;
        attr(6) := '0'; -- Bright
        attr(7) := '0'; -- Flash
        pixel := shreg_r(11);
      else
        attr := attr_r(7 downto 0);
        pixel := shreg_r(11);
      end if;

      if hcounter_s(0)='0' or highresmode_s='1' then
        if hdisplay_s='1' and vdisplay_s='1' then
          if (pixel xor (attr(7) and flash_s))='1'  then
            B_r <= attr(0);
            R_r <= attr(1);
            G_r <= attr(2);
          else
            B_r <= attr(3);
            R_r <= attr(4);
            G_r <= attr(5);
          end if;
          BRIGHT_r <= attr(6);
        else
          -- Check blanking
          --if hblank_s='1' then
          --  B_r <= '0';
          --  R_r <= '0';
          --  G_r <= '0';
          --else
            if highresmode_s='1' then
              B_r <= not hirescolor_s(0);
              R_r <= not hirescolor_s(1);
              G_r <= not hirescolor_s(2);
            else
              B_r <= border_s(0);
              R_r <= border_s(1);
              G_r <= border_s(2);
            end if;
          --end if;
          BRIGHT_r <= '0';
        end if;
      end if;
      -- Blank if vsync
      if prevsync_s='1' or hblank_s='1' then
        B_r <= '0';
        R_r <= '0';
        G_r <= '0';
        BRIGHT_r <='0';
      end if;
    end if;
  end process;


  --ras_address_s             <= std_logic_vector(vcounter_s(5 downto 3) & hcounter_s(8 downto 5) &
  --                                      (hcounter_s(3) or hcounter_s(2) or hcounter_s(1))); -- THIS IS SO UNCLEAR. There's no apparent reason
  --                                                                                          -- for not using only hcounter(3)

  ras_address_s             <= std_logic_vector(vcounter_s(5 downto 3) & hcounter_s(8 downto 5) & hcounter_s(3));

  cas_bitmap_address_s      <= std_logic_vector(altscreen_s & vcounter_s(7 downto 6) & vcounter_s(2 downto 0)); -- CAS bitmap MSB is dependent of AltScreen mode

  process(vcounter_s, highcolor_s, altscreen_s)
  begin
    if highcolor_s='0' then
      cas_attribute_address_s   <= std_logic_vector(altscreen_s & "110" & vcounter_s(7 downto 6)); -- CAS bitmap MSB is dependent of AltScreen mode
    else
      cas_attribute_address_s   <= std_logic_vector('1' & vcounter_s(7 downto 6) & vcounter_s(2 downto 0));
    end if;
  end process;

  process(hcounter_s, cas_bitmap_address_s, cas_attribute_address_s, ras_address_s)
  begin
    if OPTIMIZE_MA then
      MA_s <= (others => 'X');
    else
      MA_s <= ras_address_s;
    end if;

    if (hcounter_s(4)='1' and hcounter_s(9)='0') OR OPTIMIZE_MA then
      case hcounter_s(3 downto 1) is
        when "000" | "100" =>  -- RAS
          MA_s <= ras_address_s;
        when "001" | "101"=>
          MA_s(6 downto 1) <= cas_bitmap_address_s;
        when "010" | "011" | "110" | "111"=>
          MA_s(6 downto 1) <= cas_attribute_address_s;
        when others =>

      end case;
    end if;
  end process;


  process(CPUCLK_s, MREQ_i)
  begin
    if MREQ_i='1' then
      MUX_r   <= '1';
    elsif rising_edge(CPUCLK_s) then
      if current_banksel_s='0' then
        MUX_r <= not RFSH_i OR NOT BE_i;  -- TBC: do we need to use TS here to control loading? Don't think so.
      end if;
    end if;
  end process;


  process(CPUCLK_s, MREQ_i)
  begin
    if MREQ_i='1' then
      MREQ_dly_r   <= '1';
    elsif rising_edge(CPUCLK_s) then
      MREQ_dly_r <= '0';
    end if;
  end process;

  process(SCLD_CLK, RD_i, WR_i)
  begin
    if (RD_i AND WR_i)='1' then
      CAS1_r  <= '1';
      CAS2_r  <= '1';
    elsif falling_edge(SCLD_CLK) then
      IF BE_i='0' THEN
        CAS1_r <= '1';
        CAS2_r <= '1';
      ELSE
      if EXTRAM_address_s='1' then
        CAS1_r <= MUX_r or A_i(14);
        CAS2_r <= MUX_r or not A_i(14);
      end if;
      END IF;
    end if;
  end process;


  process(SCLD_CLK, MREQ_i)
  begin
    if MREQ_i='1' then
      MUXDLY_r <= '1';
    elsif falling_edge(SCLD_CLK) then
      MUXDLY_r <= MUX_r;
    end if;
  end process;

  -- OE control for Data

  process(IORQ_i, RD_i, TS_s, A_i)
  begin
    D_oe_o <= '0';
    if IORQ_i='0' and RD_i='0' and TS_s='0' then
      case A_i(7 downto 0) is
        when x"FE" =>    -- Keyboard, MIC
          D_oe_o <= '1';
        when others =>
      end case;
    end if;
  end process;

  internal_io_port_s <= '1' when A_i(7 downto 0)=x"FF"
                              or A_i(7 downto 0)=x"F4"
                              or A_i(7 downto 0)=x"FE"
                            else '0';

  process(MREQ_i, VRAM_address_s, RD_i, IORQ_i, nrequest_rd_s, A_i, current_banksel_s)
  begin
    if MREQ_i='0' and IORQ_i='1' then
      -- If bank is not mapped to HOME, do not enable RDN
      RDN_s <= (not VRAM_address_s) OR RD_i OR current_banksel_s;
    else
      RDN_s <= nrequest_rd_s OR not internal_io_port_s;
    end if;
  end process;

  process(VRAM_address_s, MREQ_i, RD_i, WR_i, MUXDLY_r)
  begin
    if VRAM_address_s='0' OR MREQ_i='1' then
      CASCPU_s <='1';
    else
      if (RD_i and WR_i)='1' then
        CASCPU_s <= '1';
      else
        CASCPU_s <= MUXDLY_r;
      end if;
    end if;
  end process;

  process(csync_s, hcounter_s, vcounter_s, disableint_s)
  begin
    INT_oe_o  <= '0';
    if csync_s='0' and disableint_s='0' then
      if vcounter_s(1 downto 0)="00" then
        if hcounter_s(9 downto 6)="0001" or hcounter_s(9 downto 6)="0010" then
          INT_oe_o <= '1';
        end if;
      end if;
    end if;
  end process;

  process(MREQ_i)
  begin
    if rising_edge(MREQ_i) then
      if RFSH_r='0' then
        if A6_r='1' and A_i(6)='0' then
          A7RB_r <= not A7RB_r;
        end if;
      end if;
    end if;
  end process;

  process(MREQ_i)
  begin
    if rising_edge(MREQ_i) then
      if RFSH_r='0' then
        A6_r <= A_i(6);
      end if;
    end if;
  end process;

  process(MREQ_i, RFSH_i)
  begin
    if RFSH_i='1' then
      RFSH_r <= '1';
    elsif falling_edge(MREQ_i) then
      RFSH_r <= '0';
    end if;
  end process;

  process(IORQ_i, A_i, RD_i, WR_i, request_wr_cleanup2_r)
  begin
    if IORQ_i='1' then
      bdir_s  <= '0';
    else
      case A_i(7 downto 0) is
        when x"F5" =>
          bdir_s <= request_wr_cleanup2_r AND  NOT (RD_i AND WR_i);
        when x"F6" =>
          bdir_s <= request_wr_cleanup2_r AND NOT WR_i;
        when others =>
          bdir_s <= '0';
      end case;
    end if;
  end process;

  process(IORQ_i, A_i, RD_i, WR_i, request_wr_cleanup2_r)
  begin
    if IORQ_i='1' then
      bc1_s  <= '0';
    else
      case A_i(7 downto 0) is
        when x"F5" =>
          bc1_s <= request_wr_cleanup2_r AND  NOT (RD_i AND WR_i);
        when x"F6" =>
          bc1_s <= NOT RD_i;
        when others =>
          bc1_s <= '0';
      end case;
    end if;
  end process;

  process(hcounter_s, MREQ_dly_r, RFSH_i)
  begin
    refresh_ras_s <= (RFSH_i OR MREQ_dly_r OR NOT hcounter_s(9));
  end process;

  RAS_o     <= RAS_r when TS_s='1' else
      (MREQ_i or not VRAM_address_s) AND refresh_ras_s;


  CAS_o     <= CAS_r when TS_s='1' else CASCPU_s;

  CPUCLK_o  <= CPUCLK_s;
  CPUCLKB_o <= CPUCLKB_s;
  MUX_o     <= MUX_r;
  MWE_o     <= (not VRAM_address_s) or TS_s or WR_i or MREQ_i or current_banksel_s or NOT BE_i;
  MA_o      <= MA_s;
  RDN_o     <= RDN_s OR NOT BE_i;
  TS_o      <= TS_s;

  A7RB_o    <= A_i(7) when RFSH_i='1' else A7RB_r;

  CSYNC_o   <= csync_s;

  -- CAS only active if a read or write is active

  CAS2_o    <= CAS2_r;
  CAS1_o    <= CAS1_r;

  MA_oe_o   <= vdisplay_s AND ( (AND_REDUCE(std_logic_vector(hcounter_s(3 downto 0)))
        xor hcounter_s(4)) AND NOT hcounter_s(9));

  -- RGB output

  R_o       <= R_r;-- AND not VSYNC_s;
  G_o       <= G_r;-- AND not VSYNC_s;
  B_o       <= B_r;-- AND not VSYNC_s;
  BRIGHT_o  <= BRIGHT_r;-- AND not VSYNC_s;

  -- AY
  AYCLK_o   <= ayclk_s;

  D_o <= '0' & TPIN_i & '0' & KB_i;

  ROMCS_o   <= (banksel_s(0) OR NOT BE_i) when A_i(15 downto 13)="000" else
               (banksel_s(1) OR NOT BE_i) when A_i(15 downto 13)="001"
               else '1';
  ROSCS_o   <= (not current_banksel_s OR NOT BE_i) when bank_s='0' else '1';
  EXROM_o   <= (not current_banksel_s OR NOT BE_I) when bank_s='1' else '1';
  TPOUT_o   <= ear_s;

  BDIR_o    <= bdir_s;
  BC1_o     <= bc1_s;

  -- Other outputs

  --HSYNC_o   <= hsync_r;
  --VSYNC_o   <= prevsync_s;

end sim;
