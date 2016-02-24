#!/usr/bin/perl

for($num = 2; $num <= 12; $num++){
  open(file, ">NXW_$num.fp") or die "Couldn't open file NXW_$num.fp, $!";

  $data = <<"EOF";
Element["" "" "" "" 2.05mm 2.9mm 0.0000 0.0000 0 100 ""]
(
EOF

  for($pin = 1; $pin <= $num; $pin++){
    $pin_x = ($pin-1)*2;
    $pindata = <<"EOF";
  Pin[${pin_x}mm 0.0000 60mil 0.7620mm 68mil 0.8000mm "" "$pin" "edge2"]
EOF
    $data = $data . $pindata;
  }

  $box = <<"EOF";
  ElementLine [-2.05mm -2.9mm -2.05mm 1.8mm 0.2500mm]
  ElementLine [-2.05mm 1.8mm @{[($num-1)*2+2.05]}mm 1.8mm 0.2500mm]
  ElementLine [@{[($num-1)*2+2.05]}mm 1.8mm @{[($num-1)*2+2.05]}mm -2.9mm 0.2500mm]
  ElementLine [@{[($num-1)*2+2.05]}mm -2.9mm -2.05mm -2.9mm 0.2500mm]
  ElementLine [-2.05mm 1.4mm 1mm 1.4mm 0.2500mm]
  ElementLine [1mm 1.4mm 1mm 1.8mm 0.2500mm]
  ElementLine [@{[($num-1)*2+2.05]}mm 1.4mm @{[($num-1)*2-1]}mm 1.4mm 0.2500mm]
  ElementLine [@{[($num-1)*2-1]}mm 1.4mm @{[($num-1)*2-1]}mm 1.8mm 0.2500mm]
)
EOF
  $data = $data . $box;

  print file "$data";

  close(file) or die "Couldn't close file properly";
}
