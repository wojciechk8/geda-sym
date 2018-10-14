#!/usr/bin/perl -w

use strict;
use Data::Dumper;
#use Text::ParseWords;

=encoding utf8
=pod

=head1 NAME

pdftopin.pl - a program to convert a pin file to a gschem .sym file

=head1 SYNOPSIS

pintopdf.pl [pin_file]...

=head1 DESCRIPTION

gschem  is  a  schematic  capture application, which is part of the gEDA (GPL Electronic Design Automation) toolset.
Schematics are made up of symbols, which represent the various components,
and pintosym.pl [4] creates such sympols (or symbol files) from what I call pin files.
It creates one or more symbol files for each pin file given on command line.

For information about gEDA see [1], and for sym file format see [3].

=head1 PIN FILES

Pin files are preprocessed,
multiple spaces and tabs is replaced with a single space,
line initial and trailing whitespace is removed,
and blank lines and comment lines (i.e. thoose starting with #) are ignored.

Generally, all lines (except include and attribute lines, which carry a string argument)
are treated as space separated lists.

Pin files consists of

=over

=item 1. Pin lines

=item 2. Attribute lines

=item 3. Include lines

=item 4. Pin set definitions

=item 5. Output (symbol file) definitions

=back

=head2 1. Pin lines

 <pkg0> <pkg1> ...
 <num0> <num1> ... <pintype> <pinlbl> <alt_func> ...
 ...

The first pin line is special, it is a header line.
It contains package names (e.g. LQFP48, DIL16) or
any label you might wish to use (not containing space).
There must be at least one package named.
The package columns are numbered started from zero (0).

The rest of the lines defines the pins.
First in the line is a list of pin numbers, one for each package.
If one specific package doesn't have a specific pin, use a "-" to mark it as not there.
Then follows the pin type
(pin type is an attribute of the pin and is described in [2]).
And lastly are the pin label and the pins alternate functions or whatever text you want to be attached to the pin.

Example:

 LQFP100 LQFP64 TFBGA64 LQFP48
   1   -   -   - io  PE2 TRACECLK
  23  14  G2  10 pas PA0 ADC1_IN0 TIM2_CH1_ETR USART2_CTS WKUP

=head2 2. Attribute lines

They define global or common attributes.
They are in the form of name=value, e.g.:

 refdes=X?

Attributes are described in [2] and some possible more are mentioned in [6].

Any attribute can be defined multiple times, but depending on which attribute is,
only the last one defined might be used.

Local or output (symbol file) specific attributes adds to the list for that output.
Attributes not specifically mentioned below are treated like an invisible attribute.

The attributes description, value, sublabel, source, and netsfile are processed in
the same way as <filename_fmt>, see section 5 below.

This program divides the attributes in four groups:

=head3 Visable attributes

The attributes below will be printed somewhere (depending on style and pin distribution)
whithin the symbols outline.

=over

=item a. refdes

Defaults to "U?".

=item b. description

Like "device", but a little more verbose.

=item c. value

Like "device"/"description" described above, but more specific.
E.g. "ATMega_88", "100R" (Ohm).
Defaults to value for "part-number", or "device".

=item d. sublabel

This is my invention,
any text you want to be attached below the above three.
If you e.g. have a symbol for the power pin part of a large device, you might use "Power pins" here.

=back

=head3 Invisable atttributes (will have the "visible" flag not set)

=over

=item e. author

Default is value from /etc/passwd file, the gcos or the name field.

=item f. copyright

The person or organisation who has the copyrigt.
Defaults to author.

=item g. dist-license

Defaults to "GPL".

=item h. use-license

Defaults to "unlimited".

=item i. device

The type of things that the sybol represent.
If the symbol represents a family of devices, use the family name, else
use a very short description, e.g. "MCU" or "Resistor".
No default.

=item j. footprint

This is related to the programs pcb and gnetlist.
It basically is the basename of the file which contains the footprint (with or without the ".fp" suffix).

=item k. documentation

The url to the pdf from which you extracted the pinouts and possible other relevant files/links.

=back

=head3 Package specific attributes

The program allows you to use any attribute names and append a dot and a package name.
When processing for the a specific package,
this attributes value will be copied to unappended attribute.
E.g. when processing package from column 2 and

 footprint.2=LQFP100_14.fp

is given, it will be treated as if you wrote

 footprint=LQFP100_14.fp

instead.

Any attribute name containing a period ("."), is treated like a
package specific attribute.  Any such attribute without a matching
package column number is ignored.

=head3 Special attributes

Special actions may require some configuration data.
I have choosen to use the same syntax for them as for attributes
since the specials easily can use attribute names that don't conflicts with (real) attributes.

=over

=item l. pin-arrow

 pin-arrow=true

If this attribute is set, then a little arrow is drawn at the base of the pin for pins with pintype "in" or "out".

=item m. label-net

 label-net=true

If this attribute is set, then a net attribute with the <pin label>:<pin number> as value is added.

=item n. common_labels

 common_labels=true

This is attribute is useful when creating symbols for the same chip with different packages or
for similar chips, where different symbols differ inte number of used pins.
If this attribute is set, then the pins for different packages and same label (if unique) will
appear in the same position.
One can use this e.g. when you pick a chip in a smaller package,
and then after a while switches to a more bigger package, the
the pins of the smaller and bigger package symbols will match.

=item o. source

 source=<filename>

The file we are creating is a "source" symbol to be used for hierarchical/multipage schematics.
This special will change the normal symbol creation process:

=over

=item .

the attribute "source=<filename>" will be included

=item .

the file named by <filename> will be created or updated so it contains,
for each pin, one net symbol with a (invisible) "net=value:1",
and a (visible) "refdes=value" attribute,
where value is equal to resp. pins pinlabel attribute.
The net symbol to be used is decided by the first "source-map" line which <perl_expression> evals to true.

=back

=item p. netsfile

 netsfile=<filename>

The file we are creating is a normal symbol, and in addition a sch
file (with the name given by <filename>) containing one net symbol per
pin is created or updated. It is identical to the "source" special, except
the attribute "source=<filename> isn't included.

=item q. source-map

 source-map=<net-sym-name>  <alignment> <dx> <dy> <perl_expression>

The source-map is used by the source special (see above).

=over

=item <net-sym-name>

is the basename of the symbol file name to be used if <perl_expression> evals to true.
Use a symbol with one pin, e.g. "in-1.sym".

=item <alignment>

Use <alignment> for the "refdes=value" (for <value>, see second point under <source>).
The <alignment> is a number 0..8, see [3] under "text and attributes" / alignment field.

=item <dx> / <dy>

Place the "refdes=value" text at this displacement relative the lower left of the symbol.

=item <perl_expression>

See above under "4. Pin set definitions" / "a) by a perl expression".

=back

Example:

source-map=netif_in.sym     0 620 450  $type eq "in"
source-map=netif_out.sym    0 620 450  $type eq "out"

=item r. horizontal_labels

 horizontal_labels=true

For symbols with short labels it is nice to have horizontal label text for pins on the top and
bottom side of the symbol box, this attribute makes them so.

=back

=head2 3. Include lines

 !include <file>

Include lines will start read <file> as if it was included verbatim in the current line.
Per default, ~/.gEDA/pintosym.conf is automatically included if it exists and is readable.

=head2 4. Pin set definitions

Initially the pin set "pins" are available, it's the set of all pins from the pin lines.
All pin sets are in file order, i.e. in the order the pins appeared when reading the input.
There are three ways to define a pin set:

=over

=item a) by a perl expression

 !f <dst_set> <rest_set> <src_set> <perl expression>

Use <src_set>, take each pin from that set and do eval(<perl expression>) on it.
If found true, put it in <dst_set>, else put it in <rest_set>.

 <perl_expression>

The variables you can use are:

 @pinnum a list of pin numbers, one for each package,
         where "-" means this pin don't exist for this package

 $type   what goes directly to the pin's pintype attribute

 $text   the pin's label and alt. function names

 @token  as $text but as a list/array
         in pin set definition context,
           the list is in the order as found in the file
         in output file definition context,
           the order depends on "side definitions"

 $lbl    the first token, $token[0]
         in output file definition context, this is the text
         to be used as "pinlabel"

 $pinline a number 0.., the order in which the pin line occurred when reading the file

My guess is that this is only useful to check the pintype.
Otherwise I'd use the next way to specify a pin set.

Example:

 !f pwr_pins other_pins pins $type eq "pwr"

=item b) by a regular expression

 !m <true_set> <false_set> <src_set> <regular expression>

The same as above, but with "$text =~ m/<regular expression>/".
Take <src_set>, divide it into <true_set> and <false_set> depending if resp. pin text matches or not the
given expression.

Example:

 !m jtag_pins dump other_pins (JT|NRST)

=item c) by joining/merging a few existant pin sets

 !j dst_set src_set1 src_set2 ...

Combine the src_set's and put the result into <dst_set> (with duplicates removed).

Example:

 !j sys_pins  pwr_pins jtag_pins

=back

=head2 5. Output (symbol file) definitions

 !> <filename_fmt> <packages> <pin_set> <style>
 ! arg <argument> ...
 ! local_attribute=value

The output definition tells pintosym.pl what to put into the sym-file.
There can be zero ore more arg and local_attribute lines following each "!>"-line.

=head3 <filename_fmt>

The output filename, with the following interpreted sequences:

 %d the directory part of <pin_file> (input file, see above under "synopsis"),
    including a final "/" if a directory part is present
 %n the basename of <pin_file> minus any extension
 %p the current package column number
 %l the current package column header string

If <filename_fmt> starts with a "." as in ".<suffix>", then %d and %n are implied as in
"%d%n.<suffix>".

If <filename_fmt> is a single -, the result will go to stdout.

=head3 <packages>

Which package columns to use.

Can be "*" for all packages, or a string of single digit numbers (0-based index into pkg columns).
E.g. 03 would indicate LQFP100 and LQFP48 for the example in "1. Pin lines" above.
This implies that there can be only 10 columns of packages.

=head3 <pin_set>

Only pins from given pin set will be put around the "box".
For how to create pin sets, see "4. Pin set definitions" above.

=head3 <style>

<style> can be one of the alternatives below.
It decides the general outline of the symbol "box".

=over

=item rect

Looks like a rectangle.
May have pins on all four sides.
There are a few effects available (via arg-lines) for the corners.

=item hdr

Looks like a header connector, oblong rectangle with pin 1 arrow and
typical header shroud.
Will only have pins on left and right side.

=item cutout

Looks like a tearoff strip.
Will only have pins on left and right side.

=item circle

Looks like a wheel of fortune with all the pins around the circle.
Mainly used to test the placement of pins at various angles.

=item showarg

Will printout debug data.

=back

Examples:

If <pin_file> is "hello.c", then %d = "", %n = "hello";
If <pin_file> = "~/share/pin_files/dev.pins", %d = "~/share/pin_files/", %n = "dev".

