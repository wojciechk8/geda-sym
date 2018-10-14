#!/usr/bin/perl -w

use strict;
use utf8;
use open ':encoding(utf8)';
#use open ':encoding(latin-1)';
use Data::Dumper;

binmode(STDOUT, ":encoding(UTF-8)");

########################################
# general variables

my %option = ();

my @pagedim = ();

my @fontsz = ();
my @fonthight = ();
my @fontHIGHT = ();
my @fontfam = ();
my @fontcol = ();
my @fontCnt = ();
my @fontcnt = ();
my @fontwidth = ();
my @fontline = ();

my %fontwidth = ();

# array of the textual data in the file, and names of the indexes
my @txt; # ( [ 0 page, 1 top, 2 left, 3 width, 4 height, 5 font, 6 text ], ... )
my $ipage   = 0;
my $ibottom = 1;
my $itop    = 2;
my $ileft   = 3;
my $iright  = 4;
my $ifont   = 5;
my $idir    = 6;
my $ibold   = 7;
my $itext   = 8;
# coordinate system seems to be
#   -y
# -x   +x
#   +y

my @page;  # ( index, ... ) where index is index (into @txt) to first element on that page

########################################
# handle file and its raw data

sub strip_header() {
    while (<FH>) {
	#print;
	if (m/^<pdf2xml>$/) {
	    last;
	}
    }
}

sub parse_file($) {
    my $file = shift;

    #print "$file\n";

    if (!open(FH, "pdftohtml -stdout -xml $file |")) {
	warn("cannot open $file");
	return -1;
    }

    strip_header();
    my $page = -1;
    while (<FH>) {
	my $line = $_;
	chomp;
	# remove some junk appearing at line beginnings
	s/failed to look up G\d\.\d+//g;
	s/link to page \d+//g;
	s/^[ \t]+//;
	s/[ \t]+$//;
	#print "$_\n";

	if (m/^<text top="(\d+)" left="(\d+)" width="(-?\d+)" height="(\d+)" font="(\d+)">(.*)<\/text>$/) {
	    # text with width < 0 seem to be " ", perhaps kerning
	    # text with same font sometimes seems to have differig heigths
	    # width == 0 seems to 90° rotated text
	    # rotated text seems to have the same bottom ($top+$height) as horizontal text for the some
	    #  bottom position on paper
	    my ($top, $left, $width, $height, $font, $txt) = ($1, $2, $3, $4, $5, $6);
	    if ($width < 0 && $txt =~ m/^ +$/) { next; }

	    my $bold = 0;
	    if ($txt =~ m/^<b>(.*)<\/b>$/) {
		$txt = $1;
		$bold = 1;
	    }

	    # seems a few fonts are used before definitions
	    if (!defined($fonthight[$font])) { $fonthight[$font] = 22222222222; }
	    if (!defined($fontHIGHT[$font])) { $fontHIGHT[$font] = 0; }
	    if (!defined($fontCnt[$font]  )) { $fontCnt[$font]   = 0; }
	    if (!defined($fontcnt[$font]  )) { $fontcnt[$font]   = 0; }

	    if ($fonthight[$font] > $height ) { $fonthight[$font] = $height; }
	    if ($fontHIGHT[$font] < $height ) { $fontHIGHT[$font] = $height; }

	    my $cnt = length($txt);
	    $fontCnt[$font]   += 1;
	    $fontcnt[$font]   += $cnt;
	    $fontwidth[$font] += $width;
	    #printf "%4d %3d %3d: %s\n", $., $cnt, $fontcnt[$font], $_;

	    if ($width == 0) {
		# we have to correct $top later
		push @txt, [ $page, $top+$height, $top, $left-$height, $left, $font, "V", $bold, $txt ];
	    } else {
		push @txt, [ $page, $top+$height, $top, $left, $left+$width, $font, "R", $bold, $txt ];
	    }

	} elsif (m/^<fontspec id="(\d+)" size="(\d+)" family="(.+)" color="#([0-9a-f]+)"\/>/) {
	    #print "$.: $_\n";
	    $fontsz[$1]    = $2;
	    $fonthight[$1] = 999;
	    $fontHIGHT[$1] = 0;
	    $fontfam[$1]   = $3;
	    $fontcol[$1]   = $4;
	    $fontCnt[$1]   = 0;
	    $fontcnt[$1]   = 0;
	    $fontwidth[$1] = 0;
	    $fontline[$1]  = $_;

	} elsif (m/^<page number="(\d+)" position="absolute" top="(\d+)" left="(\d+)" height="(\d+)" width="(\d+)">$/) {
	    $page = $1;
	    if (defined($pagedim[$page])) {
		warn("duplicate page definition");
	    }
	    $pagedim[$page] = [ $page, $2, $3, $4, $5 ];
	    if ($page <= 0) { warn("nonpositive page number") }

	} elsif (m/^<\/page>$/) {
	    $page = -1;

	} elsif (m/^$/) {
	    next;

	} elsif (m/^<\/pdf2xml>$/) {
	    last;

	} else {
	    print STDERR "Err: $line";
	}
    }
    close(FH);

    my %fw;
    my %fc;
    for (my $ix = 0; $ix < @fontwidth; $ix++) {
	my $k = $fontsz[$ix] . $fontfam[$ix];
	if (!defined($fw{$k})) {
	    $fw{$k} = $fontwidth[$ix];
	    $fc{$k} = $fontcnt[$ix];
	} else {
	    $fw{$k} += $fontwidth[$ix];
	    $fc{$k} += $fontcnt[$ix];
	}
    }
    for my $k (keys %fc) {
	if ($fc{$k}) {
	    $fontwidth{$k} = $fw{$k} / $fc{$k};
	} else {
	    $fontwidth{$k} = 0;
	}
    }
}

