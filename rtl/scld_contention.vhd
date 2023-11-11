--
-- TIMEX(tm) SCLD contention control
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
use IEEE.std_logic_misc.all;

entity scld_contention is
  port (
    clk_i         : in std_logic;
    arst_i        : in std_logic;
    hcounter_i    : in unsigned(9 downto 0);
    IORQ_i        : in std_logic;
    MREQ_i        : in std_logic;
    RD_i          : in std_logic;
    WR_i          : in std_logic;
    A_i           : in std_logic_vector(15 downto 14);
    contention_o  : out std_logic;
    nrequest_rd_o : out std_logic;
    nrequest_wr_o : out std_logic;
    nrequest_o    : out std_logic
  );
end entity scld_contention;

architecture beh of scld_contention is

  signal request_needs_contention_s   : std_logic;
  signal request_rd_r                 : std_logic;
  signal request_wr_r                 : std_logic;
  signal vram_access_s                : std_logic;
  signal contention_cycle_s           : std_logic;
  signal is_request                   : std_logic;
  signal nrequest_r                   : std_logic;

begin

  vram_access_s <= '1' when  A_i(15 downto 14)="01" else '0';

  process(hcounter_i, A_i, IORQ_i, MREQ_i, request_rd_r, request_wr_r,
          vram_access_s, nrequest_r, contention_cycle_s)
  begin
    request_needs_contention_s <= '0';

    if hcounter_i(9)='0' then
      if vram_access_s='1' or IORQ_i='0' then --or MREQ_i='0' then
        request_needs_contention_s <= contention_cycle_s;
      end if;
      -- If processing a request, let it complete
      --if request_rd_r='0' or request_wr_r='0' then
      if nrequest_r='0' then
        request_needs_contention_s <= '0';
      end if;

    end if;
  end process;


  is_request <= '0' WHEN IORQ_i='1' AND MREQ_i='1' else '1';

  process(clk_i, arst_i, is_request)
  begin
    if arst_i='1' or is_request='0' then
      nrequest_r   <= '1';
    elsif falling_edge(clk_i) then
      if (IORQ_i='0' or (MREQ_i='0')) then
        if contention_cycle_s='0' then
          if hcounter_i(1 downto 0)/= "11" then -- CPU clk rising edge event
            nrequest_r <= '0';
          end if;
        end if;
      end if;
    end if; -- falling_edge
  end process;

  process(clk_i, arst_i)
  begin
    if arst_i='1' then
      request_rd_r <= '1';
    elsif falling_edge(clk_i) then
      if (IORQ_i='0') then
        --if contention_cycle_s='0' then
        if request_needs_contention_s='0' then
          if hcounter_i(1 downto 0)= "11" then -- CPU clk rising edge event
            if RD_i='0' then
              request_rd_r <= '0';
            end if;
          end if;
        end if;
      else
        if hcounter_i(1 downto 0)="01" then
          request_rd_r <= '1';
        end if;
      end if;
    end if; -- falling_edge
  end process;

  process(hcounter_i)
  begin
    case hcounter_i(4 downto 2) is
      when "001" => contention_cycle_s <= hcounter_i(1);
      when "010" | "011" | "100" | "101" | "110" => contention_cycle_s <= '1';
      when others => contention_cycle_s <= '0';
    end case;
  end process;

  contention_o    <= request_needs_contention_s;
  nrequest_rd_o   <= request_rd_r;
  nrequest_wr_o   <= request_wr_r;
  nrequest_o      <= nrequest_r;

end beh;
