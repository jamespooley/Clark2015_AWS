Clark_AWS_OHBM2015.pdf: Clark_AWS_OHBM2015.tex Makefile beamerthemeCMINKI.sty
	echo "$< $@"
#	latex $< 
	pdflatex $(basename $<) $@
#	rm $(basename $<).dvi
	rm  $(basename $<).log

all: Clark_AWS_OHBM2015.pdf