sub txt_connected($) {
    # find sequence of ajecent (in text direction) text fragments
    my $sta = shift;

    if ($sta >= $#txt) { return $sta; }

    my $prv = $sta;
    my $end = $sta + 1;

    while ($end < @txt) {
	my ($page, $bot, $top, $left, $right, $font, $dir, $bold, $txt) = @{$txt[$prv]};
	my ($Page, $Bot, $Top, $Left, $Right, $Font, $Dir, $Bold, $Txt) = @{$txt[$end]};
	if ($page != $Page) { last; }
	my $width = $right - $left;
	my $Width = $Right - $Left;
	my $hig = $bot - $top;
	my $Hig = $Bot - $Top;

	my $whorz = ($dir ne "V") && ($dir ne "V");
	my $wvert = ($dir eq "V") && ($dir eq "V");
	my $wx    = ($dir eq "V") ^  ($dir eq "V");

	my $charwidth = 2;
	my $vmargin = 4;
	my $houtside = $right + $charwidth < $Left  ||  $Right + $charwidth < $left;
	my $voutside = $bot - $vmargin < $Top  || $Bot - $vmargin  < $top;

	if ($wvert) {
	    # we don't know if thext is going up or down
	    # we have to guess the string width
	    my $len = length($txt);
	    my $k = 1.2;
	    if ($bold) { $k *= 2; } # TODO: check
	    my $fw = get_fontwidth($font);
	    my $guess = $fw * $len * $k;

	    if ($Bot <= $bot) {
		# i.e. txt is below Txt, so we guess the direction is UP
		$top = $bot - $guess;
		$txt[$prv][$itop] = $top;
	    } else {
		# i.e. Txt is below txt, so we guess the direction is DOWN
		$top = $bot;
		$bot = $bot + $guess;
		$txt[$prv][$itop] = $top;
		$txt[$prv][$ibottom] = $bot;
	    }
	    $charwidth = 4;
	    $houtside = $right < $Left  ||  $Right < $left;
	    $voutside = $Top - $charwidth > $bot || $top - $charwidth > $Bot;
	}

	#pr_ixtxt($prv, $prv);
	if ($wx || $houtside || $voutside ) {
	    last;
	}

	$prv++;
	$end++;
    }

    $end - 1;
}

sub txt_join_vert($$) {
    my $sta = shift;
    my $end = shift;

    my @list = ($sta .. $end);
    #@list = sort { $txt[$a][$ibot] <=> $txt[$b][$ibot] } @list;

    my $ix = shift @list;

    my @arr = @{$txt[$ix]};
    my @res = @arr;


    $res[$ipage] = $arr[$ipage];
    $res[$ibottom] = $arr[$ibottom];
    $res[$itext] = $arr[$itext];

    my $font = $arr[$ifont];
    my $sz = $fontsz[$font];
    my $B = $arr[$ibottom];
    my $T = $arr[$itop];
    my $L = $arr[$ileft];
    my $R = $arr[$iright];


    for $ix (@list) {
	my @arr = @{$txt[$ix]};
	my $tfont = $arr[$ifont];
	my $tsz = $fontsz[$font];
	my $tB = $arr[$ibottom];
	my $tT = $arr[$itop];
	my $tL = $arr[$ileft];
	my $tR = $arr[$iright];
	my $ttext = $arr[$itext];

	if ($sz < $tsz) {
	    $font = $tfont;
	    $sz = $tsz;
	}

	if ($T > $tT) { $T = $tT; }
	if ($B < $tB) { $B = $tB; }
	if ($R < $tR) { $R = $tR; }
	if ($L < $tL) { $L = $tL; }
	$res[$itext] .= $ttext;
    }
    $res[$ibottom] = $B;
    $res[$ileft]   = $L;
    $res[$itop]    = $T;
    $res[$iright]  = $R;
    $res[$ifont] = $font;

    [ @res ];
}

sub txt_join_horz($$) {
    my $sta = shift;
    my $end = shift;

    my @list = ($sta .. $end);
    # here I'm assuming left->right text (which might not be true)
    @list = sort { $txt[$a][$ileft] <=> $txt[$b][$ileft] } @list;

    my $ix = shift @list;

    my @arr = @{$txt[$ix]};
    my @res = @arr;

    $res[$ipage] = $arr[$ipage];
    $res[$ileft] = $arr[$ileft];
    $res[$itext] = $arr[$itext];

    my $font = $arr[$ifont];
    my $sz = $fontsz[$font];
    my $B = $arr[$ibottom];
    my $T = $arr[$itop];
    my $L = $arr[$ileft];
    my $R = $arr[$iright];

    for $ix (@list) {
	my @arr = @{$txt[$ix]};
	my $tfont = $arr[$ifont];
	my $tsz = $fontsz[$font];
	my $tB = $arr[$ibottom];
	my $tT = $arr[$itop];
	my $tL = $arr[$ileft];
	my $tR = $arr[$iright];
	my $ttext = $arr[$itext];

	if ($sz < $tsz) {
	    $font = $tfont;
	    $sz = $tsz;
	}

	if ($T > $tT) { $T = $tT; }
	if ($B < $tB) { $B = $tB; }
	if ($R < $tR) { $R = $tR; }
	# already sorted by $ileft
	$res[$itext] .= $ttext;
    }
    $res[$ibottom] = $B;
    $res[$itop]    = $T;
    $res[$iright]  = $R;
    $res[$ifont] = $font;

    [ @res ];
}
sub txt_join($$) {
    my $sta = shift;
    my $end = shift;

    my $res;

    if ($sta == $end) {
	$res = $txt[$sta];
    } else {
	if ($txt[$sta][$idir] eq 'V') {
	    $res = txt_join_vert($sta, $end);
	} else {
	    $res = txt_join_horz($sta, $end);
	}
    }

    $res;
}

sub txt_merge() {
    my @new = ();

    my $sta = 0;
    while ($sta < @txt) {
	my $end = txt_connected($sta);
	#print "$sta -> $end\n";
	my $res = txt_join($sta, $end);
	if ($res) { push @new, $res; }
	$sta = $end+1;
    }

    @txt = @new;
}

sub txt_clean($) {
    my $flg = shift;
    my @new = ();

    for my $rr (@txt) {
	my $str = $$rr[$itext];
	$str =~ tr/ \t\r\n/ /s;
	$str =~ s/^ //;
	$str =~ s/ $//;
	if ($flg) {
	    $str =~ s|<a href=\"[^"]*">([^<>]+)</a>|$1|g;
	}
	$str =~ s/\(\d+\)//g;
	$$rr[$itext] = $str;
	if ($$rr[$itext] ne "") { push @new, $rr; }
    }
    @txt = @new;
}

########################################
# print stuff

my $prs_txt_hdr = " pg   bot  top  left rigt  f DB <text>\n";
my $pri_txt_hdr = "  ix: " . $prs_txt_hdr;

sub prs_txt_element($) {
    my $r = shift;
    my @e = @$r;
    #join(" ", @{$r}), "\n";
    my $str = sprintf "%3d %5d %4d %5d %4d %2d %1s%1s <%s>\n", @e;
    $str;
}

sub mk_teststr($) { # same as above minus the $e[0]
    my $ix = shift;

    my @e = @{$txt[$ix]};
    shift @e;
    sprintf "%4d %4d %4d %4d %2d %s", @e;
}