If the header line is "LQFP100 LQFP64 TFBGA64 LQFP48", and <pkg> = 3, then
%p = 3, %l = "LQFP48"; <pkg> = 01, then in the first run, %p = 0, %l = "LQFP100",
and in the second run, %p = 1, %l = "LQFP64".

With the above header line

 !> .circle.%l.sym 3 pins circle
 !> .circle.%p.sym 3 pins circle

will create the files

 hello.circle.LQFP48.sym
 hello.circle.3.sym

=head3 <argument>

<argument>'s change a style's default values.
They can be one of four types:

=over

=item A. flags

shuffle:
 when distributing pins to sides, hand out one at a time.

=item B. side definitions

Defines how and which pins are distributed along the sides of the
symbol.

 <sides>:<re>,<re>,...<:sort>

<sides> is one or more of n l b r t or N L B R T, which stands for
"not used", "left", "bottom", "right", and "top" side.
Using more than one letter distributes the resultant pins among the named sides.

<re> tells the program which pins to use, and is either a regular
expression like "ADC", or a single "x".

If <sides> is lowercase, the <re> is tested against the pin texts
(<pin_label alt_func ...>), otherwise it tested against the pin
numbers. For matches aginst the pin texts, the matched name
is used as the pin_label.

A single "x" instead of a regular expression tells the program to
insert a gap between the pins.

<:sort> is ":l", ":n" or nothing, a ":l" label_sorts the list per <re> part apha-numerically,
a ":n" sorts it per pin number (file order othervise).
 The label_sort sorts the text sanely, e.g.:

  adc1_in1a ... adc1_in9z adc1_in10a ... adc9_in124z adc10_in1a

Multiple side definitions appends, e.g. l:a l:b is the same as l:a,b, but not the same as
 l:a:s l:b, since that will have the a's in alpha-num. sort order and the b's in file order.

=item C. order definition

 order:<orders>

<orders> is one or more of lbrtLBRT, lbrt are NOP's, the others reverses the resp. side list.
The default order is the same as for a LQFP or DIL (no bottom and top pins) packages,
 going from upper left corner counter clock wise arount the outline,
To change that to be like e.g. a header connector you'd use "! arg shuffle lr:. order:R"

=item D. key-value pairs

Key-value pairs (per style):

 rect  (defaults are 0 unless noted)
  w:<rectange width>                 default depend on number of top and bottom pins, and corner
  h:<rectangle height>               default depend on number of left and right pins, and corner
  corner:<dist corner to first pin>  (disregarding skew) default = 1
  skew:<displ. pins this much>       can make pin text no collide with each other, in e.g. corners
  radi:<corner radius>               radi/cut can be negative or positive
  cut:<use straight cut this size>   if both cut and radi, cut wins
  topskip:<value>                    extra lift of top side
  ulcut:<value>                      upper left corner cut off this much
  dogear                             make a folded corner called "dogear"
  ulring:<dia/x-disp/y-disp>         print a ring like thoose found on dil packages in upper left corner
                                     default x-disp = 1, y-disp = 0.75

 hdr
  w:<left to right side distance>

 cutout
  w:<left to right side distance>

 circle
  diameter:<value>

All values are in pin_dist'ances (currently 400mil).

=back

=head3 <local_attribute=value>

=head3 Local attributes

Attributes used only for the last defined output spec.
For that output, theese attributes are added to the global attribute list.
See also "2. Attribute lines" above.

=head1 EXAMPLES

Examples are found in [5].

=head1 AUTHOR

Written by Karl Hammar.

=head1 COPYRIGHT

Copyright © 2012 Karl Hammar.
License GPLv3+: GNU GPL version 3 or later <http://gnu.org/licenses/gpl.html>
This is free software: you are free to change and redistribute it.
There is NO WARRANTY, to the extent permitted by law.

=head1 SEE ALSO

 [1] http://www.geda-project.org/
 [2] http://wiki.geda-project.org/geda:master_attributes_list
 [3] http://wiki.geda-project.org/geda:file_format_spec

 [4] http://turkos.aspodata.se/git/openhw/pdftosym/pintosym.pl
 [5] http://turkos.aspodata.se/git/openhw/pdftosym/examples.pintosym

 [6] http://www.gedasymbols.org/csv.html

=cut

########################################
# globals which are more or less ocnstant

my $VERSION = "20111231 2"; # file format version this program is using

my $conffile = $ENV{"HOME"} . "/.gEDA/pintosym.conf";

# config values
my $grid = 100; # grid which active pin end snaps to
my $pin_dist = 400;
my $pin_length = 400;
my $pin_colour = 1; # from colour definition in docs/wiki/geda-file_format_spec.html

# fontsizes
my $sztext = 10; # header text
my $szsmall = 6; # small header text
my $szlbl = 10;
my $szalt = 6;
my $sznum = 8;
my $szseq = 8;
my $sztyp = 5;

# textcolour
my $cllbl = 9;
my $clalt = 9;
my $clnum = 5;
my $clseq = 5;
my $cltyp = 5;

my $pin_lblspace = 0.25;
my $pin_seq = 0; # reset this to 0 when drawing a new symbol

# some constants
my $twopi = 2 * atan2( 0, -1 );
my $pin_space = [ ]; # some unique value, a ref to an empty array seems to suffice

####

# I could look up the font metrics and calculate this on the fly, but not now
my $bnx = 250 / 2; # half pinnum/seq bounding box width
my $bny = 130 / 2; # dito height
my $btx = 150 / 2; # half pintype bounding box
my $bty =  80 / 2;
my $angn = atan2( $bny, $bnx); # angle of bb diagonal to horisontal, pinnum/seq
my $angt = atan2( $bty, $btx); # angle of bb diagonal to horisontal, pintype
my $diagn = sqrt( $bnx * $bnx + $bny * $bny); # half the bb diagonal
my $diagt = sqrt( $btx * $btx + $bty * $bty); # half the bb diagonal

####

my $text_colour = 9;
my $text_vis = 0;
my $text_show = 1;
my $text_angle = 0;
my $text_align = 0;
my $text_format = "T %5d %5d  %2d %2d  %d %d %3d %d 1\n";

my $cur_x;
my $cur_y;
my $line_clr = 3;
my $line_width = 40;
my $line_def = "2 0 -1 -1"; # capstyle dashstyle dashlength dashspace = END ROUND, TYPE SOLID, not used, not used

my %style;

########################################
# Globals, used instead of parameter passing

# @pins = ( pin, ... ), where
# pin = [ [ list of pin numbers ], pin_type, [ list of pin labels/names ], same but as a str. for search., pin line num. ]

my @header; # the first pin line, header for the pin number part of each pin line
my %header; # index for above
my $pin_line; # for data_str saving file order, needed when merging/joining pin sets to keep file order
my @pins; # all found pins, in file order
my %gattr; # all global (default) attributes found
my %attr; # attributes to be used
my @attr_special = qw/pin-arrow label-net common_labels netsfile source source-map horizontal_labels/;
my %attr_special ; # special handling, possible not to put in output file
for (@attr_special) { $attr_special{$_} = 1; }
my %attr_proc = ("description" => 1, "value" => 1, "sublabel" => 1, "source" => 1, "netsfile" => 1,);
my %attr_skip; # any attributes you don't want in output file
my %pin_set;
my $fh_out; # file handler for output
my $cur_inp; # file name as given on the command line
my $cur_dir; # the directory part of the current <pin_file>
my $cur_file; # the basename of the current <pin_file>
my $cur_nam; # $cur_file minus any file name suffix
my $cur_pkg; # current package column number (0..$#header)
my $cur_lbl; # current package column label ($header($cur_pkg))
my $cur_set; # current pin set name, for debugging

my $warn_cnt = 0;

sub clr_globals() {
    @header = ();
    %header = ();
    $pin_line = undef();
    @pins = ();
    %gattr = ();
    %attr = ();
    $fh_out = *STDOUT;
    $cur_dir = undef();
    $cur_file = undef();
    $cur_nam = undef();
    $cur_pkg = -1;
    $cur_lbl = undef();
    $cur_set = undef();
}
########################################

sub Warn( $ ) {
    my $str = shift;
    warn($str);
    $warn_cnt++;
    if ($warn_cnt > 10) {
	warn("too many warnings, quitting");
	exit(1);
    }
}

sub moveto( $ $ ) {
    $cur_x = rnd(shift);
    $cur_y = rnd(shift);
}

sub rmoveto( $ $ ) {
    $cur_x = rnd($cur_x + shift);
    $cur_y = rnd($cur_y + shift);
}

sub lineto( $ $ ) {
    my $x = shift;
    my $y = shift;

    $x = rnd($x);
    $y = rnd($y);
    printf $fh_out "L %5d %5d  %5d %5d %d %d %s\n", $cur_x, $cur_y, $x, $y, $line_clr, $line_width, $line_def;
    $cur_x = $x;
    $cur_y = $y;
}

sub rlineto( $ $ ) {
    lineto( $cur_x + shift, $cur_y + shift);
}

sub arc( $ $ $ $ $ ) {
    my $cx = int(shift);
    my $cy = int(shift);
    my $r = int(shift);
    my $sa = int(shift);
    my $da = int(shift);
    printf $fh_out "A %5d %5d %5d  %3d %3d  %d %d %s\n", $cx, $cy, $r, $sa, $da, $line_clr, $line_width, $line_def;
}

# TODO: just started
sub line_arc( ) {
    # straight line from currentpoint aiming at corner:
    my $cx = int(shift);
    my $cy = int(shift);
    # continuing with an arc with radius
    my $r = int(shift);
    # which ends with a tanget pointing to
    my $ex = int(shift);
    my $ey = int(shift);

    # todo
}

sub text_ascheight( $ ) {
    600 * (shift) / 72;
}
sub text_capheight( $ ) {
    1000 * (shift) / 72;
}
sub text_height( $ ) {
    1.6 * 1000 * (shift) / 72;
}
sub text( $ $ ) {
    my $sz = shift;
    my $str = shift;

    rmoveto( 0, - text_capheight($sz));
    printf $fh_out $text_format, $cur_x, $cur_y, $text_colour, $sz,
	$text_vis, $text_show, $text_angle, $text_align;
    print $fh_out "$str\n";
    rmoveto( 0, - text_ascheight($sz));
}

sub component( $ ) {
    my $str = shift;
    printf $fh_out "C %5d %5d  1 0 0 %s\n", $cur_x, $cur_y, $str;
}

# random walk

sub step_fwd() {
    my $d = 1 + rand(1)/2;
    #$d = $d*$d*$d;
    $pin_dist * $d / 4;
}

sub step_ort( $ ) {
    my $tgt = shift;
    my $d = rand(1) - 0.5 + $tgt/$pin_dist; # the last term is to keep walkx/y more horisontal/vertical
    #$d = $d;
    $pin_dist * $d / 2;
}

