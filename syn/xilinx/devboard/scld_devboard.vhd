library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.numeric_std.all;
use IEEE.std_logic_misc.all;
  -- synthesis translate_off
use work.scldpkg.all;
  -- synthesis translate_on

--library unisim;
--use unisim.vcomponents.all;

entity scld_devboard is
  port (
    SCLD_CLK      : in std_logic;
    A             : in std_logic_vector(15 downto 0);
    D             : inout std_logic_vector(7 downto 0);
    MREQ          : in std_logic;
    IORQ          : in std_logic;
    RD            : in std_logic;
    WR            : in std_logic;
    P5060         : in std_logic;
    TPIN          : in std_logic; -- TBD
    RFSH          : in std_logic; 
    BE            : in std_logic; -- TBD
    KB            : in std_logic_vector(4 downto 0); -- TBD
    RAS           : out std_logic;
    CAS           : out std_logic;
    TS            : out std_logic;
    RDN           : out std_logic;
    MUX           : out std_logic;
    INT           : out std_logic;
    CAS2          : out std_logic;
    CAS1          : out std_logic;
    MWE           : out std_logic;
    CPUCLK        : out std_logic;
    CSYNC         : out std_logic;
    MA            : inout std_logic_vector(7 downto 0);
    MAe           : out std_logic;
    R             : out std_logic;
    G             : out std_logic;
    B             : out std_logic;
    BRIGHT        : out std_logic;
    A7RB          : out std_logic;
    AYCLK         : out std_logic;
    ROMCS         : out std_logic;
    ROSCS         : out std_logic;
    EXROM         : out std_logic;
    TPOUT         : out std_logic;  -- TBD
    BDIR          : out std_logic;  -- TBD
    CPUCLKB       : out std_logic;  -- TBD
    BC1           : out std_logic
      -- TBD
    --NOE           : in std_logic
  );
end entity scld_devboard;

architecture str of scld_devboard is

  signal D_o_s          : std_logic_vector(7 downto 0);
  signal D_i_s          : std_logic_vector(7 downto 0);
  signal D_oe_o_s       : std_logic;
  signal RAS_o_s        : std_logic;
  signal CAS_o_s        : std_logic;
  signal TS_o_s         : std_logic;
  signal RDN_o_s        : std_logic;
  signal MUX_o_s        : std_logic;
  signal CAS2_o_s       : std_logic;
  signal CAS1_o_s       : std_logic;
  signal MWE_o_s        : std_logic;
  signal CPUCLK_o_s     : std_logic;
  signal CPUCLKB_o_s    : std_logic;
  signal CSYNC_o_s      : std_logic;
  signal MA_o_s         : std_logic_vector(7 downto 0);
  signal MA_oe_o_s      : std_logic;
  signal R_o_s          : std_logic;
  signal G_o_s          : std_logic;
  signal B_o_s          : std_logic;
  signal A7RB_o_s       : std_logic;
  signal BRIGHT_o_s     : std_logic;
  signal ROMCS_o_s      : std_logic;
  signal ROSCS_o_s      : std_logic;
  signal EXROM_o_s      : std_logic;
  signal AYCLK_o_s      : std_logic;
  signal BC1_o_s        : std_logic;
  signal BDIR_o_s       : std_logic;
  signal TPOUT_o_s      : std_logic;

  --signal A_oe_c_s       : std_logic;
  signal D_oe_c_s       : std_logic;
  signal MA_oe_c_s      : std_logic;

  signal INT_oe_o_s     : std_logic;

  signal OE             : std_logic;
  -- synthesis translate_off
  signal  simcontrol    : simcontrol_in_type := (NONE, x"00");
  -- synthesis translate_on