sub pr_txt_element {
    #print $prs_txt_hdr;
    for my $r (@_) {
	print prs_txt_element($r);
    }
}

sub pr_ixtxt($$) {
    my $ix = shift;
    my $tx = shift;

    printf "%4d: %s", $ix, prs_txt_element($txt[$tx]);
}

sub pri_txt_element {
    #print "  ix: ", $prs_txt_hdr;
    for my $ix (@_) {
	pr_ixtxt($ix, $ix);
    }
}

sub pr_index_list($@) {
    my $name = shift;
    print "$name = [ ", join(", ", @_), " ]\n";
}

sub pr_ll($@) {
    my $str = shift;
    for (my $ix = 0; $ix < @_; $ix++) {
	pr_index_list("$str:$ix", @{$_[$ix]});
    }
}

sub pr_ixlist(@) {
    my $ix;
    print $pri_txt_hdr;
    for ($ix = 0; $ix < @_; $ix++) {
	my $r = $_[$ix];
	for my $tx (@$r) {
	    pr_ixtxt($ix, $tx);
	}
	print "\n";
    }
}

##
sub pr_invariant(@) {
    my @inv = @_;
    my @hdr = ("Left", "Center", "Right");

    for (my $ix = 0; $ix < @hdr; $ix++) {
	if (defined($inv[$ix])) {
	    print "\n", $hdr[$ix], " invariant:\n";
	    for (my $kx = 0; $kx < @{$inv[$ix]}; $kx++) {
		print "  $kx\n";
		my @list = @{${$inv[$ix]}[$kx]};
		#pr_ixtxt($list[0], $list[0]);
		pri_txt_element(@list);
	    }
	}
    }
}