sub walkx( $ $ ) {
    my $tx = shift;
    my $ty = shift;

    my $save = $line_width;
    $line_width = 10;
    if ($cur_x < $tx) {
	while ($cur_x < $tx) {
	    my $x = $cur_x + step_fwd();
	    my $y = $cur_y + step_ort($ty - $cur_y);
	    if ($tx < $x) { $x = $tx; }
	    lineto($x,$y);
	}
    } else {
	while ($cur_x > $tx) {
	    my $x = $cur_x - step_fwd();
	    my $y = $cur_y + step_ort($ty - $cur_y);
	    if ($tx > $x) { $x = $tx; }
	    lineto($x,$y);
	}
    }
    $line_width = $save;
}

sub walky( $ $ ) {
    my $tx = shift;
    my $ty = shift;

    my $save = $line_width;
    my $near = $pin_dist/2;
    $line_width = 5;
    if ($cur_y < $ty) {
	while ($cur_y < $ty) {
	    my $x = $cur_x + step_ort($tx - $cur_x);
	    my $y = $cur_y + step_fwd();
	    if ($ty < $y) { $y = $ty; }
	    lineto($x,$y);
	}
    } else {
	while ($cur_y > $ty) {
	    my $x = $cur_x + step_ort($tx - $cur_x);
	    my $y = $cur_y - step_fwd();
	    if ($ty > $y) { $y = $ty; }
	    lineto($x,$y);
	}
    }
    $line_width = $save;
}

##########

sub showpins( $ $ ) {
    my $hdr = shift;
    my $pins = shift;

    #print Dumper($hdr);
    print $fh_out join(" ", @$hdr), "\n";
    #print Dumper(@$hdr);
    for my $k (@$pins) {
	my $tok = $$k[2];
	#printf $fh_out "%3d", $$k[4];
	for my $nn (@{$$k[0]}) {
	    printf $fh_out "%4s", $nn;
	}
	printf $fh_out "  %-3s  %s\n", $$k[1], join(" ", @$tok);
    }
}

# find first element in @$r matching (m/$re/), pick it out and place it first in a copy which is returned
sub tofront( $ $ ) {
    my $re = shift;
    my $r = shift;

    if (!defined($re) || $re eq "" || !defined($r) || ref($r) ne "ARRAY" || @$r == 0 || $$r[0] =~ m/$re/ ) {
	return $r;
    }

    my $ph = [];
    for (my $ix = 0; $ix < @$r; $ix++) {
	if ($$r[$ix] =~ m/$re/) {
	    my $end = @$r - 1;
	    #print "$$r[$ix] $ix $end\n";
	    push @$ph, $$r[$ix];
	    push @$ph, @{$r}[0..($ix-1)];
	    if ($ix < $end) { push @$ph, @$r[($ix+1)..$end]; }
	    #print join(" ", @$ph), "\n";
	    return $ph;
	}
    }
    return $r;
}

# split @$pins in group @$have which have a matching element (m/$re/) and @$dont which dont have a mathing element
sub split_re( $ $ $ ) {
    my $pins = shift;
    my $re = shift;
    my $re_target = shift;

    if (!defined($pins) || ref($pins) ne "ARRAY" || @$pins == 0 || !defined($re) || $re eq "") {
	return ($pins, []);
    }

    # sort according to $re
    my $have = [];
    my $dont = [];

    if ($re_target eq "label") { # apply re on pin labels/text
	for my $r (@$pins) {
	    if ($$r[3] =~ m/$re/) {
		push @$have, $r;
	    } else {
		push @$dont, $r;
	    }
	}
    } else { # apply re on pin numbers
	for my $r (@$pins) {
	    my $str = $$r[0][$cur_pkg];
	    if ($str =~ m/$re/) {
		push @$have, $r;
	    } else {
		push @$dont, $r;
	    }
	}
    }

    ( $have, $dont );
}

sub sortpin_key( $ ) {
    my $lbl = shift;

    if ( $lbl =~ m/^([^0-9]*)(\d+)(.*)$/ ) {
	my $a = $1;
	my $b = $2;
	my $c = $3;
	if (!defined($a)) { $a = ""; }
	if (defined($c)) {
	    $c = &sortpin_key( $c );
	} else {
	    $c = "";
	}
	return sprintf "%s%03d%s", $a, $b, $c;
    } else {
	return $lbl;
    }
}
sub pinsort_lbl {
#    $$a[2][0] cmp $$b[2][0];
    sortpin_key($$a[2][0]) cmp sortpin_key($$b[2][0]);
}
sub pinsort_file {
    $$a[4] <=> $$b[4];
}
sub pinsort_num {
    my $A = $$a[0][$cur_pkg];
    my $B = $$b[0][$cur_pkg];
    if ($A eq "-" && $B eq "-") { return 0; }
    if ($A eq "-") { return  1; }
    if ($B eq "-") { return -1; }
    $A <=> $B;
}
# take a set of pins (@$pins), take those which have a matching (m/$re/) token/label
# (and make sure the matched element is brought first in the token list) and list them
# in @$final, dump the rest in @$dont
sub getpinss( $ $ $ $ ) {
    my $pins = shift;
    my $re = shift;
    my $sort = shift;
    my $re_target = shift;

    if (!defined($pins) || ref($pins) ne "ARRAY" ) {
	return ([],[]);
    }
    if (!defined($re) || $re eq "") {
	return ([], $pins);
    }

    if ($re eq "x") {
	return ([$pin_space], $pins);
    }
    my ($have, $dont) = split_re($pins, $re, $re_target);

    #pin( 0, 3000, 3000, $$pins[0]);
    my $final = [];
    # for @$have, make the matching token first (so as to be $lbl in pin())
    for my $r (@$have) {
	my $o = $$r[2];
	my $n = $$r[2];
	$n = tofront( $re, $o ) if ($re_target eq "label");
	my $np = [ $$r[0], $$r[1], $n, $$r[3], $$r[4] ];
	push @$final, $np;
    }
    if ($sort eq "l") {
	my @arr = @$final;
	@arr = sort pinsort_lbl @arr;
	$final = [ @arr ];
    } elsif ($sort eq "n") {
	my @arr = @$final;
	@arr = sort pinsort_num @arr;
	$final = [ @arr ];
    }

    ( $final, $dont );
}

sub getpins( $ $ $ $ ) {
    my $pins = shift;
    my $lst = shift;
    my $sort = shift;
    my $re_target = shift;

    if (!defined($pins) || ref($pins) ne "ARRAY" ) {
	return ([],[]);
    }
    if (!defined($lst) || $lst eq "") {
	return ([], $pins);
    }

    my $final = [];
    my $dont = $pins;
    my @re = split(/,/, $lst);
    for my $re (@re) {
	my $tt;
	($tt, $dont) = getpinss( $dont, $re, $sort, $re_target);
	push @$final, @$tt;
    }
    ( $final, $dont );
}

