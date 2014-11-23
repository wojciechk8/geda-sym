TRAGESYM=./tragesym.py
SYMBOLDIRS=$(sort $(dir $(wildcard */*.csv)))
SYMBOLSCSV=$(wildcard */*.csv)
SYMBOLS=$(SYMBOLSCSV:.csv=.sym)

.PHONY: sym clean $(SYMBOLDIRS)

sym: $(SYMBOLS)

%.sym : %.csv $(TRAGESYM)
	$(TRAGESYM) $< $@

clean:
	rm $(SYMBOLS)
