SYMGEN=./djboxsym
SYMBOLSDEF=$(wildcard */*.symdef)
SYMBOLS=$(SYMBOLSDEF:.symdef=.sym)

.PHONY: sym clean

sym: $(SYMBOLS)

%.sym : %.symdef $(SYMGEN)
	$(SYMGEN) $< > $@

clean:
	rm $(SYMBOLS)