sub parse_args( $ $ ) {
    my $pins = shift;
    my $args = shift;
    my $l = [];
    my $r = [];
    my $t = [];
    my $b = [];
    my $n = []; # pins not used by l r t or b
    my %parameter;

    #print "parse_args():\n";
    my $tmp = $pins;
    $args =~ s/^ //;
    $args =~ s/ $//;
    my @token = split(/ /, $args);
    for (@token) {

	# check for flags, i.e. no ":value" part
	if (m/^([^:]+)$/) {
	    $parameter{$1} = 1;
	    next;
	}

	# from here, we have "key:value"
	# key lbrtn are special
	if (m/^([lbrtn]+):([^:]*)(:([ln]))?$/ || m/^([LBRTN]+):([^:]*)(:([ln]))?$/) {
	    my $tgt = $1;
	    my $re  = $2;
	    my $sort = "";
	    if (defined($4)) { $sort = $4; }

	    my $re_target = "label";
	    if (m/^[LBRTN]/) { $re_target = "pin_num"; }
	    my $aa;
	    ($aa, $tmp) = getpins( $tmp, $re, $sort, $re_target );
	    my $len = length($tgt);
	    my @lst = split(//, $tgt);
	    if ($parameter{shuffle}) {
		my @dst = @lst;
		while (@$aa) {
		    if (@dst == 0) { @dst = @lst; }
		    my $p = shift @$aa;
		    my $d = shift @dst;
		    if ($d =~ m/l/i) { push @$l, $p; }
		    if ($d =~ m/b/i) { push @$b, $p; }
		    if ($d =~ m/r/i) { push @$r, $p; }
		    if ($d =~ m/t/i) { push @$t, $p; }
		    if ($d =~ m/n/i) { push @$n, $p; }
		}
	    } else {
		my $sc = int((@$aa + $len - 1)/$len);
		my $ix = 0;
		for (@lst) {
		    my $sta = $ix * $sc;
		    my $end = $sta + $sc - 1;
		    if ($end >= @$aa) { $end = @$aa - 1; }
		    my @part = @$aa[$sta .. $end];
		    if (m/l/i) { push @$l, @part; }
		    if (m/b/i) { push @$b, @part; }
		    if (m/r/i) { push @$r, @part; }
		    if (m/t/i) { push @$t, @part; }
		    if (m/n/i) { push @$n, @part; }
		    $ix++;
		}
	    }
	    next;
	}

	# generic key:value
	if (m/^([^:]+):(.*)/) {
	    $parameter{$1} = $2;
	    next;
	}

	# empty key not allowed
	Warn("empty key not allowed: <$_>");
    }
    # any remaining pins are saved to pin set "n"
    push @$n, @$tmp;

    my $order = $parameter{order};
    if ($order) {
	my @lst = split(//, $order);
	for (@lst) {
	    if (m/L/) { $l = [ reverse(@$l) ]; next; }
	    if (m/B/) { $b = [ reverse(@$b) ]; next; }
	    if (m/R/) { $r = [ reverse(@$r) ]; next; }
	    if (m/T/) { $t = [ reverse(@$t) ]; next; }
	    if (m/l/) { next; }
	    if (m/b/) { next; }
	    if (m/r/) { next; }
	    if (m/t/) { next; }
	    Warn("unknown order ($_): <$args>");
	}
    }

    #for my $k (sort keys %parameter) {
    #my $v = $parameter{$k};
    #print "$k: $v\n";
    #}
    [ $pins, $l, $b, $r, $t, $n, { %parameter } ];
}
########################################

sub data_str( $ $ $ $ ) {
    my $sieve = shift;
    my $act = shift;
    my $dir = shift;
    $_ = shift;

    chomp;
    my $line = $_;		# for error messages etc.
    tr/\t / /s;
    s/^ //;
    s/ $//;
    s/^\#.*$//;
    return if (m/^$/);

    if (m/^!/) {		# handle action
	s/^!//;
	if (m/^include (.*)/) { # include file
	    my $file = $1;
	    if ($file =~ m/^\//) {
	    } elsif ($file =~ m/^~(\/.*)/) {
		$file = $ENV{HOME} . $1;
	    } else {
		$file = "$dir/$file";
	    }
	    if (&data_read($sieve, $act, $file)) {
		Warn("cannot open file: \"$file\"")
	    }
	} elsif (m/^(f|m|j) /) { # pin set definitions
	    push @$sieve, $_;
	} elsif (m/^> (.+)/) {	# Output (symbol file) definitions
	    my @fld = split(/ /, $1);
	    if (@fld != 4) {
		Warn("need Extension, Pkgs, Pin_set, and Style: <$line>");
	    }
	    push @$act, [ @fld, "", {} ]; # reserve space for arg and local attributes
	} elsif (m/^ arg( .+)/) { # arguments
	    my $ref = $$act[$#$act];
	    $$ref[4] .= $1;
	} elsif (m/^ ([^= ]+)=(.*)$/) { # local attributes
	    my $ref = $$act[$#$act];
	    my $k = $1;
	    my $v = $2;
	    if (!defined($$ref[5]{$k})) { $$ref[5]{$k} = []; }
	    push @{$$ref[5]{$k}}, $v;
	} else {
	    Warn("Unhandled action line: <$line>");
	}
    } elsif (m/^([^= ]+)=(.*)$/i) {
	my $k = $1;
	my $v = $2;
	if (defined($v) && $v ne "") {
	    if (!defined($gattr{$k})) {
		$gattr{$k} = [];
	    }
	    my $r = $gattr{$k};
	    push @$r, $v;
	}
    } elsif (@header == 0) {
	@header = split;
	for (my $ix = 0; $ix < @header; $ix++) {
	    $header{$header[$ix]} = $ix;
	}
	$pin_line = 0;
    } else {
	my @vec = split(/ /, $_, @header + 2);

	if (@vec == @header + 1) { # missing label, add empty label
	    push @vec, " ";
	} elsif (@vec != @header + 2) {
	    Warn("too short pin line, ignored");
	    return;
	}
	my $text = pop @vec;
	my $type = pop @vec;
	my @tok = split(/ /, $text);
	push @pins, [ [ @vec ], $type, [ @tok ], $text, $pin_line++ ];
    }
}

sub data_read( $ $ $ ) {
    my $sieve = shift;
    my $act = shift;
    my $file = shift;

    my $dir = `dirname $file`;
    chomp $dir;
    my $fh_inp;

    open($fh_inp, "$file") || return -1;
    while (<$fh_inp>) {
	data_str($sieve, $act, $dir, $_);
    }
    close($fh_inp);
    0;
}

sub header_inv( $ $ $ ) { # invisible header items
    my $llx = shift;
    my $lly = shift;
    my $flag = shift;

    $text_colour = 5;
    $text_vis = 0;
    $text_show = 0;
    $text_align = 0;

    if (!defined($attr{author})) {
	my ($name,$passwd,$uid,$gid,$quota,$comment,$gcos,$dir,$shell,$expire) = getpwuid($<);
	if (defined($gcos)) {
	    my ($a, $b) = split(/,/, $gcos, 2);
	    $name = $a;
	}
	$attr{author} = [ $name ];
    }
    if (!defined($attr{"copyright"   })) { $attr{"copyright"}    = [ $attr{"author"} ]; }
    if (!defined($attr{"dist-license"})) { $attr{"dist-license"} = [ "GPL" ]; }
    if (!defined($attr{"use-license" })) { $attr{"use-license"}  = [ "unlimited" ]; }

    my $v = $attr{documentation};
    my @doc = ();
    if (defined($v) && ref($v) eq "ARRAY" && @$v > 0) {
	@doc = @$v;
    }
    my @upper = qw{author copyright dist-license use-license}; # thoose with defaults above
    my %upper;
    my $upper_cnt = 0;
    for my $k (@upper) {
	$upper_cnt += @{$attr{$k}}+0;
	$upper{$k} = 1;
    }
    my   @hdr_vis_attr = qw/refdes description value source sublabel/; # double check with header_vis()
    my   %hdr_vis_attr;
    for (@hdr_vis_attr) { $hdr_vis_attr{$_} = 1; }
    my @lower = ();
    my $lower_cnt = 0;
    for my $k (keys %attr) {
	next if ($upper{$k});
	next if ($hdr_vis_attr{$k});
	next if ($k eq "documentation");
	next if ($attr_skip{$k});
	next if ($attr_special{$k});
	#print " inv: $k\n";
	push @lower, $k;
	$lower_cnt += @{$attr{$k}}+0;
    }

    my $cnt = $upper_cnt + 1;
    if ($flag) { $cnt +=  $lower_cnt + 1 + @doc; }
    moveto($llx, $lly + $cnt * text_height( $sztext ));
    print $fh_out "v $VERSION\n";
    for my $k (@upper) {
	for my $str (@{$attr{$k}}) { text($sztext, "$k=$str"); }
    }
    rmoveto(0, -text_height($sztext));

    if ($flag) {
	for my $k (sort @lower) {
	    for my $str (@{$attr{$k}}) { text($sztext, "$k=$str"); }
	}
	rmoveto(0, -text_height($sztext));
	for (@doc) {
	    text($sztext, "documentation=$_");
	}
    }
}

sub attr_last($) {
    my $k = shift;
    my $r = $attr{$k};
    my $res;
    if (defined($r)) {
	my $last = $#{$r};
	$res = $$r[$last];
    }
    return $res;
}
sub header_vis( $ $ $ ) {
    my $x = shift;
    my $y = shift;
    my $pos = shift;

    $text_colour = 9;
    $text_vis = 1;
    $text_show = 1;

    # double check with @hdr_vis_attr in header_inv():
    my $refdes      = attr_last("refdes");
    my $description = attr_last("description");
    my $value       = attr_last("value");
    my $source      = attr_last("source");
    my $sublabel    = attr_last("sublabel");

    # default values
    if (!$refdes) { $refdes = "U?"; }
    if (!$value) {
	my $def = attr_last("device");
	if ($def) { $value = $def; }
	$def = attr_last("part-number");
	if ($def) { $value = $def; }
    }

    # total height
    my $toth = 0;
    $toth += $sztext; # for refdes=xx
    if ($description) { $toth += $szsmall; }
    if ($value)       { $toth += $sztext; }
    if ($source)      { $toth += $sztext; }
    if ($sublabel)    { $toth += $szsmall; }

    # find initial position
    if (!$pos) { $pos = "c"; }
    if ($pos eq "t") {
	moveto($x , $y - text_height($sztext));
	$text_align = 3;
    } elsif ($pos eq "b") {
	moveto($x , $y + text_height($toth));
	$text_align = 3;
    } elsif ($pos eq "c") {
	moveto($x , $y + text_height($toth)/2);
	$text_align = 4;
    } elsif ($pos eq "a") {
	moveto($x , $y + 1 * text_height($sztext));
	$text_align = 3;
    } else {
	die("unknown position <$pos>");
    }

    if ($source) {
	$text_show = 0;
	text($sztext, "refdes=$refdes");
	$text_show = 1;
    } else {
	text($sztext, "refdes=$refdes");
    }
    if ($pos eq "a") {
	moveto($x , $y - 0.3 * text_height($sztext));
    }
    if ($description) { text($szsmall, "description=$description"); }
    if ($value)       { text($sztext, "value=$value"); }
    if ($source)      {
	my $file = proc_format($source);
	text($sztext, "source=$file");
    }
    if ($sublabel)    { text($szsmall, "sublabel=$sublabel"); }
}

sub rnd( $ ) {
    my $dbl = shift;
    int( $dbl + 0.5 );
}

sub snap( $ ) {
    my $dbl = shift;
    rnd( $dbl/$grid ) * $grid;
}

# this is my first try, but I think I'll prefer pinnum's to be horisontal
sub pin2( $ $ $ $ ) {
    my $rot = shift;
    my $x = shift;
    my $y = shift;

    my $pinref = shift;

    return if ($pinref == $pin_space);
    my $num = $$pinref[0][$cur_pkg];
    return if ($num eq "-");
    my $type = $$pinref[1];
    my @tok = @{$$pinref[2]};
    my $lbl = shift  @tok;
    my $alt = join(" ", @tok);
    if (!defined($alt)) {
	$alt = "";
    } else {
	# trim and lowercase to make it take less space
	$alt =~ s/_//g;
	$alt = "\L$alt";
    }

    $rot %= 360;
    $x = rnd($x);
    $y = rnd($y);

    my $rad = $twopi * $rot / 360;
    my $sin = sin($rad);
    my $cos = cos($rad);
    #print "rot: $rot $ToTheLeft $dx $dy\n";

    my $x2 = $x;
    my $y2 = $y;
    my $x3 = $x;
    my $y3 = $y;
    my $x4 = $x;
    my $y4 = $y;

    my $lx = $x;
    my $ly = $y;
    my $la = 0;

    my $ax = $x;
    my $ay = $y;
    my $aa = 2;

    my $nx = $x;
    my $ny = $y;
    my $na = 6;

    my $tx = $x;
    my $ty = $y;
    my $ta = 8;

    $x2 += $pin_length * $cos;
    $y2 += $pin_length * $sin;
    $x2 = snap($x2);
    $y2 = snap($y2);

    $x3 += rnd(0.3 * $pin_length * $cos);
    $y3 += rnd(0.3 * $pin_length * $sin);
    $x4 += rnd(0.7 * $pin_length * $cos);
    $y4 += rnd(0.7 * $pin_length * $sin);

    $ax = $lx -= rnd(0.25 * $pin_length * $cos);
    $ay = $ly -= rnd(0.25 * $pin_length * $sin);

    # horisontal or vertical text
    my $ang;
    if (45 < $rot && $rot < 135  || 225 < $rot && $rot < 315) {
	$ang = 270;
    } else {
	$ang = 0;
    }

    # where to attach label and alt text
    # see docs/wiki/media/geda/fileformat_textgraphic.jpg for attachment points
    if (45 < $rot && $rot <= 225) {
	$la = 0;
	$aa = 2;
    } else {
	$la = 6;
	$aa = 8;
    }

    # adj. spacing so alt stay clear of label
    if ($ang) {
	$ax -= 0.05 * $pin_length;
    } else {
	$ay -= 0.05 * $pin_length;
    }

    # where to attach and place pinnum/seq/type text
    my $ll = 0; # pos for pinnum/seq
    my $ul = 1; # pos for pintype
    if (($rot % 90) == 0) {
	$ll = 1;
    } else {
	if ($rot <= 1*45) {
	    $ll = 0;
	} elsif ($rot <  2*45) {
	    $ll = 1;
	} elsif ($rot <  3*45) {
	    $ll = 0;
	} elsif ($rot <  4*45) {
	    $ll = 1;
	} elsif ($rot <= 5*45) {
	    $ll = 0;
	} elsif ($rot <  6*45) {
	    $ll = 1;
	} elsif ($rot <  7*45) {
	    $ll = 0;
	} else {
	    $ll = 1;
	}
	if ($ll) { $ul = 0; }
    }

    #my $dd = 0;
    my $dd = 0.15 * $pin_length;
    if ($rot <= 45 || 5*45 < $rot) {
	# left of text is inner, i.e. $x3 $y3
	if ($ll) {
	    $na = 0;
	    $nx = $x3 - rnd($dd * $sin);
	    $ny = $y3 + rnd($dd * $cos);
	} else {
	    $na = 6;
	    $nx = $x4 - rnd($dd * $sin);
	    $ny = $y4 + rnd($dd * $cos);
	}
	if ($ul) {
	    $ta = 2;
	    $tx = $x3 + rnd($dd * $sin);
	    $ty = $y3 - rnd($dd * $cos);
	} else {
	    $ta = 8;
	    $tx = $x4 + rnd($dd * $sin);
	    $ty = $y4 - rnd($dd * $cos);
	}
    } else {
	# left of text is outer, i.e. $x4 $y4
	if ($ll) {
	    $na = 0;
	    $nx = $x4 + rnd($dd * $sin);
	    $ny = $y4 - rnd($dd * $cos);
	} else {
	    $na = 6;
	    $nx = $x3 + rnd($dd * $sin);
	    $ny = $y3 - rnd($dd * $cos);
	}
	if ($ul) {
	    $ta = 2;
	    $tx = $x4 - rnd($dd * $sin);
	    $ty = $y4 + rnd($dd * $cos);
	} else {
	    $ta = 8;
	    $tx = $x3 - rnd($dd * $sin);
	    $ty = $y3 + rnd($dd * $cos);
	}
    }

    # the second point is the active point for atting nets
    print $fh_out "P $x $y $x2 $y2  $pin_colour 0 1\n"; # the last two are: pintype=NORMAL_PIN=0, whichend=1
    print $fh_out "{\n";

    print $fh_out "T $lx $ly $cllbl $szlbl 1 1  $ang $la  1\n";
    print $fh_out "pinlabel=$lbl\n";
    if ($alt) {
	print $fh_out "T $ax $ay $clalt $szalt 1 1  $ang $aa  1\n";
	print $fh_out "pinalt=$alt\n";
    }

    print $fh_out "T $nx $ny $clnum $sznum 1 1  $ang $na  1\n";
    print $fh_out "pinnumber=$num\n";
    print $fh_out "T $nx $ny $clseq $szseq 0 1  $ang $na  1\n";
    $pin_seq++;
    print $fh_out "pinseq=$pin_seq\n";

    print $fh_out "T $tx $ty $cltyp $sztyp 0 1  $ang $ta  1\n";
    print $fh_out "pintype=$type\n";

    print $fh_out "}\n";
}

sub pin_cnt($) {
    my $input = shift;

    my $pins   = $$input[0];
    my $left   = $$input[1];
    my $bottom = $$input[2];
    my $right  = $$input[3];
    my $top    = $$input[4];
    my $NC     = $$input[5];
    my $parameter = $$input[6];

    my $cnt = 0;

    for my $k (@$left, @$bottom, @$right, @$top) {
	next if ($k == $pin_space);
	next if ($$k[0][$cur_pkg] eq "-");
	$cnt++;
    }

    $cnt;
}
sub pin( $ $ $ $ ) {
    my $rot = shift;
    my $x = shift;
    my $y = shift;
    my $pinref = shift;

    return if ($pinref == $pin_space);
    my $num = $$pinref[0][$cur_pkg];
    return if ($num eq "-");
    my $type = $$pinref[1];
    my @tok = @{$$pinref[2]};
    my $lbl = shift  @tok;
    my $alt = join(" ", @tok);
    if (!defined($alt)) {
	$alt = "";
    } else {
	# trim and lowercase to make it take less space
	$alt =~ s/_//g;
	$alt = "\L$alt";
    }

    $rot %= 360;
    $x = rnd($x); # passive endpoint of pin line
    $y = rnd($y);

    my $rad = $twopi * $rot / 360;
    my $sin = sin($rad);
    my $cos = cos($rad);
    #print "rot: $rot $ToTheLeft $dx $dy\n";

    my $x2 = $x; # active endpoint of pin line
    my $y2 = $y;

    my $lx = $x; # attachment point for pinlabel
    my $ly = $y;
    my $la = 0;

    my $ax = $x; # attachment point for pinalt
    my $ay = $y;
    my $aa = 2;

    $x2 += $pin_length * $cos;
    $y2 += $pin_length * $sin;
    $x2 = snap($x2);
    $y2 = snap($y2);

    # since the active end is snapped, we have to adjust the angle
    my $pin_l = sqrt( ($x2 - $x) * ($x2 - $x) + ($y2 - $y) * ($y2 - $y) );
    $sin = ($y2 - $y) / $pin_l;
    $cos = ($x2 - $x) / $pin_l;
    $rad = atan2( $y2 - $y, $x2 - $x );

    $ax = $lx -= rnd($pin_lblspace * $pin_length * $cos);
    $ay = $ly -= rnd($pin_lblspace * $pin_length * $sin);

    # horisontal or vertical text

    # where to attach label and alt text
    # see docs/wiki/media/geda/fileformat_textgraphic.jpg for attachment points

    # adj. spacing so alt stay clear of label

    my $ang;
    if ($rot <= 45 || $rot > 315) { # -> right
	$ang = 0;
	$ay -= int(text_height($szalt));
	$la = 6;
	$aa = 6;
    } elsif ($rot <= 135) { # ^ up
	if (attr_last("horizontal_labels")) {
	    $ang = 0;
	    $ay -= int(text_height(0.8*$szlbl));
	    $la = 5;
	    $aa = 5;
	} else {
	    $ang = 270;
	    $ax -= int(text_height($szalt));
	    $la = 0;
	    $aa = 0;
	}
    } elsif ($rot <= 225) { # left <-
	$ang = 0;
	$ay -= int(text_height($szalt));
	$la = 0;
	$aa = 0;
    } else { # v down
	if (attr_last("horizontal_labels")) {
	    $ang = 0;
	    $ay += int(text_height(0.8*$szlbl));
	    $la = 3;
	    $aa = 3;
	} else {
	    $ang = 270;
	    $ax -= int(text_height($szalt));
	    $la = 6;
	    $aa = 6;
	}
    }

    # where to attach and place pinnum/seq/type text
    # now take the smallest box that contains the largest pinnum/seq resp. pintype
    # we want the midpoint of that box to be on the normal to the pin at its midpoint
    # and the closest point of that box should have a distance of $h from the pin line
    # since we don't know that bounding box, we'll guess
    # And the text should be flush left in that box of cause

    my $mx = rnd(($x2 + $x) / 2); # pin line mid point
    my $my = rnd(($y2 + $y) / 2);
    my $nx = $mx + $bnx; # attachment point for pinnum/seq
    my $ny = $my + $bny;
    my $tx = $mx + $btx; # attachment point for pintype
    my $ty = $my - $bty;
    # now bb mid bottom is attached to mid point of pin line

    my $dd = 0.05 * $pin_length; # wanted distance between text bb and pin line
    if ($rot <= 90) {
	my $dn;
	# we must move this lenght in the normal direction to stay clear of pin line
	$dn = $dd + $bnx * $sin;
	$nx -= $dn * $sin;
	$ny += $dn * $cos;
	# and slip this length along the pin line to stay in the middle of it
	$dn = $bny * $sin;
	$nx -= $dn * $cos;
	$ny -= $dn * $sin;

	$dn = $dd + $btx * $sin;
	$tx += $dn * $sin;
	$ty -= $dn * $cos;
	$dn = $bty * $sin;
	$tx += $dn * $cos;
	$ty += $dn * $sin;
    } elsif ( $rot <= 180 ) {
	my $dn;
	my $str = sprintf( "%s", $num);
	my $tt = length($str) / 3; # adj $bnx/y for longer/chorter string
	$dn = $dd + $tt * $bnx * $sin;
	$nx += $dn * $sin;
	$ny -= $dn * $cos;
	$dn = $tt * $bny * $sin;
	$nx -= $dn * $cos;
	$ny -= $dn * $sin;

	$dn = $dd + $btx * $sin;
	$tx -= $dn * $sin;
	$ty += $dn * $cos;
	$dn = $bty * $sin;
	$tx += $dn * $cos;
	$ty += $dn * $sin;
    } elsif ( $rot <= 270 ) {
	my $dn;
	$dn = $dd - $bnx * $sin;
	$nx += $dn * $sin;
	$ny -= $dn * $cos;
	$dn = $bny * $sin;
	$nx -= $dn * $cos;
	$ny -= $dn * $sin;

	$dn = $dd - $btx * $sin;
	$tx -= $dn * $sin;
	$ty += $dn * $cos;
	$dn = $bty * $sin;
	$tx += $dn * $cos;
	$ty += $dn * $sin;
    } else {
	my $dn;
	my $str = sprintf( "%d", $num);
	my $tt = length($str) / 3; # adj $bnx/y for longer/chorter string
	$dn = $dd - $tt * $bnx * $sin;
	$nx -= $dn * $sin;
	$ny += $dn * $cos;
	$dn = - $tt * $bny * $sin;
	$nx += $dn * $cos;
	$ny += $dn * $sin;

	$dn = $dd - $btx * $sin;
	$tx += $dn * $sin;
	$ty -= $dn * $cos;
	$dn = - $bty * $sin;
	$tx -= $dn * $cos;
	$ty -= $dn * $sin;
    }

    $nx = rnd($nx);
    $ny = rnd($ny);
    $tx = rnd($tx);
    $ty = rnd($ty);

    # the second point is the active point for atting nets

    # the last two are: pintype=NORMAL_PIN=0, whichend=1
    printf $fh_out "P %5d %5d  %5d %5d  %d 0 1\n", $x, $y, $x2, $y2, $pin_colour;
    print $fh_out "{\n";

    if ($lbl) { # permit emtpy/no label
	printf $fh_out $text_format, $lx, $ly, $cllbl, $szlbl, 1, 1, $ang, $la;
	print $fh_out "pinlabel=$lbl\n";
    }
    if ($alt) {
	printf $fh_out $text_format, $ax, $ay, $clalt, $szalt, 1, 1, $ang, $aa;
	print $fh_out "pinalt=$alt\n";
    }

    printf $fh_out $text_format, $nx, $ny, $clnum, $sznum, 1, 1, 0, 7;
    print $fh_out "pinnumber=$num\n";
    printf $fh_out $text_format, $nx, $ny, $clseq, $szseq, 0, 1, 0, 7;
    $pin_seq++;
    print $fh_out "pinseq=$pin_seq\n";

    printf $fh_out $text_format, $tx, $ty, $cltyp, $sztyp, 0, 1, 0, 7;
    print $fh_out "pintype=$type\n";

    print $fh_out "}\n";
    if (defined(attr_last("label-net"))) {
	printf $fh_out $text_format, $lx, $ly, $cllbl, $szlbl, 0, 1, $ang, $la;
	print $fh_out "net=$lbl:$num\n";
    }
    if (defined(attr_last("pin-arrow")) && ($type eq "in" || $type eq "out")) {
	my $alen = $pin_lblspace * $pin_length * 0.75;
	my $aup  = $alen * 0.3;
	my $dx = rnd($alen * $cos);
	my $dy = rnd($alen * $sin);
	my ($xa, $ya, $xb, $yb);
	if ($type eq "in") {
	    $xa = $xb = $x + $dx;
	    $ya = $yb = $y + $dy;
	} else { # "out"
	    $xa = $xb = $x - $dx;
	    $ya = $yb = $y - $dy;
	}
	$xa -= rnd($aup * $sin);
	$ya += rnd($aup * $cos);
	$xb += rnd($aup * $sin);
	$yb -= rnd($aup * $cos);
	printf $fh_out "H $pin_colour 0 0   0 -1 -1   1 -1 -1 -1 -1 -1  4\n";
	printf $fh_out "M $x,$y\n";
	printf $fh_out "L $xa,$ya\n";
	printf $fh_out "L $xb,$yb\n";
	printf $fh_out "Z\n";
    }
}

########################################

sub showarg( $ ) {
    my $input = shift;

    my $pins   = $$input[0];
    my $left   = $$input[1];
    my $bottom = $$input[2];
    my $right  = $$input[3];
    my $top    = $$input[4];
    my $NC     = $$input[5];
    my $parameter = $$input[6];

    print $fh_out "##############################\n";
    print $fh_out "Input file: $cur_inp\n";
    print $fh_out "%d <$cur_dir>\n";
    print $fh_out "%n <$cur_nam>\n";
    print $fh_out "%p <$cur_pkg>\n";
    print $fh_out "%l <$cur_lbl>\n";
    print $fh_out "//// \$pin_set($cur_set):\n";
    showpins(\@header, $pin_set{$cur_set}); # ZZZ
    print $fh_out "//// All pins ($cur_set):\n";
    showpins(\@header, $pins);
    print $fh_out "//// Left:\n";
    showpins(\@header, $left);
    print $fh_out "//// Bottom:\n";
    showpins(\@header, $bottom);
    print $fh_out "//// Right:\n";
    showpins(\@header, $right);
    print $fh_out "//// Top:\n";
    showpins(\@header, $top);
    print $fh_out "//// Not used:\n";
    showpins(\@header, $NC);
    print $fh_out "\n//// Attributes\n";
    for my $key (sort keys %attr) {
	my $val = $attr{$key};
	for (@$val) {
	    print $fh_out "$key: $_\n";
	}
    }
    print $fh_out "\n//// Parameters\n";
    #print Dumper($parameter);
    for my $key (sort keys %$parameter) {
	my $val = $$parameter{$key};
	print $fh_out "$key: $val\n";
    }
    print $fh_out "\n";
}
$style{showarg} = \&showarg;

sub circle( $ ) {
    my $input = shift;

    my $pins   = $$input[0];
    my $parameter = $$input[6];
    my $diameter = $$parameter{diameter};

    my $p = $pins;
    my $cr;

    if ($diameter && $diameter > 0) {
	$cr = $pin_dist * $diameter / 2;
    } else {
	my $f = 2;
	if (@$p > 30) { $f -= ( @$p - 30 ) / 40; }
	if (@$p > 70) { $f = 1; }
	$cr = @$p * $f * $pin_dist / $twopi;
    }
    $cr = rnd($cr/$pin_dist)*$pin_dist;
    my $cx = $pin_length + $cr;
    my $cy = $cx;

    my $rot = 0;
    my $step = 360/@$p;
    my $k;

    # text
    header_inv( $cx - $cr - $pin_length, $cy + $cr + 2 * $pin_length, 1);
    header_vis( $cx, $cy, "c");

    # draw circumference
    moveto($cx + $cr, $cy);
    $rot = $step;
    for (my $ix = 0; $ix < @$p; $ix++) {
	my $rad = $twopi * $rot / 360;
	lineto( $cx + $cr * cos($rad), $cy + $cr * sin($rad) );
	$rot += $step;
    }
    # draw pins
    $rot = 0;
    for $k (@$p) {
	my $rad = $twopi * $rot / 360;
	pin2( $rot, $cx + $cr * cos($rad), $cy + $cr * sin($rad), $k);
	$rot += $step;
    }
}
$style{circle} = \&circle;

sub conn( $ ) {
    my $input = shift;

    my $pins   = $$input[0];
    my $left   = $$input[1];
    my $bottom = $$input[2];
    my $right  = $$input[3];
    my $top    = $$input[4];
    my $NC     = $$input[5];
    my $parameter = $$input[6];

    my $width  = $$parameter{w};
    if (!$width) { $width = 0.07; }
    $width *= $pin_dist;

    if (@$bottom || @$top) {
	print "conn style: no bottom nor top pins, sorry\n";
	return;
    }

    my $cnt = @$pins;

    my $xmin = $pin_length;
    my $xmax = $xmin + $width;
    my $xmid = int(($xmax + $xmin) / 2);

    my $ymin  = 0;
    my $ymax  = $ymin + $cnt * $pin_dist;
    my $ytext = $ymax + 3*$pin_dist;

    # draw box
    header_inv( $xmin-$pin_length, $ytext, 1);
    header_vis( $xmid, $ymax+0.9*$pin_dist, "b");

    my $dy =  0.6*$pin_dist;
    my $dY = +0.7*$pin_dist;
    moveto($xmin, $ymax+$dy);
    lineto($xmin, $ymin+$dY);
    lineto($xmax, $ymin+$dY);
    lineto($xmax, $ymax+$dy);
    lineto($xmin, $ymax+$dy);

    my $k;
    my $ix;

    for (my $ix = 0; $ix < @$left; $ix++) {
	my $k = $$left[$ix];
	pin( 180, $xmin, $ymax - $ix * $pin_dist, $k);
    }
    for (my $ix = 0; $ix < @$right; $ix++) {
	my $k = $$right[$ix];
	pin( 0, $xmax, $ymin + ($ix+1) * $pin_dist, $k);
    }
}
$style{conn} = \&conn;

# dual in line with a header shroud, arrow in upper left
# pins in cable header order
sub hdr( $ ) {
    my $input = shift;

    my $pins   = $$input[0];
    my $left   = $$input[1];
    my $bottom = $$input[2];
    my $right  = $$input[3];
    my $top    = $$input[4];
    my $NC     = $$input[5];
    my $parameter = $$input[6];

    my $width  = $$parameter{w};

    if (!$width) { $width = 5; }
    $width *= $pin_dist;

    my $cnt = @$pins;
    my $ps = int($cnt / 2);
    my $odd = $cnt - 2 * $ps;

    my $xmin = $pin_length;
    my $xmax = $xmin + $width;
    my $xmid = int(($xmax + $xmin) / 2);

    my $ymin = 0;
    my $yl   = $ymin + $pin_dist; # y position of lowest pin
    if (!$odd) { $yl += int($pin_dist/2); }
    my $yu   = $yl   + ($ps - 1 + $odd) * $pin_dist; # y position of highest pin
    my $ymax = $yu   + $pin_dist;
    my $ytext = $ymax + 2.5*$pin_dist;

    # draw box
    header_inv( $xmin, $ytext, 1);
    header_vis( $xmid, $ymax, "b");

    my $save;
    $save = $line_width;
    $line_width = $line_width/2;

    moveto($xmin, $ymax);
    lineto($xmin, $ymin);
    lineto($xmax, $ymin);
    lineto($xmax, $ymax);
    lineto($xmin, $ymax);

    my $th = 70;
    my $ymid = int(($ymax + $ymin)/2);
    my $half = 0.7 * $pin_dist;

    moveto($xmin      , $ymid + $half);
    lineto($xmin + $th, $ymid + $half);
    lineto($xmin + $th, $ymax - $th);
    lineto($xmax - $th, $ymax - $th);
    lineto($xmax - $th, $ymin + $th);
    lineto($xmin + $th, $ymin + $th);
    lineto($xmin + $th, $ymid - $half);
    lineto($xmin      , $ymid - $half);
    moveto($xmin + $th, $yu + 0.7*$th);
    lineto($xmin      , $yu);
    lineto($xmin + $th, $yu - 0.7*$th);
    $line_width = $save;

#    printf "V %5d %5d  %4d %d %d 0  0 -1 -1  0 -1 -1 -1 -1 -1\n",
#	$xmin+$pin_dist, int($ymax-0.75*$pin_dist), int(0.3 * $pin_dist), $line_clr, $line_width;

    $save = $pin_lblspace;
    $pin_lblspace = 0.5;

    my $k;
    my $ix;
    for ($ix = 0; $ix < 2*$ps; $ix +=2) {
	my $step = int($ix / 2);
	$k = $$pins[$ix];
	pin( 180, $xmin, $yu - $step * $pin_dist, $k);
	$k = $$pins[$ix+1];
	pin(   0, $xmax, $yu - $step * $pin_dist - $pin_dist/2, $k);
    }
    if ($ix < $cnt) {
	my $step = int($ix / 2);
	$k = $$pins[$ix];
	pin( 180, $xmin, $yu - $step * $pin_dist, $k);
    }
    $pin_lblspace = $save;

}
$style{hdr} = \&hdr;

sub rect( $ ) {
    my $input = shift;

    my $pins   = $$input[0];
    my $left   = $$input[1];
    my $bottom = $$input[2];
    my $right  = $$input[3];
    my $top    = $$input[4];
    my $NC     = $$input[5];
    my $parameter = $$input[6];

    # ulring, see below
    my @arg     = qw( w h corner skew radi cut topskip ulcut);
    my @default =   ( 0,0,1,     0,   0,   0,  0,      0,   );

    for (my $ix = 0; $ix < @arg; $ix++) {
	my $key = $arg[$ix];
	my $def = $default[$ix];
	my $val = $$parameter{$key};
	if (defined($val)) {
	    if ($val =~ m/^[-+0-9.]+$/) {
		# ok
	    } else {
		Warn("numerical value exspected <$_:$val>");
	    }
	} else {
	    $$parameter{$key} = $def;
	}
    }

    my $width       = $$parameter{w};
    my $height      = $$parameter{h};
    my $rect_corner = $$parameter{corner};
    my $rect_skew   = $$parameter{skew};
    my $radi        = $$parameter{radi};
    my $cut         = $$parameter{cut};
    my $topskip     = $$parameter{topskip};
    my $ulcut       = $$parameter{ulcut};
    my $ulring      = $$parameter{ulring};
    my $dogear      = $$parameter{dogear};
    my $header      = $$parameter{header};

    $radi   *= $pin_dist;
    $cut    *= $pin_dist;
    $ulcut  *= $pin_dist;

    # rectangle size
    if (@$left || @$right || @$bottom || @$top) {
	# fine, use the choosen ones
    } else {
	Warn("please specify l, b, r, and/or t");
	return;
    }

    my $vc = @$left; # vertical count
    if ($vc < @$right) { $vc = @$right; }
    my $hc = @$top; # horisontal count
    if ($hc < @$bottom) { $hc = @$bottom; }

    my $xmin = 0;
    if (@$left) { $xmin = $pin_length; }
    my $xmax;
    if ($width) {
	$xmax = $xmin + $width * $pin_dist;
    } else {
	my $xpins = $hc;
	if ( $xpins < 2 ) { $xpins = 2; }
	$xmax = $xmin + ($xpins-1 + 2*$rect_corner) * $pin_dist;
    }
    my $xmid = int(($xmax + $xmin) / 2);

    my $ymin = 0;
    if (@$bottom) { $ymin = $pin_length; }
    my $ymax;
    if ($height) {
	$ymax = $ymin + $height * $pin_dist;
    } else {
	$ymax = $ymin + ($vc-1 + 2*$rect_corner + $topskip) * $pin_dist;
    }
    my $ytext = $ymax + $pin_dist;
    if (@$top) { $ytext += $pin_length; }
    my $ymid = int(($ymax + $ymin) / 2);

    # draw attributes
    header_inv( $xmin, $ytext, 1);
    if ($header) {
	header_vis( $xmid, $ymax, $header);
    } else {
	if (@$top == 0) {
	    header_vis( $xmid, $ymax, "t");
	} else {
	    header_vis( $xmid, $ymid, "c");
	}
    }

    # draw box
    my $gap = abs($radi);
    if ($cut) { $gap = $cut; }
    my $ulgap = $ulcut;
    if (!$ulgap) { $ulgap = $gap; }

    moveto($xmin     , $ymax-$ulgap); lineto($xmin       , $ymin+$gap);
    moveto($xmin+$gap, $ymin       ); lineto($xmax-$gap  , $ymin     );
    moveto($xmax     , $ymin+$gap  ); lineto($xmax       , $ymax-$gap);
    moveto($xmax-$gap, $ymax       ); lineto($xmin+$ulgap, $ymax     );
    if ($cut) {		# straight cut
	moveto($xmin+$ulgap, $ymax     ); lineto($xmin     , $ymax-$ulgap);
	moveto($xmin       , $ymin+$cut); lineto($xmin+$cut, $ymin       );
	moveto($xmax-$cut  , $ymin     ); lineto($xmax     , $ymin+$cut  );
	moveto($xmax       , $ymax-$cut); lineto($xmax-$cut, $ymax       );
    } elsif ($radi == 0) {
	# sharp corner
	moveto($xmin+$ulcut, $ymax     ); lineto($xmin     , $ymax-$ulcut);
    } elsif ($radi > 0) {			# rounded out
	if ($ulcut) {
	    moveto($xmin+$ulcut, $ymax     ); lineto($xmin     , $ymax-$ulcut);
	} else {
	    arc( $xmin+$radi, $ymax-$radi, $radi,  90, 90);
	}
	arc( $xmin+$radi, $ymin+$radi, $radi, 180, 90);
	arc( $xmax-$radi, $ymin+$radi, $radi, 270, 90);
	arc( $xmax-$radi, $ymax-$radi, $radi,   0, 90);
    } else {			# rounded in
	if ($ulcut) {
	    moveto($xmin+$ulcut, $ymax     ); lineto($xmin     , $ymax-$ulcut);
	} else {
	    arc( $xmin, $ymax, -$radi, 270, 90);
	}
	arc( $xmin, $ymin, -$radi,   0, 90);
	arc( $xmax, $ymin, -$radi,  90, 90);
	arc( $xmax, $ymax, -$radi, 180, 90);
    }

    if ($dogear) {
	moveto($xmin+$ulgap, $ymax     );
	lineto($xmin+$ulgap, $ymax-$ulgap);
	lineto($xmin       , $ymax-$ulgap);
    }

    if ($ulring) {
	if ( $ulring !~ m/^([-+0-9.]+)(\/([-+0-9.]+))?(\/([-+0-9.]+))?$/ ) {
	    Warn("illegal ulring: <$ulring>");
	    return;
	}
	my $r = $1 / 2; # diameter -> radius
	my $x = 1.0;
	my $y = 0.75;
	if (defined($3)) { $x = $3; }
	if (defined($5)) { $y = $5; }
	$r *= $pin_dist;
	$x *= $pin_dist;
	$y *= $pin_dist;
	arc( $xmin + $x, $ymax - $y, $r, 0, 360);
    }

    for (my $ix = 0; $ix < @$left; $ix++) {
	my $k = $$left[$ix];
	pin( 180, $xmin, $ymax - ($rect_corner + $rect_skew + $ix + $topskip) * $pin_dist, $k);
    }
    for (my $ix = 0; $ix < @$bottom; $ix++) {
	my $k = $$bottom[$ix];
	pin( 270, $xmin + ($rect_corner + $rect_skew + $ix) * $pin_dist, $ymin, $k);
    }
    for (my $ix = 0; $ix < @$right; $ix++) {
	my $k = $$right[$ix];
	pin( 0, $xmax, $ymin + ($rect_corner + $rect_skew + $ix) * $pin_dist, $k);
    }
    for (my $ix = 0; $ix < @$top; $ix++) {
	my $k = $$top[$ix];
	pin( 90, $xmax - ($rect_corner + $rect_skew + $ix) * $pin_dist, $ymax, $k);
    }

}
$style{rect} = \&rect;

sub cutout( $ ) {
    my $input = shift;

    my $pins   = $$input[0];
    my $left   = $$input[1];
    #my $bottom = $$input[2];
    my $right  = $$input[3];
    #my $top    = $$input[4];
    #my $NC     = $$input[5];
    my $parameter = $$input[6];

    my $width  = $$parameter{w};
    if (!$width) { $width = 5; }
    $width *= $pin_dist;

    if (@$left == 0 && @$right == 0) {
	print "missing arguments, please specify l: and/or r:\n";
	return;
    }

    my $sc = @$right;
    if ($sc < @$left) { $sc = @$left; }
    my ($loffs, $roffs) = (0,0);
    if (@$right <= @$left) { $roffs = $pin_dist/2; }
    else { $loffs = $pin_dist/2; }

    my $xmin = $pin_length;
    my $xmax = $xmin + $width;
    my $xmid = int(($xmax + $xmin) / 2);

    my $ymin = $pin_length;
    my $yl   = $ymin + 1.5*$pin_dist; # y position of lowest pin
    my $yu   = $yl   + ($sc - 1) * $pin_dist; # y position of highest pin
    my $ymax = $yu   + 3 * $pin_dist;
    my $ytext = $ymax + $pin_dist;

    # draw box
    header_inv( $xmin, $ytext, 1);
    header_vis( $xmid, $ymax, "t");

    moveto($xmin, $ymin);
    walkx($xmax, $ymin);
    #walky($xmax, $ymax);
    lineto($xmax, $ymax);
    walkx($xmin, $ymax);
    lineto($xmin, $ymin);

    my $k;
    for (my $ix = 0; $ix < @$left; $ix++) {
	$k = $$left[$ix];
	pin( 180, $xmin, $yu - $ix * $pin_dist - $loffs, $k);
    }
    for (my $ix = 0; $ix < @$right; $ix++) {
	$k = $$right[$ix];
	pin(   0, $xmax, $yu - $ix * $pin_dist - $roffs, $k);
    }
}
$style{cutout} = \&cutout;

##########

sub perl_expression( $ $ ) {
    my $pin = shift;
    my $expr = shift;

    my ($num, $type, $tok, $text, $pinline) = @$pin;
    my @pinnum = @$num;
    my @token = @$tok;
    my $lbl = $$tok[0];

    eval($expr);
}

#$fh_out = *STDOUT;

sub act_sieve( $ ) {
    my $line = shift;
    #print "$line\n";
    if (m/^j/) {
	my @tok = split(/ /, $line);
	if (@tok < 3) {
	    Warn("at least one src and one dst needed <$line>");
	    return;
	}
	my $cmd = shift @tok;
	my $dst = shift @tok;
	my @arr;
	for (@tok) {
	    my $r = $pin_set{$_};
	    if (!defined($r)) {
		Warn("unknown pin set ($_): <$line>");
		return;
	    }
	    push @arr, @$r;
	}
	@arr = sort pinsort_file @arr;
	my @tst;
	my $save = -1;
	for my $k (@arr) {
	    if ($save != $$k[4]) {
		push @tst, $k;
		$save = $$k[4];
	    }
	}
	$pin_set{$dst} = [ @tst ];
	return;
    }

    # only the f and m case left
    my ($cmd, $dst, $rest, $src, $arg) = split(/ /, $line, 5);
    if (!defined($arg) && $arg ne "") {
	Warn("Not a sieve line: <$line>\n");
	return;
    }
    my $rsrc = $pin_set{$src};
    my $rdst = [];
    my $rrest = [];
    $pin_set{$dst} = $rdst;
    $pin_set{$rest} = $rrest;
    if (!defined($rsrc)) {
	Warn("unknown source pin set ($src): <$line>");
	return;
    }
    if ($cmd eq "f") {
	for (@$rsrc) {
	    if (perl_expression($_, $arg)) {
		push @$rdst, $_;
	    } else {
		push @$rrest, $_;
	    }
	}
    } elsif ($cmd eq "m") {
	for (@$rsrc) {
	    my ($num, $type, $tokref, $text) = @$_;
	    if ($text =~ m/$arg/) {
		push @$rdst, $_;
	    } else {
		push @$rrest, $_;
	    }
	}
    } else {
	Warn("Not a sieve line: <$line>\n");
    }
}

sub rm_unused( $ $ ) {
    my $rset = shift;
    my $rpkgl = shift;

    my $nset = [];
    my $flag = 0;
    for my $r (@$rset) {
	my $p = $$r[0];
	my $str = join("", @$p[@$rpkgl]);
	#print "$str\n";
	if ($str =~ m/^-+$/) {
	    # no used pins here, leave it out
	    $flag = 1;
	} else {
	    push @$nset, $r;
	}
    }
    if ($flag) { return $nset; }
    else { return $rset; }
}

sub proc_format( $ ) {
    my $str = shift;
    my $pfx = "";

    if ($str =~ m/^\./ && $str !~ m/\//) {
	$pfx = "$cur_dir$cur_nam";
    }

    $str =~ s/(^|[^%])%d/$1$cur_dir/g;
    $str =~ s/(^|[^%])%n/$1$cur_nam/g;
    $str =~ s/(^|[^%])%p/$1$cur_pkg/g;
    $str =~ s/(^|[^%])%l/$1$cur_lbl/g;

    $pfx . $str;
}

sub check_source( $ $ ) {
    my $input  = shift;
    my $src    = shift;

    if (!defined($src)) { return 0; }

    my $left   = $$input[1];
    my $bottom = $$input[2];
    my $right  = $$input[3];
    my $top    = $$input[4];

    my $file = proc_format( $src );
    my @spins;
    # drop missing pins
    for my $p (@$left, @$bottom, @$right, @$top) {
	if ($p == $pin_space) { next; }
	my $vec = $$p[0];
	if ($$vec[$cur_pkg] eq "-") { next; }
	push @spins, $p;
    }

    # start position for new symbols
    my $xmin = 10000;
    my $ysta = $pin_dist;
    if (-e $file) {
	# find maximun y for visible text, and
	# the list of all refdes
	my %refdes = ();
	my $fh_source;
	if (!open($fh_source, $file)) {
	    Warn("cannot open source symbol <$file>");
	    return -1;
	}
	{
	    my $in_T = 0;
	    while (<$fh_source>) {
		if ($in_T) {
		    if (m/^refdes=(.*)$/) {
			$refdes{$1} = 1; # mark as found
			next;
		    }
		    $in_T--;
		} else {
		    if (m/^T/) {
			my @fld = split;
			if (@fld != 10 || $fld[1] !~ m/^\d+$/ || $fld[2] !~ m/^\d+$/ || $fld[5] !~ m/^[01]$/ || $fld[9] !~ m/^\d+/) {
			    chomp;
			    Warn("invalid \"T\" line found <$_> in <$file>");
			    close($fh_source);
			    return;
			}
			$in_T = $fld[9];
			if ($fld[5] == 1) { # visible
			    # adj. start position
			    if ($xmin > $fld[1]) {
				$xmin = $fld[1];
			    }
			    if ($ysta < $fld[2]) {
				$ysta = $fld[2];
			    }
			}
			next;
		    }
		}
	    }
	}
	close($fh_source);

	my @lst = @spins;
	@spins = ();
	for my $p (@lst) {
	    my $lbl = $$p[2][0];
	    if ($refdes{$lbl}) {
		# Ok, already there, don't create new
	    } else {
		push @spins, $p;
	    }
	}
	if (@spins == 0) {
	    print "target source ($file) complete\n";
	    return 0;
	}
	if (!open($fh_out, ">>$file")) {
	    Warn("cannot append to source target file <$file>");
	    return -1;
	}
	print "appending source target $file\n";
    } else {
	if (!open($fh_out, ">>$file")) {
	    Warn("cannot create source target file <$file>");
	    return -1;
	}
	print "creating $file\n";
	$xmin = $pin_dist;
	header_inv( $xmin, $ysta + 3*text_height($sztext), 0);
	#header_vis( $pin_dist, $ysta, "b");
    }

    $text_colour = 5;
    $text_vis = 1;
    $text_show = 1;
    $text_align = 0;

    my @map = ();
    {
	my $r = $attr{"source-map"};
	if (defined($r) && ref($r) eq "ARRAY") {
	    @map = @$r;
	}
	if (@map == 0) {
	    Warn("no \"source-map\" found, skipping");
	    close($fh_out);
	    return -1;
	}
    }
    my @symb;
    my @align;
    my @dx;
    my @dy;
    my @expr;
    for (my $ix = 0; $ix < @map; $ix++) {
	my $str = $map[$ix];
	$str =~ tr/ \t\n/ /s;
	$str =~ s/^ //;
	$str =~ s/ $//;
	my @fld = split(/ /, $str, 5);
	if (@fld != 5) {
	    Warn("source-map needs 5 fields <$str>");
	    return -1;
	}
	$symb[$ix] = $fld[0];
	$align[$ix] = $fld[1];
	$dx[$ix] = $fld[2];
	$dy[$ix] = $fld[3];
	$expr[$ix] = $fld[4];
	#print "$fld[0] $fld[1] $fld[2] $fld[3] $fld[4]\n";
    }
    my $ypos = $ysta + $pin_dist;
    for my $p (@spins) {
	my $lbl = $$p[2][0];

	my $ix;
	for ($ix = 0; $ix < @map; $ix++) {
	    #print "$lbl $ix\n";
	    if (perl_expression($p, $expr[$ix])) {
		last;
	    }
	}
	if ($ix >= @map) {
	    Warn("no match for <$lbl>, check your source-map settings");
	    next;
	}

	$xmin = snap($xmin);
	$ypos = snap($ypos);
	moveto($xmin, $ypos);
	$ypos += 2*$pin_dist;
	component($symb[$ix]);
	print $fh_out "{\n";
	$text_align = $align[$ix];
	# make the refdes be placed at $dx/$dy relative component lower left
	rmoveto($dx[$ix], $dy[$ix] + text_capheight($sznum) + text_height($sznum));
	$text_vis = 0; $text_show = 0;
	text($sznum, "net=$lbl:1");
	$text_vis = 1; $text_show = 1;
	text($sznum, "refdes=$lbl");
	print $fh_out "}\n";
    }

    close($fh_out);

    0;
}

#sub end_source() {
#    undef $attr{source};
#}

sub showact($) {
    my $ref = shift;

    my $filename_fmt = $$ref[0];
    my $pkg      = $$ref[1];
    my $set      = $$ref[2];
    my $style    = $$ref[3];
    my $arg      = $$ref[4];
    my $lattr    = $$ref[5];

    $fh_out = *STDOUT;
    print "/// showact\n";
    print "filename_fmt: $filename_fmt\n";
    print "pkg:   $pkg\n";
    print "set:   $set\n";
    showpins(\@header, $pin_set{$set});
    print "style: $style\n";
    print "arg:   $arg\n";
    print "lattr:\n";
    for my $k (sort keys %$lattr) {
	my $v = $$lattr{$k};
	print "  $k: $v\n";
    }
    print "\n";
    undef($fh_out);
}

sub per_file( $ ) {
    my $file = shift;
    my @sieve;
    my @act;

    $cur_inp = $file;
    clr_globals();
    data_read(\@sieve, \@act, $conffile);
    data_read(\@sieve, \@act, $file);
    #print "sieve: \n"; for (@sieve) { print "$_\n"; }

    if ($file =~ m/\//) {
	$cur_dir  = `dirname  $file`;
	$cur_file = `basename $file`;
	chomp( $cur_dir, $cur_file );
	if ($cur_dir eq ".") { $cur_dir  = ""; }
	else                 { $cur_dir .= "/"; }
    } else {
	$cur_dir  = "";
	$cur_file = $file;
    }
    $cur_file =~ m/([^\/]*)\.[^.]*$/;
    $cur_nam  = $1;

    $pin_set{pins} = \@pins;
    if (@pins == 0) {
	Warn("no pins found when reading file <$file>");
	return;
    }

    for (@sieve) { act_sieve($_); }

    #$fh_out = *STDOUT;
    #showpins(\@header, \@pins);
    #print join("\n", @sieve), "\n";
    #for (sort keys(%pin_set)) {
	#print "\n$_:\n";
	#showpins(\@header, $pin_set{$_});
    #}
    #undef($fh_out);

    for my $ref (@act) {
	my $filename_fmt = $$ref[0];
	my $pkg      = $$ref[1];
	my $set      = $$ref[2];
	my $style    = $$ref[3];
	my $arg      = $$ref[4];
	my $lattr    = $$ref[5];
	#showact($ref); next;
	$cur_set = $set;

	# check filename_fmt
	if (!defined($filename_fmt) || $filename_fmt eq "" || $filename_fmt =~ m/\//) {
	    Warn("found empty or illegal filename_fmt ($filename_fmt)");
	    next;
	}

	# check pkg
	my @pkgl;
	if ($pkg =~ m/^\d+$/) {
	    @pkgl = sort split(//, $pkg);
	    #print "pkg: $pkg\n";
	    #print "header: ", join(" ", @header), "\n";
	    #print "pkgl: ", join(" ", @pkgl), "\n";
	} elsif ($pkg eq "*") {
	    @pkgl = (0..$#header);
	} else {
	    Warn("unknown package list ($pkg)");
	    next;
	}

	# check set
	my $rset = $pin_set{$set};
	if (!defined($rset)) {
	    Warn("unknow pin set ($set)");
	    next;
	}
	#showpins(\@header, $rset);
	$rset = rm_unused($rset, \@pkgl);
	#showpins(\@header, $rset);

	# check style
	if (!defined($style) || $style eq "" || !defined($style{$style})) {
	    Warn("unknown box style: {$_}");
	    next;
	}
	my $func = $style{$style};
	if (!defined($func)) {
	    Warn("unknown style: $filename_fmt <$style>");
	    next;
	}

	# check arg postponed till after attribute handling

	# check lattr, update %attr
	my %save_attr = (%gattr);
	for my $k (keys %$lattr) {
	    # TODO: replace instead of append
	    #$save_attr{$k} = $$lattr{$k};
	    push @{$save_attr{$k}}, @{$$lattr{$k}};
	}

	# check arg
	my $arguments;
	if (attr_last("common_labels")) {
	    $arguments = parse_args($rset, $arg);
	}

	# start process
	for my $ix (@pkgl) {
	    $cur_pkg = $ix;
	    if ($cur_pkg >= @header) {
		Warn("out of bounds package column number ($cur_pkg)");
		last;
	    }
	    %attr = ();
	    for my $k (keys %save_attr) {
		$attr{$k} = [ @{$save_attr{$k}} ];
	    }
	    %attr_skip = ();
	    my $cset = [ @$rset ];
	    if (!attr_last("common_labels")) {
		# check arg with package specific pin set
		$cset = rm_unused($cset, [ $cur_pkg ]);
		$arguments = parse_args($cset, $arg);
	    }

	    # update attributes for current package
	    $cur_lbl = $header[$cur_pkg];
	    #print "$filename_fmt $cur_pkg $cur_lbl\n";
	    for my $key (sort keys %attr) {
		#print "  $key";
		#if ($key =~ m/^(.+)\.($cur_pkg|$cur_lbl)$/) {
		#if ($key =~ m/^(.+)\.($cur_lbl)$/) {
		if ($key =~ m/^(.+)\.($cur_pkg)$/) {
		    my $stem =  $1;
		    my $ref  =  $attr{$key};
		    #print " found: $stem";
		    push @{$attr{$stem}}, @$ref;
		    $attr_skip{$key} = 1;
		} elsif ($key =~ m/^(.+)\..*$/) {
		    $attr_skip{$key} = 1;
		}
		#print "\n";
	    }
	    for my $key (sort keys %attr) {
		#if ($attr_skip{$key}) { next; }
		if ($attr_proc{$key}) {
		    my $r = $attr{$key};
		    for (my $ix = 0; $ix < @$r; $ix++) {
			$$r[$ix] = proc_format($$r[$ix]);
		    }
		}
	    }

	    $pin_seq = 0; # every file should start from scratch re. pinseq
	    $fh_out = undef();
	    if (pin_cnt($arguments) == 0) {
		#print "no pins, skipping $output ($set $style $arg)\n";
	    } else {
		if ($filename_fmt eq "-") {
		    $fh_out = *STDOUT;
		    &$func($arguments);
		    undef($fh_out);
		} else {
		    my $output = proc_format( $filename_fmt );

		    if (open($fh_out, ">$output")) {
			print "printing to $output ($set $style $arg)\n";
			&$func($arguments);
			close($fh_out);
		    } else {
			Warn("cannot print to $output $style($arg)\n");
		    }
		}
		# check special
		if (check_source($arguments, attr_last("netsfile"))) { next; };
		if (check_source($arguments, attr_last("source"))) { next; };
		#end_source();
	    }
	}
    }
}

sub main( ) { for my $file (@ARGV) { per_file($file); } }

main();

__END__