begin

  --OE <= not NOE;
  OE <= '1';
  D_oe_c_s  <= OE and D_oe_o_s;
  MA_oe_c_s <= OE and MA_oe_o_s;

  scld_inst: entity work.scld
  port map (
    -- synthesis translate_off
    simcontrol    => simcontrol,
    -- synthesis translate_on

    SCLD_CLK      => SCLD_CLK,
    A_i           => A,
    D_i           => D_i_s,
    D_o           => D_o_s,
    D_oe_o        => D_oe_o_s,
    MREQ_i        => MREQ,
    IORQ_i        => IORQ,
    RD_i          => RD,
    WR_i          => WR,
    KB_i          => KB,
    TPIN_i        => TPIN,
    P5060_i       => P5060,
    RFSH_i        => RFSH,
    BE_i          => BE,
    RAS_o         => RAS_o_s,
    CAS_o         => CAS_o_s,
    TS_o          => TS_o_s,
    RDN_o         => RDN_o_s,
    MUX_o         => MUX_o_s,
    CAS2_o        => CAS2_o_s,
    CAS1_o        => CAS1_o_s,
    MWE_o         => MWE_o_s,
    CPUCLK_o      => CPUCLK_o_s,
    CPUCLKB_o     => CPUCLKB_o_s,
    CSYNC_o       => CSYNC_o_s,
    MA_o          => MA_o_s,
    MA_oe_o       => MA_oe_o_s,
    R_o           => R_o_s,
    G_o           => G_o_s,
    B_o           => B_o_s,
    BRIGHT_o      => BRIGHT_o_s,
    A7RB_o        => A7RB_o_s,
    INT_oe_o      => INT_oe_o_s,
    ROMCS_o       => ROMCS_o_s,
    ROSCS_o       => ROSCS_o_s,
    EXROM_o       => EXROM_o_s,
    AYCLK_o       => AYCLK_o_s,
    BC1_o         => BC1_o_s,
    BDIR_o        => BDIR_o_s,
    TPOUT_o       => TPOUT_o_s
  );

  RAS <= RAS_o_s WHEN OE='1' else 'Z';
  CAS <= CAS_o_s WHEN OE='1' else 'Z';
  TS  <= TS_o_s WHEN OE='1' else 'Z';
  RDN  <= RDN_o_s WHEN OE='1' else 'Z';
  MUX  <= MUX_o_s WHEN OE='1' else 'Z';
  CAS2  <= CAS2_o_s WHEN OE='1' else 'Z';
  CAS1  <= CAS1_o_s WHEN OE='1' else 'Z';
  MWE  <= MWE_o_s WHEN OE='1' else 'Z';
  CPUCLK  <= CPUCLK_o_s WHEN OE='1' else 'Z';
  CPUCLKB  <= CPUCLKB_o_s WHEN OE='1' else 'Z';

  CSYNC  <= CSYNC_o_s WHEN OE='1' else 'Z';
  R  <= R_o_s WHEN OE='1' else 'Z';
  G  <= G_o_s WHEN OE='1' else 'Z';
  B  <= B_o_s WHEN OE='1' else 'Z';
  BRIGHT  <= BRIGHT_o_s WHEN OE='1' else 'Z';
  A7RB  <= A7RB_o_s WHEN OE='1' else 'Z';
  AYCLK <= AYCLK_o_s WHEN OE='1' else 'Z';
  TPOUT <= TPOUT_o_s WHEN OE='1' else 'Z';
  BC1 <= BC1_o_s WHEN OE='1' else 'Z';
  BDIR <= BDIR_o_s WHEN OE='1' else 'Z';

  D <= D_o_s WHEN D_oe_c_s='1' else (others=>'Z');
  MA <= MA_o_s WHEN MA_oe_c_s='1' else (others =>'Z');
  D_i_s <= D;


  -- Open-drain outputs.
  INT <= '0' when INT_oe_o_s='1' else 'Z';

  -- TBD: confirm if these signals are open-drain or are directly driven.
  ROMCS  <= ROMCS_o_s WHEN OE='1' else 'Z';
  ROSCS  <= ROSCS_o_s WHEN OE='1' else 'Z';
  EXROM  <= EXROM_o_s WHEN OE='1' else 'Z';


end str;

