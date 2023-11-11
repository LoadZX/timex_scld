PART=xc95144xl-TQ100-10
TARGET=scld_devboard

all: $(TARGET).jed 

$(TARGET).jed: $(TARGET).mfd
	hprep6 -s IEEE1149 -n $(TARGET) -i $(TARGET)
	cat $(TARGET).rpt | head -n12|tail -n5

$(TARGET).ngc: xst/projnav.tmp
	xst -ifn $(TARGET).xst -ofn $(TARGET).syr

$(TARGET).ngd: $(TARGET).ngc
	ngdbuild -dd _ngo -uc $(TARGET).ucf -p $(PART) $(TARGET).ngc $(TARGET).ngd

      
$(TARGET).mfd: $(TARGET).ngd
	cpldfit -intstyle ise \
	-p xc95144xl-10-TQ100 \
	-ofmt vhdl \
        -optimize density \
	-htmlrpt \
	-loc try \
	-slew fast \
        -init low \
	-inputs 53 \
	-pterms 40 \
	-exhaust \
        -unused float \
	-power std \
	-terminate keeper \
	$(TARGET).ngd

$(TARGET)_timing_report.htm: $(TARGET).mfd
	taengine -intstyle ise -f $(TARGET) -w --format html1 -l $(TARGET)_timing_report.htm

xst/projnav.tmp:	
	mkdir -p xst/projnav.tmp

clean:
	rm -f $(TARGET).{ngc,jed,mfd,ngd,vm6,pad,pad.csv,pnx,rpt,srp,syr,bld,gyd,lso,ngr,xml}
	rm -f $(TARGET){_pad.csv,_build.xml,_ngdbuild.xrpt,_TOP.lso,_xst.xrpt} tmperr.err
	rm -rf _ngo $(TARGET)_html tmp xlnx_auto_0_xdb _xmsgs xst
