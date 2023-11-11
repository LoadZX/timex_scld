--
-- TIMEX(tm) SCLD package
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

library ieee;
use ieee.std_logic_1164.all;

package scldpkg is

  type simcontrol_command_type is (
    NONE,
    SETFE,
    SETFF
  );

  type simcontrol_in_type is record
    cmd   : simcontrol_command_type;
    data  : std_logic_vector(7 downto 0);
  end record;

  procedure setFE(signal simcontrol: out simcontrol_in_type; val: std_logic_vector(7 downto 0));
  procedure setFF(signal simcontrol: out simcontrol_in_type; val: std_logic_vector(7 downto 0));

end package;

package body scldpkg is

  procedure setFE(signal simcontrol: out simcontrol_in_type; val: std_logic_vector(7 downto 0)) is
  begin
    simcontrol.data <= val;
    simcontrol.cmd <= SETFE;
    wait for 0 ps;
    simcontrol.cmd <= NONE;
    wait for 0 ps;
  end procedure;

  procedure setFF(signal simcontrol: out simcontrol_in_type; val: std_logic_vector(7 downto 0)) is
  begin
    simcontrol.data <= val;
    simcontrol.cmd <= SETFF;
    wait for 0 ps;
    simcontrol.cmd <= NONE;
    wait for 0 ps;
  end procedure;

end;
