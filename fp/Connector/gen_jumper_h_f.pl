#!/usr/bin/perl

for($num = 1; $num <= 40; $num++){
  open(file, ">JUMPER${num}H_F.fp") or die "Couldn't open file JUMPER${num}H.fp, $!";

  $data = <<"EOF";
Element["" "" "" "" 0mm 0mm 0.0000 0.0000 0 100 ""]
(
EOF

  for($pin = 1; $pin <= $num; $pin++){
    $pin_y = ($pin-1)*2.54;
    if($pin == 1){
      $pindata = <<"EOF";
  Pin[0mm ${pin_y}mm 70mil 0.7620mm 78mil 0.9000mm "" "$pin" "edge2,square"]
EOF
    }else{
      $pindata = <<"EOF";
  Pin[0mm ${pin_y}mm 70mil 0.7620mm 78mil 0.9000mm "" "$pin" "edge2"]
EOF
    }
    $data = $data . $pindata;
  }

  $box = <<"EOF";
  ElementLine [1.5mm -1.27mm 1.5mm @{[($num-1)*2.54+1.27]}mm 0.2500mm]
  ElementLine [1.5mm @{[($num-1)*2.54+1.27]}mm 10mm @{[($num-1)*2.54+1.27]}mm 0.2500mm]
  ElementLine [10mm @{[($num-1)*2.54+1.27]}mm 10mm -1.27mm 0.2500mm]
  ElementLine [10mm -1.27mm 1.5mm -1.27mm 0.2500mm]
)
EOF
  $data = $data . $box;

  print file "$data";

  close(file) or die "Couldn't close file properly";
}
