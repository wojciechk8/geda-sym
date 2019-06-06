#!/usr/bin/perl

for($num = 2; $num <= 10; $num++){
  open(file, ">MOLEX_5268_$num.fp") or die "Couldn't open file MOLEX_5268_$num.fp, $!";

  $data = <<"EOF";
Element["" "" "" "" 2.4500mm 1.3000mm 0.0000 0.0000 0 100 ""]
(
EOF

  for($pin = 1; $pin <= $num; $pin++){
    $pin_x = ($pin-1)*2.5;
    if($pin == 1){
      $pindata = <<"EOF";
  Pin[${pin_x}mm 0.0000 2.0320mm 0.7620mm 2.2320mm 0.9000mm "" "$pin" "edge2,square"]
EOF
    }else{
      $pindata = <<"EOF";
  Pin[${pin_x}mm 0.0000 2.0320mm 0.7620mm 2.2320mm 0.9000mm "" "$pin" "edge2"]
EOF
    }
    $data = $data . $pindata;
  }

  $box = <<"EOF";
  ElementLine [-2.4500mm -1.3000mm -2.4500mm 6.6000mm 0.2500mm]
  ElementLine [-2.4500mm 6.6000mm @{[($num-1)*2.5+2.45]}mm 6.6000mm 0.2500mm]
  ElementLine [@{[($num-1)*2.5+2.45]}mm 6.6000mm @{[($num-1)*2.5+2.45]}mm -1.3000mm 0.2500mm]
  ElementLine [@{[($num-1)*2.5+2.45]}mm -1.3000mm -2.4500mm -1.3000mm 0.2500mm]

  ElementLine [@{[($num-1)*2.5+1.18]}mm -1.3000mm @{[($num-1)*2.5+1.18]}mm 6.6000mm 0.2500mm]
  ElementLine [-1.18mm -1.3000mm -1.18mm 6.6000mm 0.2500mm]
  ElementLine [-1.6mm -1.3000mm -1.6mm 6.6000mm 0.2500mm]
  ElementLine [-2.03mm -1.3000mm -2.03mm 6.6000mm 0.2500mm]
)
EOF
  $data = $data . $box;

  print file "$data";

  close(file) or die "Couldn't close file properly";
}
