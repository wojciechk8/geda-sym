This is my repository of gEDA symbols/footprints. There are also some
configuration files (\*rc), template files (template.\*), tools
(utils directory).

All my symbols are licensed GPL for distribution, and unlimited for use.

Documentation regarding symbols or footprints creation, configuration
files, etc. can be found at [gEDA wiki](http://wiki.geda-project.org/geda:documentation).

## Symbols
Some symbols are drawn manually and some are generated using *djboxsym*.
The Makefile in the *sym* directory runs *djboxsym* on all .symdef
files.

In some places there are converters from "plain text" to symdef, which
in turn can be converted to symbol using *djboxsym*. This "plain text"
could be for instance a copied pinout table from a device datasheet.
For example of such converter check ARM/STM32 directory, where the
content of stm32f105 file was copied from a datasheet and then converted
to 3 symdef files (respectively for each package) using my *stm2symdef*
perl script.

There are also few connectors generators in Connector directory.

## Footprints
Most footprints I'm using come from stock *pcb* library. If there's no
footprint I need, then I make it myself. Some IC footprints are
generated using *sfg.rb* script. For several connectors footprints I've
written scripts to generate them. Others are made manually.
