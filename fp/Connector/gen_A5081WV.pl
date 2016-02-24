#!/usr/bin/perl

for($num = 2; $num <= 12; $num++){
  open(file, ">A5081WV_$num.fp") or die "Couldn't open file A5081WV_$num.fp, $!";

  $data = <<"EOF";
Element["" "" "" "" 2.54mm 5.6mm 0.0000 0.0000 0 100 ""]
(
EOF

  for($pin = 1; $pin <= $num; $pin++){
    $pin_x = ($pin-1)*5.08;
    $pindata = <<"EOF";
  Pin[${pin_x}mm 0.0000 140mil 0.7620mm 148mil 1.8000mm "" "$pin" "edge2"]
EOF
    $data = $data . $pindata;
  }

  $box = <<"EOF";
  ElementLine [-2.54mm -5.6mm -2.54mm 4.6mm 0.2500mm]
  ElementLine [-2.54mm 4.6mm @{[($num-1)*5.08+2.54]}mm 4.6mm 0.2500mm]
  ElementLine [@{[($num-1)*5.08+2.54]}mm 4.6mm @{[($num-1)*5.08+2.54]}mm -5.6mm 0.2500mm]
  ElementLine [@{[($num-1)*5.08+2.54]}mm -5.6mm -2.54mm -5.6mm 0.2500mm]
  ElementLine [-1mm -5.6mm -1mm -5mm 0.2500mm]
  ElementLine [-1mm -5mm 1mm -5mm 0.2500mm]
  ElementLine [1mm -5mm 1mm -5.6mm 0.2500mm]
  ElementLine [-2.54mm 2mm @{[($num-1)*5.08+2.54]}mm 2mm 0.2500mm]
)
EOF
  $data = $data . $box;

  print file "$data";

  close(file) or die "Couldn't close file properly";
}