sub pr_txt() {
    print $pri_txt_hdr;
    pri_txt_element(0..$#txt);
}

sub get_fontwidth($) {
    my $font = shift;
    my $k = $fontsz[$font] . $fontfam[$font];

    $fontwidth{$k};
}
sub pr_font {
    if (@_ == 0) {
	@_ = (0..$#fontsz);
    }
    printf " id:  sz hgt HGT  Cnt   cnt width  color     family <orig>\n";
    for my $ix (@_) {
	my ($h, $H, $c, $C, $w) = ($fonthight[$ix], $fontHIGHT[$ix], $fontCnt[$ix], $fontcnt[$ix], $fontwidth[$ix]);
	if ($fontcnt[$ix] <= 0) {
	    ($h, $H) = ("-")x2;
	}
	if ($fontwidth[$ix] == 0) {
	    $w = "-";
	} else {
	    $w = sprintf "%5.1f", $w / $fontcnt[$ix];
	}
	printf "%3d:  %2d %3s %3s %4s %5s %5s %s %10s %s\n",
	    $ix, $fontsz[$ix], $h, $H, $c, $C, $w, $fontcol[$ix], $fontfam[$ix], $fontline[$ix];
    }
}

sub pr_page() {
    my $ix;
    pr_index_list('@page', @page);
    print $pri_txt_hdr;
    pri_txt_element(@page);
    print "\n";
}

########################################
# utilities

sub ix_unique {
    my %tmp = map { $_, 1 } @_;
    my @unique = sort { $a <=> $b } keys %tmp;
    @unique;
}
sub ix_remove($$) {
    my $list = shift;
    my $rm = shift;

    my %tmp = map { $_, 1 } @$list;

    for my $e (@$rm) {
	if (defined($tmp{$e})) {
	    delete $tmp{$e};
	}
    }
    sort { $a <=> $b } keys %tmp;
}

sub vec_len($) {
    my $r = shift;
    my $x = $$r[0];
    my $y = $$r[1];

    sqrt($x*$x + $y*$y);
}

sub txt_lldistance($$) {
    # how much must I displace a to get to b
    my $a = shift;
    my $b = shift;

    my $ally = $txt[$a][$ibottom];
    my $blly = $txt[$b][$ibottom];

    my $allx = $txt[$a][$ileft];
    my $bllx = $txt[$b][$ileft];

    ( $bllx - $allx, $blly - $ally );
}

sub txt_distance($$) {
    my $a = shift;
    my $b = shift;

    my $ay = $txt[$a][$itop];
    my $by = $txt[$b][$itop];

    my $aY = $txt[$a][$ibottom];
    my $bY = $txt[$b][$ibottom];

    my $ax = $txt[$a][$ileft];
    my $bx = $txt[$b][$ileft];

    my $aX = $txt[$a][$iright];
    my $bX = $txt[$b][$iright];

    my $ox = $ax <= $bx && $bx <= $aX || $ax <= $bX && $bX <= $aX; # overlap x
    my $oy = $ay <= $by && $by <= $aY || $ay <= $bY && $bY <= $aY; # overlap y

    my $dx = 0;
    my $dy = 0;

    # one could concider that the overlapping cases have more "glue" than the corner cases
    # and thus be more closely binded together
    if      ($ox && $oy) { # they cover each other, at least partially
    } elsif ($ox) { # they are above each other
	if ($aY < $by) { $dy = $by - $aY; }
	else           { $dy = $bY - $ay; } # negative to indicate that b is to the left of a
    } elsif ($oy) { # they are side by side
	if ($aX < $bx) { $dx = $bx - $aX; }
	else           { $dx = $bX - $ax; } # neg. b is over a
    } else { # corners
	if ($aX < $bx) { # b is to the right of a
	    my $dx = $bx - $aX;
	    if ($aY < $by) { $dy = $by - $aY; }
	    else           { $dy = $bY - $ay; }
	} else { # b is to the left of a
	    my $dx = $bX - $ax;
	    if ($aY < $by) { $dy = $by - $aY; }
	    else           { $dy = $bY - $ay; }
	}
    }

    ( $dx, $dy );
}

sub txt_cmp {
    my $cmp;
    $cmp = $$a[$ipage] <=> $$b[$ipage];
    if ($cmp) { return $cmp; }

    $cmp = $$a[$itop] <=> $$b[$itop];
    if ($cmp) { return $cmp; }

    $cmp = $$a[$ibottom] <=> $$b[$ibottom];
    if ($cmp) { return $cmp; }

    $cmp = $$a[$ileft] <=> $$b[$ileft];
    if ($cmp) { return $cmp; }

    $cmp = $$a[$iright] <=> $$b[$iright];
    if ($cmp) { return $cmp; }

    $$a[$itext] cmp $$b[$itext];
}
sub cell_hcmp {
    my $cmp;
    $cmp = $txt[$a][$ipage] <=> $txt[$b][$ipage];
    if ($cmp) { return $cmp; }

    $cmp = $txt[$a][$ileft] <=> $txt[$b][$ileft];
    if ($cmp) { return $cmp; }

    $cmp = $txt[$a][$iright] <=> $txt[$b][$iright];
    if ($cmp) { return $cmp; }

    $cmp = $txt[$a][$itop] <=> $txt[$b][$itop];
    if ($cmp) { return $cmp; }

    $cmp = $txt[$a][$ibottom] <=> $txt[$b][$ibottom];
    if ($cmp) { return $cmp; }

    $txt[$a][$itext] cmp $txt[$b][$itext];
}
sub cell_vcmp {
    my $cmp;
    $cmp = $txt[$a][$ipage] <=> $txt[$b][$ipage];
    if ($cmp) { return $cmp; }

    $cmp = $txt[$a][$itop] <=> $txt[$b][$itop];
    if ($cmp) { return $cmp; }

    $cmp = $txt[$a][$ibottom] <=> $txt[$b][$ibottom];
    if ($cmp) { return $cmp; }

    $cmp = $txt[$a][$ileft] <=> $txt[$b][$ileft];
    if ($cmp) { return $cmp; }

    $cmp = $txt[$a][$iright] <=> $txt[$b][$iright];
    if ($cmp) { return $cmp; }

    $txt[$a][$itext] cmp $txt[$b][$itext];
}

sub num_cmp {
    $a <=> $b;
}

sub font_sz($) {
    my $a = shift;
    my $fid = $txt[$a][$ifont];

    $fontsz[$fid];
}

########################################
# work on arr of indexes into @txt

sub txt_hdistance($$) {
    my $a = shift;
    my $b = shift;

    my $left  = $txt[$a][$ileft];
    my $right = $txt[$a][$iright];

    my $Left  = $txt[$b][$ileft];
    my $Right = $txt[$b][$iright];

    my $d = 0;

    if ($Right < $left) {
	$d = - ( $left - $Right );
    } elsif ($right < $Left) {
	$d = + ( $Left - $right );
    } else {
	$d = 0;
    }

    $d;
}

sub txt_sort() {
    @txt = sort txt_cmp @txt;
}

sub get_pages() {
    my $lpage= -1;
    @page = ();

    for (my $ix = 0; $ix < @txt; $ix++) {
	my $spage= $txt[$ix][$ipage];
	if ($lpage != $spage) {
	    # new page
	    $lpage = $spage;
	    push @page, $ix;
	}
    }

}

sub pr_lines($) {
    my $rtot = shift;

    for my $page (sort { $a <=> $b } keys %$rtot) {
	for (my $lix = 0; $lix < @{$$rtot{$page}}; $lix++) {
	    my $line = $$rtot{$page}[$lix];
	    print " ** Page $page Line $lix:\n";
	    pri_txt_element(@$line);
	}
    }
}
sub collect_lines(@) {
    my @list = @_;
    my $page = -1;
    my $top  = -1;
    my $bot  = -1;
    my $rtot = {};

    for my $ix (@list) {
	my $Page = $txt[$ix][$ipage];
	my $Bot  = $txt[$ix][$ibottom];
	my $Top  = $txt[$ix][$itop];

	if ($page != $Page) { # found a new page
	    $top  = $Top;
	    $bot  = $Bot;
	    $page = $Page;
	    $$rtot{$page} = [ ];
	    push @{$$rtot{$page}}, [];
	}

	my $is_same_line = ($top <= $Top && $Top <= $bot)  ||  ($top <= $Bot && $Bot <= $bot);
	my $rll = $$rtot{$page};

	if ($is_same_line) {
	    if ($top > $Top) { $top = $Top; }
	    if ($bot < $Bot) { $bot = $Bot; }
	} else {
	    # found a new line, same page
	    $top  = $Top;
	    $bot  = $Bot;
	    $page = $Page;
	    push @{$$rtot{$page}}, [];
	}

	my $last_line_ix = @$rll - 1;
	push @{$$rll[$last_line_ix]}, $ix;
    }


    for $page (keys %$rtot) {
	for my $line (@{$$rtot{$page}}) {
	    $line = [ sort { $txt[$a][$ileft] <=> $txt[$b][$ileft]; } @$line ];
	}
    }

    $rtot;
}

sub find_invariant_positions($$;$) {
    my $index_sta  = shift;
    my $index_step = shift;
    my $index_end  = shift;

    if (!defined($index_end)) {
	$index_end = @page;
    } else {
	$index_end++;
    }
    # TODO: handle different even/odd page margins
    my @inv_l = ();
    my @inv_c = ();
    my @inv_r = ();
    my $maxerr = 2;

    if (@page < 2) { return (\@inv_l, \@inv_c, \@inv_r); }

    for (my $ix = $page[$index_sta]; $ix < $page[$index_sta+1]; $ix++) {
	# go through all text on first page ...
	my $pos_y = $txt[$ix][$ibottom];
	my $pos_l = $txt[$ix][$ileft];
	my $pos_r = $txt[$ix][$iright];
	my $pos_c = ($pos_l + $pos_r) / 2;

	my @list_l = ($ix);
	my @list_c = ($ix);
	my @list_r = ($ix);

	for (my $px = $index_sta + $index_step; $px < $index_end; $px += $index_step) {
	    # ... and see if any of thoose positions is there on all other pages
	    my $fx = $page[$px];
	    my $ex = ($px+1 < @page) ? $page[$px+1] : @txt+0;

	    # $tx (below) > 0, since $txt[0] is on the first page
	    my $found_l = 0;
	    my $found_c = 0;
	    my $found_r = 0;

	    for (my $tx = $fx; $tx < $ex; $tx++) {
		my $Pos_y = $txt[$tx][$ibottom];
		my $Pos_l = $txt[$tx][$ileft];
		my $Pos_r = $txt[$tx][$iright];
		my $Pos_c = ($Pos_l + $Pos_r) / 2;

		if ($Pos_y < $pos_y - $maxerr) {
		    next;
		} elsif (abs($Pos_y - $pos_y) <= $maxerr) {
		    if  (abs($Pos_l - $pos_l) <= $maxerr) { $found_l = $tx; }
		    if  (abs($Pos_c - $pos_c) <= $maxerr) { $found_c = $tx; }
		    if  (abs($Pos_r - $pos_r) <= $maxerr) { $found_r = $tx; }
		} else {
		    last;
		}
	    } # for ($tx
	    if (@list_l && $found_l) {
		push @list_l, $found_l;
	    } else {
		@list_l = ();
	    }
	    if (@list_c && $found_c) {
		push @list_c, $found_c;
	    } else {
		@list_c = ();
	    }
	    if (@list_r && $found_r) {
		push @list_r, $found_r;
	    } else {
		@list_r = ();
	    }
	} # for (my $px
	if (@list_l) { push @inv_l, [ @list_l ]; }
	if (@list_c) { push @inv_c, [ @list_c ]; }
	if (@list_r) { push @inv_r, [ @list_r ]; }
    }

    (\@inv_l, \@inv_c, \@inv_r);
}

sub find_wfont($) {
    my $font = shift; # index into @font...
    my @list = ();

    for (my $ix = 0; $ix < @txt; $ix++) {
	if ($font == $txt[$ix][$ifont]) {
	    push @list, $ix;
	}
    }
    @list = sort num_cmp @list;
}

########################################
# todo

sub find_txt_groups() {
    my $ix;
    my @avail = (0..$#txt);
    my @group;

    while (@avail) {
	my @test = ( shift @avail ); # init test with first element in avail
	my @surplus;
	my @yes;

	while (@test) { # check everything in test against avail
	    my $a = shift @test;
	    my @not;

	    while (@avail) {
		# pick out text in avail that are close enought to a
		# and put it in out test set

		my $b = shift @avail;
		my $d = txt_distance($a, $b);

		# "attraction" radius: the greatest font sz * constant
		my $fa = font_sz($a);
		my $fb = font_sz($b);
		my $fd = $fa > $fb ? $fa : $fb;
		$fd *= 1.5;

		if ($$d[1] > $fd) {
		    # too much diff in y-direction, no further things to find in avail
		    last;
		}

		if ($$d[0] > $fd) {
		    # not this one
		    if ($txt[$b][$itop] < $txt[$a][$itop]) {
			# this one will not attract to anything in test
			push @surplus, $b;
		    } else {
			# this one might be close enought to a later element in test
			push @not, $b;
		    }
		    next;
		}

		# b has been found to belong to the current set
		push @test, $b;
	    }

	    # we are now finished with a, save it avay
	    push @yes, $a;

	    # sort the not set make it availabe for testing again
	    @not = sort txt_icmp @not;
	    @avail = ( @not, @avail );
	}

	# we now have a complete group in yes, save it, and start over with the rest
	push @group, [ @yes ];
	@avail = ( @surplus, @avail );
    }
}

########################################
# appl. specific things

sub find_hdrs() {
    my $font = -1;
    my $min = 222222222222222222222222222; # some big enought point size

    for (my $ix = 0; $ix < @fontsz; $ix++) {
	my $sz = $fontsz[$ix];
	#pr_font($ix);
	if (defined($sz) && $sz < $min) {
	    $font = $ix;
	    $min = $sz;
	}
    }
    if ($font < 0) {
	die("no fonts found");
    }
    #pr_font($font);

    my @hdr = find_wfont($font);
    my ($i, $v) = find_pageinvariant(@hdr);
    @hdr = @$v;
    for my $r (@$i) { # pick the first invariant, i.e. drop them on the other pages
	push @hdr, $$r[0];
    }
    @hdr = sort num_cmp @hdr;
}

sub pr_group(@) {
    my $label = shift;

    printf "%-20s ", $txt[$label][$itext] . ":";

    my @data;
    for my $ix (@_) {
	my $str = $txt[$ix][$itext];
	$str =~ s/^[ \t]*//;
	$str =~ s/[ \t]*$//;
	push @data, $str;
    }
    print join(" / ", @data);
    print "\n";
}

sub find_txt_below($@) {
    # find the text below the label (on the same page)
    my $label = shift;
    my @stop  = @_;
    my $pg = $txt[$label][$ipage];
    my $page = -1;
    my @res = ( $label );

    #pri_txt_element($label);
    for (my $ix = 0; $ix < @page; $ix++) {
	my $tst = $txt[$page[$ix]][$ipage];
	if ($pg == $tst) {
	    $page = $ix;
	    last;
	}
    }
    if ($page < 0) {
	print "could not find page index for $label\n";
	pri_txt_element($label);
	exit(1);
    }
    #print "page index $page\n";
    #pri_txt_element($label);

    my $end = $page[$page+1];
    if (!defined($end)) {
	$end = @txt;
    }
    my $a = $label;
 CHK: for (my $ix = $label + 1; $ix < $end; $ix++) { # stay on same page
	my ($dx, $dy) = txt_lldistance($a, $ix);
	if (abs($dx) > 20) { next; }
	if ($dy > 100) { last; }

	my $fa = font_sz($a);
	my $fb = font_sz($ix);
	my $fd = 3 * ($fa + $fb) / 2;

	if ($dy > $fd) { last; }

	for (my $sx = 0; $sx < @stop; $sx++) {
	    if ($ix != $label && $ix == $stop[$sx]) { last CHK; }
	}
	push @res, $ix;
	#pri_txt_element($ix);

	$a = $ix;
    }
    #print "\n";

    @res;
}

sub process_ica(@) {
    my @line = @_;
    my $pos = 0;

    for my $lx (@line) {
	my $tst = shift @$lx;
	next if ($txt[$tst][$ifont] != 4);
	my $str = $txt[$tst][$itext];
	if ($str eq "Totalt:") {
	    last;
	}
	my $last;
	if ($str =~ m/^[ \t]*(\d+) (\d{6})$/) {
	    $pos++;
	    if ($1 != $pos) {
		print "missing pos?\n";
	    }
	    printf "%3d: %s", $pos, $2;
	    $last = pop @$lx;
	} else {
	    printf "%3d: %s", $pos, $str;
	}

	for my $ix (@$lx) {
	    $str = $txt[$ix][$itext];
	    $str =~ s/^[ \t]*//;
	    $str =~ s/[ \t]*$//;
	    print " / ", $str;
	}
	if (defined($last)) {
	    $str = $txt[$last][$itext];
	    $str =~ s/^[ \t]*//;
	    $str =~ s/[ \t]*$//;
	    my @d = split(/[ \t]+/, $str);
	    print " / ", join(" / ", @d);
	}
	print "\n";
    }
}

sub pr_columns($@) {
    my $page = shift;
    my @col = @_;

    printf " page %3s, \@col sz %3d: ", $page, @col+0;
    for (my $ix = 0; $ix < @col; $ix++) {
	print " [ $col[$ix][0], $col[$ix][1] ]";
    }
    print "\n";
}
sub pr_mult_columns($@) {
    my $page = shift;

    for (@_) {
	pr_columns($page, @$_);
    }
}
sub find_columns($) {
    my $line = shift;
    my @lines = @$line;

    my @col = ();
    my @Col;
    if (@lines == 0) { return @col; };

    for (my $lx = 0; $lx < @lines; $lx++) {
	my $r = $lines[$lx];
	my @list = @$r;
	for my $ix (@list) {
	    my $Left  = $txt[$ix][$ileft];
	    my $Right = $txt[$ix][$iright];
	    #pri_txt_element($ix);

	    @Col = @col;
	    @col = ();
	    while (@Col) {
		my $r = shift @Col;
		my ($left, $right) = @$r;

		if ($Left < $left) {
		    if ($Right < $left) {
			push @col, [$Left, $Right], $r, @Col;
			$Left = $Right = 0;
			last;
		    } elsif ($Right <= $right) {
			push @col, [$Left, $right], @Col;
			$Left = $Right = 0;
			last;
		    } else {
			next;
		    }
		} elsif ($Left <= $right ) {
		    $Left = $left;
		    if ($Right <= $right) {
			push @col, $r, @Col;
			$Left = $Right = 0;
			last;
		    } else {
			next;
		    }
		} else {
		    push @col, $r;
		    next;
		}
	    }
	    if ($Left && $Right) {
		push @col, [$Left, $Right];
	    }
	}
    }

    @col;
}
sub find_mult_columns(@) {
    my @res;
    for (@_) {
	push @res, [ find_columns(@$_) ];
    }

    @res;
}

sub pr_table($) {
    my $table = shift;

    for (my $lix = 0; $lix < @$table; $lix++) {
	my $col = $$table[$lix];
	print "   LINE $lix\n";
	for (my $cix = 0; $cix < @$col; $cix++) {
	    print " Col $cix\n";

	    my $cell = $$table[$lix][$cix];
	    if ($cell) {
		pri_txt_element(@$cell);
	    }
	}
    }
}
sub mktable($$) {
    my $line = shift;
    my $col  = shift;

    my @col = @$col;
    my @table = ();

    my $table = ();
    for (my $lix = 0; $lix < @$line; $lix++) {
	my @data = @{$$line[$lix]};
	$table[$lix] = [];
	my $dix = 0;
	for (my $cix = 0; $cix < @col; $cix++) {
	    my $cell = [];
	    $table[$lix][$cix] = $cell;

	    my $right = $$col[$cix][1];
	    while ($dix < @data && $txt[$data[$dix]][$iright] <= $right) {
		push @$cell, $data[$dix];
		$dix++;
	    }
	}
    }

    [ @table ];
}
sub tbl_merge_lines($) {
    my $table = shift;
    my $ntable = [];

    for (my $lix = 0; $lix < @$table; $lix++) {
	my $line = $$table[$lix];
	my @lst = ();

	for (my $cix = 0; $cix < @$line; $cix++) {
	    my $cell = $$line[$cix];
	    if (@$cell > 0) {
		push @lst, $cix;
	    }
	}

	if (@lst == 1) {
	    my $cix = $lst[0];
	    my $cell_content = $$table[$lix][$cix];
	    my $nlst = $#$ntable;
	    #if ($lix == 0) is the table header
	    if ($lix == 1 && $#$table > 1) { # merge with cell below
		unshift @{$$table[$lix+1][$cix]}, @$cell_content;
	    } elsif ($lix == $#$table) { # merge with cell above
		push @{$$ntable[$nlst][$cix]}, @$cell_content;
	    } else {
		# up or down ?
		my $above = $$table[$lix-1][$cix];
		my $Above = $$above[$#$above];
		my $Bot   = $txt[$Above][$ibottom];
		my $Btxt  = $txt[$Above][$itext];

		my $below = $$table[$lix+1][$cix];
		my $Below = $$below[0];
		my $Top   = $txt[$Below][$ibottom];
		my $Ttxt  = $txt[$Below][$itext];

		my $top = $txt[$$cell_content[0]][$itop];
		my $bot = $txt[$$cell_content[$#$cell_content]][$itop];

		my $dabove = $top - $Bot;
		my $dbelow = $Top - $bot;

		if      ($Btxt eq "-" && $Ttxt ne "-") { # put it below
		    unshift @{$$table[$lix+1][$cix]}, @$cell_content;
		} elsif ($Btxt ne "-" && $Ttxt eq "-") {
		    push @{$$ntable[$nlst][$cix]}, @$cell_content;
		} elsif ($txt[$$cell_content[$#$cell_content]][$itext] =~ m|/$|) {
		    unshift @{$$table[$lix+1][$cix]}, @$cell_content;
		} elsif ($Btxt =~ m|/$|) {
		    push @{$$ntable[$nlst][$cix]}, @$cell_content;
		} elsif ($dabove < $dbelow) {
		    push @{$$ntable[$nlst][$cix]}, @$cell_content;
		} else {
		    unshift @{$$table[$lix+1][$cix]}, @$cell_content;
		}
	    }
	} else {
	    push @$ntable, $line;
	}
    }

    $ntable;
}
sub cell_hgroup($) {
    my $cell = shift;
    my @cell = @$cell;

    if (@cell == 0) {
	return [];
    }

    my @hcell = sort cell_hcmp @cell;
    my @tst = ();
    my @t = ();

    for my $ix (@hcell) {
	if (@t == 0) {
	    push @t, $ix;
	    next;
	}

	my $tlst = $t[$#t];
	if (txt_hdistance($tlst, $ix) == 0) {
	    push @t, $ix;
	    next;
	}

	push @tst, [ @t ];
	@t = ( $ix );
    }

    push @tst, [ @t ];

    @tst;
}
sub tbl_autosplit_col($) {
    my $table = shift;
    my @line = ();

    if (@$table == 0) { return @line; }

    #### Check/merge header line for (hopefully) actual columns in header line
    my $hdr_line = $$table[0];
    my @hdr_cnt;

    my $str = "";
    my @str = ();
    for (my $cix = 0; $cix < @$hdr_line; $cix++) {
	my $cell = $$hdr_line[$cix];
	my @tst = cell_hgroup($cell);
	push @hdr_cnt, @tst+0;

	for my $r (@tst) {
	    my @arr = @$r;
	    if (@arr == 0) {
		warn("tbl_autosplit_col: shouldn't happen");
	    } elsif (@arr == 1) {
		push @str, $txt[$arr[0]][$itext];
	    } else {
		my @s = ();
		for my $ix (sort cell_vcmp @arr) {
		    push @s, $txt[$ix][$itext];
		}
		push @str, join(" ", @s);
	    }

	}
    }
    $str = join(" | ", @str) . "\n";
    #print "hdr_cnt: ", join(" ", @hdr_cnt), "\n";
    push @line, $str;
    #pr_table([$$table[0]]);

    #print "Header\n";
    #print $str;
    for (my $lix = 1; $lix < @$table; $lix++ ) {
	my $line = $$table[$lix];
	@str = ();
	for (my $cix = 0; $cix < @$line; $cix++) {
	    my $cell = $$table[$lix][$cix];
	    my @tst = cell_hgroup($cell);
	    my $expected_columns = $hdr_cnt[$cix];

	    my @tstr = ();
	    for my $r (@tst) {
		my @arr = @$r;
		if (@arr == 0) {
		    #print("tbl_autosplit_col: $lix $cix\n");
		    #pr_table([$line]);
		    push @tstr, ("-");
		} elsif (@arr == 1) {
		    push @tstr, $txt[$arr[0]][$itext];
		} else {
		    my @s = ();
		    for my $ix (sort cell_vcmp @arr) {
			push @s, $txt[$ix][$itext];
		    }
		    my $tstr = join(" ", sort @s);
		    $tstr =~ s/^ //;
		    $tstr =~ s/ $//;
		    $tstr =~ s| */ *| |;
		    push @tstr, $tstr;
		}

	    }


	    if ($expected_columns < 1) {
		# empty
	    } elsif (@tstr == $expected_columns) {
		push @str, @tstr;
	    } elsif (@tstr == 1 && $expected_columns > 1) {
		# ok, split this column
		my @fld = split(/ +/, $tstr[0], $expected_columns);
		if (@fld < $expected_columns) {
		    my $cnt = $expected_columns - @fld;
		    push @str, ("-")x$cnt; # let user handle this
		}
		push @str, @fld;
	    } else {
		# mismatch
		my $nn = @tstr;
		my $zz = join(" ", @tstr);
		my @fld = split(/ +/, $zz);
		if (@fld == $expected_columns) {
		    push @str, @fld;
		} else {
		    print "mismatch $lix $cix: $nn $expected_columns\n";
		    push @str, @tstr;
		}
	    }

	}
	$str = join(" | ", @str) . "\n";
	push @line, $str;
    }

    @line;
}

sub tbl2str($) {
    my $table = shift;
    my @line = ();

    for (my $lix = 0; $lix < @$table; $lix++) {
	my $line = $$table[$lix];
	my $Str = "";

	for (my $cix = 0; $cix < @$line; $cix++) {
	    my @cell = @{$$line[$cix]};

	    my $str = "";
	    for (my $xx = 0; $xx < @cell; $xx++) {
		my $ix = $cell[$xx];
		$str .= " " . $txt[$ix][$itext];
	    }
	    $Str .= " | " . $str;
	}
	$Str =~ tr/ / /s;
	$Str =~ s/^ //;
	$Str =~ s/ $//;
	$Str =~ s/^\| ?//;
	$Str .= "\n";
	push @line, $Str;
    }

    @line;
}

sub stm32_fix_line($$@) {
    my $do_fst_line = shift;
    my $page = shift;
    my @line = @_;

    my @hdr = ();
    if ($do_fst_line) {
	my @cell = split(/ ?\| ?/, shift @line);
	push @hdr, "$cell[2] $cell[1] $cell[0]\n";
	push @hdr, "# Page: $page\n";
    } else {
	shift @line;
	push @hdr, "# Page: $page\n";
    }

    for (my $lix = 0; $lix < @line; $lix++) {
	chomp $line[$lix];
	my @cell = split(/ ?\| ?/, $line[$lix]);
	if (@cell != 9) {
	    print "elements don't match\n";
	    #print $line[$lix], "\n";
	    #print "<", join("/", @cell), ">\n";
	}
	if ($cell[4] =~ m|^I/O$|) {
	    $cell[4] = "pas";
	} elsif ($cell[4] =~ m|^I$|) {
	    $cell[4] = "in";
	} elsif ($cell[4] =~ m|^O$|) {
	    $cell[4] = "out";
	} elsif ($cell[4] =~ m|^S$|) {
	    $cell[4] = "pwr";
	} elsif ($cell[4] =~ m|^HiZ$|) {
	    $cell[4] = "pas";
	} else {
	    $cell[4] = "pas";
	}

	if ($cell[7] =~ m|^-$|) {
	    $cell[7] = "";
	} else {
	    my @fld = split(/[ \/]+/, $cell[7]);
	    @fld = sort @fld;
	    $cell[7] = join(" ", @fld);
	}

	if ($cell[8] =~ m|^-$|) {
	    $cell[8] = "";
	} else {
	    my @fld = split(/[ \/]+/, $cell[8]);
	    @fld = sort @fld;
	    for (my $ix = 0; $ix < @fld; $ix++) {
		$fld[$ix] = "r" . $fld[$ix];
	    }
	    $cell[8] = join(" ", @fld);
	}

	my $str = sprintf("%-4s %2s %3s  %-3s  %-5s %s   %s",
			  $cell[2], $cell[1], $cell[0], $cell[4], $cell[6], $cell[7], $cell[8]);
	$str =~ s/ +$//;
	$line[$lix] = $str . "\n";
    }

    unshift @line, @hdr;

    @line;
}

sub stm32_filter($) {
    my $rtot = shift;
    my $ntot = {};

    for my $page (sort { $a <=> $b } keys %$rtot) {
	my $npage = [];
	$$ntot{$page} = $npage;

	for (my $lix = 0; $lix < @{$$rtot{$page}}; $lix++) {
	    my $line = $$rtot{$page}[$lix];
	    my $nn = @$line;
	    my @nline = ();

	    if ($lix == 0 && $nn == 1 && $txt[$$line[0]][$itext] =~ m/[tT]able \d+.*/) {
		next;
	    }
	    if ($lix == 1 && $nn == 2 && $txt[$$line[0]][$itext] =~ m/^Pins/ && $txt[$$line[1]][$itext] =~ m/^Alterna/) {
		next;
	    }

	    for (my $tix = 0; $tix < @$line; $tix++) {
		my $ix = $$line[$tix];

		if ($txt[$ix][$itext] eq "Not connected") { # don't let this disturb columnization
		    $txt[$ix][$itext] = "N.C.";
		    $txt[$ix][$iright] = $txt[$ix][$ileft];
		    push @nline, $ix;
		    last;
		}
		push @nline, $ix;
	    }

	    push @$npage, [ @nline ];
	}
    }

    $ntot;
}

sub run_stm32() {
    my $table = $option{table};
    my $table_sta;
    my $table_end;
    if ($table && $table =~ /^(\d+),(\d+)$/) {
	$table_sta = $1;
	$table_end = $2;
    } else {
	warn("please specify table=<starting page>,<ending page>");
	return;
    }
    # look for invariants a few pages before table so as not to catch table contents
    my @aa = find_invariant_positions($table_sta-4,2,$table_end);
    my @ab = find_invariant_positions($table_sta-3,2,$table_end);
    if ($option{pr_invariant}) { pr_invariant(@aa); }
    if ($option{pr_invariant}) { pr_invariant(@ab); }
    my @a = ();
    for my $r (@aa, @ab) { for my $rr (@$r) { push @a, @$rr; } }
    my @invariant = ix_unique(@a);
    my $page_sta = $page[$table_sta - 1]; # note @page is zero based
    my $page_end = $page[$table_end] - 1;
    my @variant = ix_remove([ $page_sta .. $page_end ], \@invariant);

    if ($option{pr_invariant}) {
	print "\n\nVariant:\n";
	print $pri_txt_hdr;
	pri_txt_element(@variant);
    }
    my $rline = collect_lines(@variant);
    if ($option{pr_lines}) { pr_lines($rline); }

    $rline = stm32_filter($rline);
    if ($option{pr_flines}) { pr_lines($rline); }

    my $do_fst_line = 1;
    for my $page (sort { $a <=> $b } keys %$rline) {
	my $line = $$rline{$page};
	my @col = find_columns($line);
	if ($option{pr_columns}) { pr_columns($page, @col); }
	my $table = mktable($line, \@col);
	if ($option{pr_table}) { pr_table($table); }
	$table = tbl_merge_lines($table);
	if ($option{pr_table2}) { pr_table($table); }
	my @line;
	@line = tbl_autosplit_col($table);
	@line = stm32_fix_line($do_fst_line, $page, @line);
	print @line;
	$do_fst_line = 0;
    }
}

my %run = (
    stm32 => \&run_stm32,
);

########################################

sub Usage($) {
    my $err = shift;
    if ($err) {
	print "Error: $err\n";
	exit 1;
    }
}
sub main() {
    $option{debug} = "";
    for (my $ix = 0; $ix < @ARGV; $ix++) {
	my $arg = $ARGV[$ix];

	if ($arg =~ m/^([^=]+)=(.*)$/) {
	    my $k = $1;
	    my $v = $2;
	    if (!defined($v)) { $v = ""; }
	    $option{$k} = $v;
	    next;
	}

	my $file = $arg;
	parse_file($file);
	txt_merge();
	txt_clean(1);
	txt_sort();
	get_pages();
	if ($option{pr_font}) { pr_font(); }
	if ($option{pr_txt})  { pr_txt(); }
	if ($option{pr_page}) { pr_page(); }

	my $run = $option{run};
	if ($run && $run{$run}) {
	    my $f = $run{$run};
	    &$f();
	}
    }
}

main();

__END__
    # Note: this relies on that the headers have the smallest font
    my @hdr = find_hdrs();
    #pri_txt_element(@hdr);
    for my $label (@hdr) {
	next if ("Sida" eq $txt[$label][$itext]);
	my @grp = find_txt_below($label, @hdr);
	#pri_txt_element(@grp);
	pr_group(@grp);
    }
    print "\n";

    #process_ica();
    #find_txt_groups();
    #pr_ixlist(@group);

sub find_pageinvariant(@) {
    my @list = @_;

    #pri_txt_element(@list);

    if (@list == 0) {
	@list = (0..$#txt);
    }
    my @invariants = ();
    my @variants = ();

    my @pg = find_pages(@list);
    my $r = shift @pg;
    my @fp = @$r;

    my @not = ();
    for (my $ix = 0; $ix < @pg; $ix++) { $not[$ix] = []; }

    while (@fp) {
	# go through all text on first page
	#pr_index_list('x', @fp);
	my $a = shift @fp;
	my $A = mk_teststr($a);
	my @tst = ();
	#print "Testing $a $A\n";

	my $flag = 1;
	for (my $px = 0; $px < @pg; $px++) {
	    #pr_index_list($px, @{$pg[$px]});
	    $r = $pg[$px];
	    if (@$r == 0) {
		$flag = 0;
		next;
	    }
	    while (@$r > 0) {
		#printf "%3d %d\n", $px, @$r + 0;
		my $tx = shift @$r;
		#pr_ixtxt($px, $tx);
		my $T = mk_teststr($tx);
		#printf "%4d: <%s>\n", $tx, $T;
		if      ($T lt $A) {
		    # to high up/the left, will not match any one more in first page
		    push @{$not[$px]}, $tx;
		    next;
		} elsif ($T eq $A) {
		    #print "fine, check next page\n";
		    $tst[$px] = $tx;
		    last;
		} else {
		    #print "to low down/the right, a can't be an invariant\n";
		    unshift @$r, $tx;
		    $flag = 0;
		    last;
		}
	    }
	    #page end
	    if (!$flag) {
		last;
	    }
	}
	#pr_ll('pg', @pg);
	if ($flag) {
	    #print "Got invariant: $A\n";
	    push @invariants, [ $a, @tst ];
	} else {
	    # a not an invariant, restore pg
	    #print "Got   variant: $A\n";
	    push @variants, $a ;
	    for (my $px = 0; $px < @pg; $px++) {
		if (!defined($tst[$px])) { last; }
		unshift @{$pg[$px]}, $tst[$px];
	    }
	}
	#pr_ll("inv", @invariants);
	#pr_index_list("var", @variants);
	#if ($a > 3) { last; }
    }

    for (my $ix = 0; $ix < @pg; $ix++) {
	#my $r = $not[$ix];
	#printf "%d: %d\n", $ix, @$r + 0;
	push @variants, @{$not[$ix]};
	push @variants, @{$pg[$ix]};
    }
    @variants = sort num_cmp @variants;

    ( \@invariants, \@variants );
}

sub pr_info() {
    printf "\@txt: %s\n", @txt+0;
    printf "\@lines: %s\n", @lines+0;
    printf "\@page: %s\n", @page+0;
    printf "\@group: %s\n", @group+0;
}

