# Timex SCLD

This is an implementation of the Timex TC2068 SCLD as can be found in Timex models TC2048 and TC2068.

# License

All the design files (VHDL code, PCB designs) are licensed under a Creative Commons Attribution-ShareAlike 4.0 International License.

You should have received a copy of the license along with this work. If not, see <https://creativecommons.org/licenses/by-sa/4.0/>.

A copy of the legal license text is placed in this repository (see LICENSE)

# Trademarks

TIMEX is a trademark of TIMEX GROUP USA, INC

The authors of this work are not affiliated, sponsored or have any partnership with the trademark holders. The trademark holders do not sponsor or endorse this work or any of its authors.

Xilinx is a registered trademark of Xilinx in the United States and other countries.

# Implementation code
The implementation (VHDL code and associated files) target a XC95144XL-10TQ100 CPLD from Xilinx. 

## Synthesis
The tool used for synthesis and fitting was Xilinx ISE 14.7. 

## Programming
Programming can be acomplished with Xilinx Impact using a proper programmer (i.e., Xilinx Platform Cable)

# Building

Just type "make" under the SDLC implementation folder (syn/xilinx). Alternatively you can try loading the ISE project in the same directory.
