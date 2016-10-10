#!/usr/bin/perl

for($num = 2; $num <= 64/2; $num++){
  open(file, ">CONN${num}X2-2.sym") or die "Couldn't open file CONN${num}X2-2.sym, $!";

  $height = $num*400;

  $data = <<"EOF";
v 20140308 2
T 300 @{[$height+500]} 8 10 1 1 0 0 1
refdes=J?
T 0 @{[$height+800]} 5 10 0 0 0 0 1
symversion=1.0
T 0 @{[$height+1000]} 5 10 0 0 0 0 1
device=CONNECTOR
T 0 @{[$height+1200]} 5 10 0 0 0 0 1
footprint=HEADER@{[$num*2]}_2
T 0 @{[$height+1400]} 5 10 0 0 0 0 1
author=Wojciech Krutnik
T 0 @{[$height+1600]} 5 10 0 0 0 0 1
documentation=none
T 0 @{[$height+1800]} 5 10 0 0 0 0 1
description=Double row connector
T 0 @{[$height+2000]} 5 10 0 0 0 0 1
numslots=0
T 0 @{[$height+2200]} 5 10 0 0 0 0 1
dist-license=GPL
T 0 @{[$height+2400]} 5 10 0 0 0 0 1
use-license=unlimited
T 300 300 8 10 1 1 0 2 1
value=CONN${num}X2
T 300 100 8 10 1 1 0 2 1
comment=comment
EOF

  for($pin = 0; $pin < $num; $pin++){
    $piny = ($height+200)-400*($pin);
    $pindata = <<"EOF";
P 0 $piny 300 $piny 1 0 0
{
T 100 @{[$piny+100]} 5 10 0 0 0 0 1
pintype=pas
T 400 $piny 9 12 1 1 0 1 1
pinlabel=@{[$pin+1]}
T 105 @{[$piny+95]} 5 10 0 1 0 6 1
pinnumber=@{[$pin+1]}
T 100 @{[$piny+100]} 5 10 0 0 0 0 1
pinseq=@{[$pin+1]}
}
P 1400 $piny 1100 $piny 1 0 0
{
T 1300 @{[$piny+100]} 5 10 0 0 0 6 1
pintype=pas
T 1000 $piny 9 12 1 1 0 7 1
pinlabel=@{[($num*2)-$pin]}
T 1295 @{[$piny+95]} 5 10 0 1 0 0 1
pinnumber=@{[($num*2)-$pin]}
T 1300 @{[$piny+100]} 5 10 0 0 0 6 1
pinseq=@{[($num*2)-$pin]}
}
EOF
    $data = $data . $pindata;
  }

  $data = $data . "B 300 400 800 $height 3 30 1 0 -1 -1 0 -1 -1 -1 -1 -1\n";

  print file "$data";

  close(file) or die "Couldn't close file properly";
}
