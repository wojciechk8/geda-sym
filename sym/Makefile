SYMGEN=./djboxsym
#SYMBOLSDEF=$(wildcard */*.symdef)
SYMBOLSDEF=$(shell find . -type f -name '*.symdef')
#SYMBOLS=$(SYMBOLSDEF:.symdef=.sym)
SYMBOLS=$(patsubst %.symdef, %.sym, $(SYMBOLSDEF))

.PHONY: sym clean

sym: $(SYMBOLS)

%.sym : %.symdef $(SYMGEN)
	$(SYMGEN) $< > $@

clean:
	rm $(SYMBOLS)
