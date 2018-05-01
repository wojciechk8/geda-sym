PROJECT := spectrometer
SCHEMATICS := spectrometer.sch

all: parts pdf sch

.PHONY: parts pdf sch
parts: $(PROJECT).parts
sch: $(PROJECT)_sch.pdf
pdf: $(PROJECT).pdf


$(PROJECT).parts : $(SCHEMATICS)
	gnetlist -g partslist3 -o $@ $^

$(PROJECT)_sch.pdf : $(SCHEMATICS)
	./sch_export $@ $^

$(PROJECT).pdf : $(PROJECT).lht
	./pcb-rnd_export $<
