#!/usr/bin/perl

for($num = 2; $num <= 40; $num++){
  open(file, ">CONN$num-1.sym") or die "Couldn't open file CONN$num-1.sym, $!";
  
  $height = $num*200;
  
  $data = <<"EOF";
v 20140308 2
T 0 @{[$height+150]} 8 10 1 1 0 0 1
refdes=J?
T 0 @{[$height+300]} 5 10 0 0 0 0 1
symversion=1.0
T 0 @{[$height+400]} 5 10 0 0 0 0 1
device=CONNECTOR
T 0 @{[$height+500]} 5 10 0 0 0 0 1
footprint=JUMPER$num
T 0 @{[$height+600]} 5 10 0 0 0 0 1
author=Wojciech Krutnik
T 0 @{[$height+700]} 5 10 0 0 0 0 1
documentation=none
T 0 @{[$height+800]} 5 10 0 0 0 0 1
description=Single row connector
T 0 @{[$height+900]} 5 10 0 0 0 0 1
numslots=0
T 0 @{[$height+1000]} 5 10 0 0 0 0 1
dist-license=GPL
T 0 @{[$height+1100]} 5 10 0 0 0 0 1
use-license=unlimited
T 0 50 8 10 1 1 0 2 1
value=CONN$num
T 0 -50 8 10 1 1 0 2 1
comment=comment
B 0 100 300 $height 3 15 1 0 -1 -1 0 -1 -1 -1 -1 -1
EOF
  
  for($pin = 1; $pin <= $num; $pin++){
    $piny = $height-200*($pin-1);
    $pindata = <<"EOF";
P 500 $piny 300 $piny 1 0 0
{
T 400 @{[$piny+50]} 5 10 0 0 0 6 1
pintype=pas
T 250 $piny 9 12 1 1 0 7 1
pinlabel=$pin
T 395 @{[$piny+45]} 5 10 0 1 0 0 1
pinnumber=$pin
T 400 @{[$piny+50]} 5 10 0 0 0 6 1
pinseq=$pin
}
EOF
    $data = $data . $pindata;
  }
  
  print file "$data";
  
  close(file) or die "Couldn't close file properly";
}
