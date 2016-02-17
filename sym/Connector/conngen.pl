#!/usr/bin/perl

for($num = 2; $num <= 40; $num++){
  open(file, ">CONN$num-1.sym") or die "Couldn't open file CONN$num-1.sym, $!";

  $height = $num*400;

  $data = <<"EOF";
v 20140308 2
T 400 @{[$height+500]} 8 10 1 1 0 6 1
refdes=J?
T 0 @{[$height+800]} 5 10 0 0 0 0 1
symversion=1.0
T 0 @{[$height+1000]} 5 10 0 0 0 0 1
device=CONNECTOR
T 0 @{[$height+1200]} 5 10 0 0 0 0 1
footprint=JUMPER$num
T 0 @{[$height+1400]} 5 10 0 0 0 0 1
author=Wojciech Krutnik
T 0 @{[$height+1600]} 5 10 0 0 0 0 1
documentation=none
T 0 @{[$height+1800]} 5 10 0 0 0 0 1
description=Single row connector
T 0 @{[$height+2000]} 5 10 0 0 0 0 1
numslots=0
T 0 @{[$height+2200]} 5 10 0 0 0 0 1
dist-license=GPL
T 0 @{[$height+2400]} 5 10 0 0 0 0 1
use-license=unlimited
T 400 300 8 10 1 1 0 8 1
value=CONN$num
T 400 100 8 10 1 1 0 8 1
comment=comment
EOF

  for($pin = 1; $pin <= $num; $pin++){
    $piny = ($height+200)-400*($pin-1);
    $pindata = <<"EOF";
P 800 $piny 500 $piny 1 0 0
{
T 700 @{[$piny+100]} 5 10 0 0 0 6 1
pintype=pas
T 400 $piny 9 12 1 1 0 7 1
pinlabel=$pin
T 695 @{[$piny+95]} 5 10 0 1 0 0 1
pinnumber=$pin
T 700 @{[$piny+100]} 5 10 0 0 0 6 1
pinseq=$pin
}
EOF
    $data = $data . $pindata;
  }

  $data = $data . "B 0 400 500 $height 3 30 1 0 -1 -1 0 -1 -1 -1 -1 -1\n";

  print file "$data";

  close(file) or die "Couldn't close file properly";
}
