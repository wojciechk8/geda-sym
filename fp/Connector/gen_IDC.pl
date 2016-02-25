#!/usr/bin/perl

for($num = 6; $num <= 40; $num+=2){
  open(file, ">IDC_$num.fp") or die "Couldn't open file IDC_$num.fp, $!";
  
  $data = <<"EOF";
Element["" "" "" "" 3.13mm 5.08mm 0.0000 0.0000 0 100 ""]
(
EOF
  
  for($pin = 1; $pin <= $num; $pin+=2){
    $pin_y = ($pin-1)/2*2.54;
    $pindata = <<"EOF";
  Pin[0mm ${pin_y}mm 70mil 0.7620mm 78mil 0.9000mm "" "$pin" "edge2"]
  Pin[2.54mm ${pin_y}mm 70mil 0.7620mm 78mil 0.9000mm "" "@{[($pin+1)]}" "edge2"]
EOF
    $data = $data . $pindata;
  }
  
  $box = <<"EOF";
  ElementLine [-3.13mm -5.08mm -3.13mm @{[($num/2-1)*2.54+5.08]}mm 0.2500mm]
  ElementLine [-3.13mm @{[($num/2-1)*2.54+5.08]}mm 5.67mm @{[($num/2-1)*2.54+5.08]}mm 0.2500mm]
  ElementLine [5.67mm @{[($num/2-1)*2.54+5.08]}mm 5.67mm -5.08mm 0.2500mm]
  ElementLine [5.67mm -5.08mm -3.13mm -5.08mm 0.2500mm]
  ElementLine [-3.13mm @{[(($num/2-1)*2.54/2)-2.2]}mm -1.13mm @{[(($num/2-1)*2.54/2)-2.2]}mm 0.2500mm]
  ElementLine [-1.13mm @{[(($num/2-1)*2.54/2)-2.2]}mm -1.13mm @{[(($num/2-1)*2.54/2)+2.2]}mm 0.2500mm]
  ElementLine [-1.13mm @{[(($num/2-1)*2.54/2)+2.2]}mm -3.13mm @{[(($num/2-1)*2.54/2)+2.2]}mm 0.2500mm]
)
EOF
  $data = $data . $box;
  
  print file "$data";
  
  close(file) or die "Couldn't close file properly";
}
