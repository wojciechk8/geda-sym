#!/usr/bin/ruby -w
# sfg.rb -- simple/small/stefans footprint generator for gEDA/PCB
# Copyright: S. Salewski, mail@ssalewski.de
# License: GPL
#
# I just started learning Ruby, so do not expect too nice code!
# Improvements welcome.
#
Version = '0.13 (25-OCT-2009)'
#
Docu = <<HERE
sfg.rb -- yet another footprint generator for gEDA/PCB
Version: #{Version}
Author: S. Salewski
License: GPL

This is a plain footprint (land pattern) generator for gEDA/PCB
written in Ruby. The intention was to make its use simple, safe
and intuitive. Extension for new types of footprints is easy.

The program processes a textual input file, which contains the
parameters needed for generation of footprints. Each line of this
input file defines a single parameter, i.e. "pindiameter = 0.8 mm".

The input file is divided in sections by "Device = " statements.
You can define global parameters, if you prepend the parameters
with the line "Device = Global". Parameters specific for a special
type of footprint are defined if you prepend the parameter
definition by a command like "Device = DIP". In this case all
following parameter definitions are local. You may redefine global
parameters here, but after next "Device = " command all global
parameters have again their previous state (and no local parameters
exist). This behaviour ensures that insertion of a new section can
never influence existing sections. You can define a default unit,
so mm or mil for dimensions is optional. Equal sign for assignment
is optional too, or you may uses ":=". Numeric parameters can be
simple expressions like "2.1+0.8*2". If parameters are not numeric
and are not simple text strings, you should include it in quotation
marks. The command "Generate" followed by a filename will write the
footprint file to disk. This is a small piece of a configuration
file:

Device Global
  date "10-APR-2008"
  clearance 10 mil
  defaultunit mm

Device DIP
  defaultunit mil # locally overwrite a global parameter
  width = 300
  pins 8
  drilldiameter 0.8*1.1 mm # 10 % tolerance
  refdespos upperleft
  Generate "DIP8-300.fp" # this is a command, so do not use = sign.

If you execute this program with argument -h or --help then this
documentation is written to stdout. If you give a command line
parameter, this is considered as an input file and processing
starts. You can generate an empty input file (template) if you
give "PrintAll" as command line argument, or you may generate an
input template for a specific device by using that name, i.e.
"DIP" as argument. Redirect the output to a file and fill in the
missing information.

Supported device types:
-----------------------
HERE

# device_name_type_default_comment, last two fields are optional
# type is str, dim (float) or cnt (integer)
Datas = [
'Global_author_str',
'Global_email_str',
'Global_license_str',
'Global_dist-license_str_GPL',
'Global_use-license_str_unlimited',
'Global_copyright_str',
'Global_comment_str',
'Global_version_str',
'Global_date_str',
'Global_elementdir_str_"./"',
'Global_defaultunit_str__mm or mil',
'Global_silkwidth_dim_10 mil_thickness of silk lines',
'Global_silkoffset_dim_10 mil_distance between pads/pins and silk lines, ignored if silkbox = custom',
'Global_hole-scale_cnt_100_scaling for drill diameter in percent, should be 100 to 130',
'Global_hole-add-on_dim_0.05 mm_absolute increase of drill diameter, should be 0 to 0.1 mm',
'Global_textpos_str_upperleft_position of reference designator, upperleft, some devices may accept center',
'Global_textorientation_str_horizontal_horizontal, some devices may accept vertical',
'Global_refdessize_cnt_100_size of reference designator, default is 100 (integer)',
'Global_mask_dim_6 mil_distance between the copper of pads/pins and the mask',
'Global_clearance_dim_10 mil_distance between the copper of pads/pins and any polygon',
'Global_p1silkmark_str__mark pin/pad 1 with silk: to get a mark use: mark, p1mark, silkmark, yes, true, 1',
'Global_p1coppermark_str__mark pin/pad 1 with copper: to get a mark use: mark, coppermark, yes, true, 1',
'Each_name_str__name of the footprint -- if left empty then filename is used',
'Each_description_str__detailed description',
'Each_desc_str__short description',
'Each_documentation_str__source of layout, i.e. URI of datasheet',
'DIP_pins_cnt__total number of pins',
'DIP_width_dim__separation of the two columns of pins -- center to center',
'DIP_pitch_dim__distance between adjacent pins',
'DIP_pad-dia_dim__outer diameter of copper annulus',
'DIP_drill-dia_dim__diameter of the hole',
'DIP_silkbox_str__inner or outer for autosize, custom for explicit size, otherwise no box',
'DIP_silkboxwidth_dim_0 mil_silkbox width, used if silkbox = custom, no box if value is too small',
'DIP_silkboxheight_dim_0 mil_silkbox height, used if silkbox = custom, no box if value is too small',
'DIP_ovalpads_str__to get ovals use: oval, ovalpads, yes, true, 1',
'DIP_p1silkmark_str__mark pin/pad 1: see global, or for specific shape: semicircle, notch, damage, slash',
'DIP_p1coppermark_str__mark pin/pad 1: see global section, or for specific shape: square, octagon',
'SIP_pins_cnt__total number of pins',
'SIP_pitch_dim__distance between adjacent pins',
'SIP_pad-dia_dim__outer diameter of copper annulus',
'SIP_drill-dia_dim__diameter of the hole',
'SIP_silkbox_str__outer for autosize, custom for explicit size, otherwise no box',
'SIP_silkboxwidth_dim_0 mil_silkbox width, used if silkbox = custom, no box if value is too small',
'SIP_silkboxheight_dim_0 mil_silkbox height, used if silkbox = custom, no box if value is too small',
'SIP_ovalpads_str__to get ovals use: oval, ovalpads, yes, true, 1',
'SIP_p1silkmark_str__mark pin/pad 1: see global, or for specific shape: damage or slash',
'SIP_p1coppermark_str__mark pin/pad 1: see global section, or for specific shape: square, octagon',
'QFP_pins_cnt__total number of pins',
'QFP_rows_cnt_0_number of pins at side of pin one -- 0 is identical to pins/4',
'QFP_width_dim__separation of the two columns of pads -- center to center. If 0 height is used.',
'QFP_height_dim__separation of the two rows of pads -- center to center. If 0 width is used.',
'QFP_pitch_dim__distance between adjacent pads -- center to center',
'QFP_padthickness_dim__should be smaller than pitch',
'QFP_padlength_dim',
'QFP_centerpadwidth_dim_0_width of additional center pad with number pins+1 -- use 0 to supress',
'QFP_centerpadheight_dim_0_height of additional center pad with number pins+1 -- use 0 to supress',
'QFP_silkbox_str__inner or outer for autosize, custom for explicit size, otherwise no box',
'QFP_silkboxwidth_dim_0 mil_silkbox width, used if silkbox = custom, no box if value is too small',
'QFP_silkboxheight_dim_0 mil_silkbox height, used if silkbox = custom, no box if value is too small',
'QFP_ovalpads_str__to get ovals use: oval, ovalpads, yes, true, 1',
'QFP_p1silkmark_str__mark pin/pad 1: see global section, or for specific shape: circle, damage, slash',
'CAPPR_width_dim__separation of the two pins -- center to center',
'CAPPR_pad-dia_dim__outer diameter of copper annulus',
'CAPPR_drill-dia_dim__diameter of the hole',
'CAPPR_silkcircle-dia_dim__diameter of device body -- silk outline',
'CAPPR_p1coppermark_str__mark pin/pad 1: see global section, or for specific shape: square, octagon',
'CAPPR_silkmark_str__mark a pin: use p1plus, p1minus, p2plus, p2minus, p1circle, p2circle to get a mark',
'TRIMR_x1_dim__x position of first pad',
'TRIMR_y1_dim__y position of first pad',
'TRIMR_x2_dim__x position of second pad',
'TRIMR_y2_dim__y position of second pad',
'TRIMR_x3_dim__x position of third pad -- use [x3, y3] == [x1, y1] to suppress third pad',
'TRIMR_y3_dim__y position of third pad',
'TRIMR_pad-dia_dim__outer diameter of copper annulus',
'TRIMR_drill-dia_dim__diameter of the hole',
'TRIMR_cx_dim__center of silk circle',
'TRIMR_cy_dim__center of silk circle',
'TRIMR_chole_dim_0_diameter of hole in the center of silk circle, for adjusting from bottom side',
'TRIMR_silkcircle-dia_dim__diameter of device body -- silk outline',
'TRIMR_p1coppermark_str__mark pin/pad 1: see global section, or for specific shape: square, octagon',
'PinHole_drill-dia_dim__diameter of the hole',
'PinHole_pad-dia_dim__outer diameter of copper annulus, if smaller than drill-dia then hole is unplated',
'PinHole_silk-dia_dim__diameter of silk circle, use 0 for auto size or a value smaller than drill-dia for no silk',
'MountingHole_drill-dia_dim__diameter of the hole',
'MountingHole_pad-dia_dim__outer diameter of copper annulus, if smaller than drill-dia then hole is unplated',
'MountingHole_silk-dia_dim__diameter of silk circle, use 0 for auto size or a value smaller than drill-dia for no silk',
]

DevInfo = Hash[
'DIP' => 'Dual In-Line Packages and similar devices, see http://en.wikipedia.org/wiki/Dual_in-line_package',
'SIP' => 'Single In-Line Packages and similar devices, see http://en.wikipedia.org/wiki/Single_in-line_package',
'QFP' => 'Quad Flat Packages and similar SMD devices like SO, see http://en.wikipedia.org/wiki/QFP',
'CAPPR' => 'Capacitor Polarized Round (in top view), two pins through hole',
'TRIMR' => 'Trimmer, 2 or 3 pins through hole, optional center hole',
'PinHole' => 'Hole or single through hole pin',
'MountingHole' => 'Hole or single through hole pin with pads',
]

PCB_DefaultTextSize = 40 # 40 mil for TScale==100
RefdesToSilkOffset = 30 # should be scaled by TScale
MinSilkWidth = 300 # 3 mil, smaller lines are ignored

$TypeHash = Hash.new
$DevHash = Hash.new
$GlobalHash = Hash.new
$LocalHash = Hash.new
$LineNumber = 0
$Device = "Global"

Name = '([a-zA-Z][-\w]*)'
Ass = '(=|:=|\s)'
Exp = '([-+]?\d+(.\d+)?([-+*/]\d+(.\d+)?)*)'
Str = '([a-zA-Z][-\w\.]*|".*"|\'.*\')'
OptUnit = '(mm|mil)?'
OptSpace = '\s*'
Filename = '[a-zA-Z][-\w\.]*'
CommentLine = '(^\s*#)|(^\s*$)'
LineEnd = '\s*($|#)'
ExpAssignment = '^\s*' + Name + OptSpace + Ass + OptSpace + Exp + OptSpace + OptUnit + LineEnd
StrAssignment = '^\s*' + Name + OptSpace + Ass + OptSpace + Str + LineEnd

NameIndex = 1
ExpIndex = 3
StrIndex = 3
UnitIndex = 7

def ListDevice(dev)
  if DevInfo.has_key?(dev)
    print '# ', DevInfo[dev], "\n"
  end
  puts "Device = #{dev}"
  Datas.each do |line|
    device, name, type, default, comment = line.split('_')
    if (device == dev) or ((device == 'Each') and (dev != 'Global'))
      print "  #{name} = "
      if default and (default != '')
        print default
      elsif type == 'str'
        print '""'
      end
      if comment 
        print ' # ', comment
      end
      puts
    end
  end
  unless dev == 'Global'
    puts '  # Generate ?.fp'
  end
end

# fine but not in in sequence as specified
#def ListDefaults
#  $DevHash.each_value {|device| ListDevice(device)}
#end

def ListDefaults
  a = Array.new
  Datas.each do |line|
    device = line.split(/_/)[0]
    a.push(device) unless device == 'Each'
  end
  a.uniq!.each {|device| ListDevice(device)}
end

def DataToHash
  Datas.each do |line|
    device, name, type = line.split('_')
    if $TypeHash[device + name]
      puts "Error in Datas of program: Device #{device}, multiple definition of #{name}!"
    end
    $TypeHash[device + name] = type
    $DevHash[device] = device
  end
  $DevHash.delete('Each')
end

def InputError(name, value, text)
  print text, "!\n"
  print "  line #{$LineNumber}: #{name} = #{value} (#{$Device})\n"
  Process.exit
end

def ToPcbUnit(val, unit)
  case unit
    when 'mm'
      val * 100000/25.4
    when 'mil'
      val * 100
  else
    puts "Line #{$LineNumber}, section #{$Device}: Undefined unit '#{unit}'!"
    Process.exit
  end
end

def Store(name, value, unit)
  if $Device == 'Global'
    t = $TypeHash['Global' + name]
    InputError(name, value, 'Definition of unused global value') unless t
  else
    t = $TypeHash[$Device + name]
    t = $TypeHash['Each' + name] unless t
    t = $TypeHash['Global' + name] unless t
    InputError(name, value, "Definition of unused value for device #{$Device}") unless t
  end
  if (t == 'str') and (value.class != String)
    InputError(name, value, 'Value should be a string')
  end
  if t == 'cnt'
    if value.class != Fixnum
      InputError(name, value, 'Value should be an integer')
    elsif unit
      InputError(name, value, "Value should be an integer without a unit '#{unit}'")
    end
  end
  if t == 'dim'
    if (value.class != Fixnum) and (value.class != Float)
      InputError(name, value, 'Value should be a dimension (float or integer)')
    else
      unit = Get('defaultunit') unless unit
      value = ToPcbUnit(value, unit)
    end
  end
  if $Device == 'Global'
    $GlobalHash[$Device + name] = value
  else
    $LocalHash[$Device + name] = value
  end 
end

def StoreStr(name, value)
  if value.class == String
    Store(name, value, nil)
  else
    InputError(name, value, 'Value should be a string')
  end
end

def StoreVal(name, value, unit)
  if (value.class == Fixnum) or (value.class == Float)
    Store(name, value, unit)
  else
    InputError(name, value, 'Value should be integer or float')
  end
end

def AskStr(name)
  if ($Device == 'Global') #and (name != 'defaultunit')
    puts 'Error: AskStr() called from global section!'
    Process.exit
  end
  v = $LocalHash[$Device + name]
  v = $GlobalHash['Global' + name] unless v
  v = '' unless v
  if v.class != String
    puts "AskStr(): #{name} (#{$Device}) is not of requested type string!"
    #Process.exit
  end
  return v  
end

def Get(name)
  if ($Device == 'Global') and (name != 'defaultunit')
    puts 'Error: Get() called from global section!'
    Process.exit
  end
  v = $LocalHash[$Device + name]
  v = $GlobalHash['Global' + name] unless v
  unless v
    puts "Error in Get(): #{name} not defined for device #{$Device}!"
    Process.exit
  end
  return v
end

def GetStr(name)
  value = Get(name)
  if value.class != String
    puts "Error in GetStr(): #{name} (#{$Device}) is not of requested type string!"
    Process.exit
  end
  return value
end

def GetCnt(name)
  value = Get(name)
  if value.class != Fixnum
    puts "Error in GetCnt(): #{name} (#{$Device}) is not of requested type integer!"
    Process.exit
  end
  return value
end

def GetDim(name)
  value = Get(name)
  if ((value.class != Fixnum) and (value.class != Float))
    puts "Error in GetDim(): #{name} (#{$Device}) is not of requested type integer or float!"
    Process.exit
  end
  return value
end

def GetScaledDrillDia()
  s = GetCnt('hole-scale')
  if s < 100 or s > 130
    puts "GetScaledDrillDia() (#{$Device}): Scale is #{s}, expected was 100 to 130 percent!"
  end
  o = GetDim('hole-add-on')
  if o < 0 or o > 1000 # 10 mil
    puts "GetScaledDrillDia() (#{$Device}): Add-On is #{(o/100.0).round}, expected was 0 to 10 mil!"
  end
  return GetDim('drill-dia') * s * 0.01 + o
end

def ProcessLine(line)
  return if Regexp.new(CommentLine).match(line)
  if match = Regexp.new(ExpAssignment).match(line)
    name = match[NameIndex]
    value = eval(match[ExpIndex])
    unit = match[UnitIndex]
    StoreVal(name, value, unit)
  elsif match = Regexp.new(StrAssignment).match(line)
    name = match[NameIndex]
    str = match[StrIndex]
    str.gsub!(/^(["'])(.*)\1$/,'\2')
    if name == 'Device'
      if $DevHash[str]
        $Device = str
        $LocalHash = Hash.new
      else
        puts "Line #{$LineNumber}: Device #{str} unknown!"
        print '==> ', line, "\n"
        Process.exit
      end
    elsif name == 'Generate'
      if Regexp.new(Filename).match(str)
        $ElementName = str.gsub(/\.fp/,'')
        Generate(str)
      else
        puts "Line #{$LineNumber}: Invalid filename #{str}!"
        print '==> ', line, "\n"
        Process.exit
      end 
    else
      StoreStr(name, str)
    end
  else
    print 'Ignored line: ', line, "\n"
  end
end

def ProcessInputFile(name)
  begin
    $LineNumber = 0
    File.open(name, 'r') do |f|
      while line = f.gets
        $LineNumber += 1 
        ProcessLine(line.chop!)
      end
    end
  rescue => e
    puts e.message
  end
end

def main
  DataToHash()
  if (ARGV[0] == nil) or (ARGV[0] == '-h') or (ARGV[0] == '--help')
    print Docu
    DevInfo.each{|k,v| print k, ': ', v, "\n"}
  elsif %w[PrintAll ShowAll List].include?(ARGV[0])
    ListDefaults()
  else
    if $DevHash[ARGV[0]]
      ListDevice(ARGV[0])
    else
      ProcessInputFile(ARGV[0])
    end
  end
end

# general generator functions follows
# first functions named Pcb... which generate strings for PCB-Elements

def PcbElementHeader(flags, desc, name, value, mx, my, tx, ty, tdir, tscale, tflags)
  _SFlags = %Q("#{flags}")
  _Desc = %Q("#{desc}")
  _Name = %Q("#{name}")
  _Value = %Q("#{value}")
  _MX = mx.round
  _MY = my.round
  _TX = tx.round
  _TY = ty.round
  _TDir = tdir.round
  _TScale = tscale.round
  _TSFlags = %Q("#{tflags}")
  %Q(Element[#{_SFlags} #{_Desc} #{_Name} #{_Value} #{_MX} #{_MY} #{_TX} #{_TY} #{_TDir} #{_TScale} #{_TSFlags}]\n)
end

def PcbPad(x1, y1, x2, y2, thickness, clearance, mask, name, number, flags)
  _X1 = x1.round
  _Y1 = y1.round
  _X2 = x2.round
  _Y2 = y2.round
  _Thickness = thickness.round
  _Clearance = clearance.round
  _Mask = mask.round
  _Name = %Q("#{name}")
  _Number = %Q("#{number}")
  _SFlags = %Q("#{flags}")
  %Q(  Pad[#{_X1} #{_Y1} #{_X2} #{_Y2} #{_Thickness} #{_Clearance} #{_Mask} #{_Name} #{_Number} #{_SFlags}]\n)
end

#def PcbPad(x1, y1, x2, y2, thickness, clearance, mask, name, number, flags)
def PcbSmartPad(x1, y1, x2, y2, thickness, name, number, flags)
  clearance = GetDim('clearance') * 2
  mask = GetDim('mask') * 2 + thickness
  PcbPad(x1, y1, x2, y2, thickness, clearance, mask, name, number, flags)
end

def PcbPin(x, y, thickness, clearance, mask, drill, name, number, flags)
  _X = x.round
  _Y = y.round
  _Thickness = thickness.round
  _Clearance = clearance.round
  _Mask = mask.round
  _Drill = drill.round
  _Name = %Q("#{name}")
  _Number = %Q("#{number}")
  _SFlags = %Q("#{flags}")
  %Q(  Pin[#{_X} #{_Y} #{_Thickness} #{_Clearance} #{_Mask} #{_Drill} #{_Name} #{_Number} #{_SFlags}]\n)
end

def PcbElementLine(x1, y1, x2, y2, thickness)
  return '' if thickness < MinSilkWidth
  _X1 = x1.round
  _Y1 = y1.round
  _X2 = x2.round
  _Y2 = y2.round
  _Thickness = thickness.round
  %Q(  ElementLine[#{_X1} #{_Y1} #{_X2} #{_Y2} #{_Thickness}]\n)
end

def PcbElementArc(x, y, width, height, startangle, deltaangle, thickness)
  return '' if (thickness < MinSilkWidth) or ([width, height].min < MinSilkWidth) 
  _X = x.round
  _Y = y.round
  _Width = width.round
  _Height = height.round
  _StartAngle = startangle.round
  _DeltaAngle = deltaangle.round
  _Thickness = thickness.round
  %Q(  ElementArc[#{_X} #{_Y} #{_Width} #{_Height} #{_StartAngle} #{_DeltaAngle} #{_Thickness}]\n)
end

def PcbAttribute(name, text)
  _Name = %Q("#{name}")
  _Text = %Q("#{text}")
  %Q|  Attribute(#{_Name} #{_Text})\n|
end

def PcbCommentLine(text)
  '# ' + text
end

# following procedures calls the Pcb... generators

#def PcbElementHeader(flags, desc, name, value, mx, my, tx, ty, tdir, tscale, tflags)
def GenElementHeader(tx, ty, tdir)
  tscale = GetCnt('refdessize')
  desc = AskStr('desc')
  if (name = AskStr('name')) == ''
    name = $ElementName
  end
  PcbElementHeader("", desc, name, "", 0, 0, tx, ty, tdir, tscale, "")
end

#def PcbAttribute(name, text)
def GenAttributes
  if (text = AskStr('name')) == ''
    text = $ElementName
  end
  r = PcbAttribute('name', text)
  %w[author email license dist-license use-license copyright version date comment
     description desc documentation].each do |str|
    if (text = AskStr(str)) != ''
      r += PcbAttribute(str, text)
    end
  end
  return r
end

#def PcbPin(x, y, thickness, clearance, mask, drill, name, number, flags)
def GenPin(x, y, paddia, drilldia, name, number, flags)
  clearance = GetDim('clearance') * 2
  mask = GetDim('mask') * 2 + paddia
  PcbPin(x, y, paddia, clearance, mask, drilldia, name, number, flags)
end

=begin
#def PcbSmartPad(x1, y1, x2, y2, thickness, name, number, flags)
def GenPad(x1, y1, x2, y2, name, number, flags)
  if x1 > x2
    x1, x2 = x2, x1
  end
  if y1 > y2
    y1, y2 = y2, y1
  end
  thickness = [(x2 - x1), (y2 - y1)].min
#  if (x2 - x1) > (y2 - y1)
#    thickness = (y2 - y1)
#  else
#    thickness = (x2 - x1)
#  end
  x1 += 0.5*thickness
  x2 -= 0.5*thickness
  y1 += 0.5*thickness
  y2 -= 0.5*thickness
  PcbSmartPad(x1, y1, x2, y2, thickness, name, number, flags)
end
=end

# maybe better -- ensure that pad is not diagonal due to arithmetic errors
#def PcbSmartPad(x1, y1, x2, y2, thickness, name, number, flags)
def GenPad(x1, y1, x2, y2, name, number, flags)
  if x1 > x2
    x1, x2 = x2, x1
  end
  if y1 > y2
    y1, y2 = y2, y1
  end
  if (x2 - x1) > (y2 - y1)
    thickness = (y2 - y1)
    y1 = y2 = (y1 + y2) / 2.0 # same value, no eps
    x1 += thickness / 2.0
    x2 -= thickness / 2.0
  else
    thickness = (x2 - x1)
    x1 = x2 = (x1 + x2) / 2.0
    y1 += thickness / 2.0
    y2 -= thickness / 2.0
  end
  PcbSmartPad(x1, y1, x2, y2, thickness, name, number, flags)
end

#def PcbElementLine(x1, y1, x2, y2, thickness)
def GenSilkLine(x1, y1, x2, y2)
  thickness = GetDim('silkwidth')
  PcbElementLine(x1, y1, x2, y2, thickness)
end

#def PcbElementArc(x, y, width, height, startangle, deltaangle, thickness)
def GenSilkArc(x, y, width, height, startangle, deltaangle)
  thickness = GetDim('silkwidth')
  PcbElementArc(x, y, width, height, startangle, deltaangle, thickness)
end

def GenSilkBox(x1, y1, x2, y2)
  thickness = GetDim('silkwidth')
  PcbElementLine(x1, y1, x1, y2, thickness) +
  PcbElementLine(x1, y1, x2, y1, thickness) +
  PcbElementLine(x2, y2, x2, y1, thickness) +
  PcbElementLine(x2, y2, x1, y2, thickness)
end

def GenGapBox(x1, y1, x2, y2, leftgap, rightgap)
  if (leftgap < MinSilkWidth) and  (rightgap < MinSilkWidth)
    return GenSilkBox(x1, y1, x2, y2)
  end
  thickness = GetDim('silkwidth')
  if x1 > x2 
    x1, x2 = x2, x1
  end
  if y1 > y2 
    y1, y2 = y2, y1
  end
  dy1 = ((y2 - y1) - leftgap) / 2.0
  dy2 = ((y2 - y1) - rightgap) / 2.0
  PcbElementLine(x1, y1, x1, y1 + dy1, thickness) +
  PcbElementLine(x1, y2, x1, y2 - dy1, thickness) +
  PcbElementLine(x1, y1, x2, y1, thickness) +
  PcbElementLine(x2, y1, x2, y1 + dy2, thickness) +
  PcbElementLine(x2, y2, x2, y2 - dy2, thickness) +
  PcbElementLine(x2, y2, x1, y2, thickness)
end

# (x1,y1) corner is damaged
def GenDamagedBox(x1, y1, x2, y2)
  thickness = GetDim('silkwidth')
  #d = [(x1-x2).abs, (y1-y2).abs].min / 10.0
  d = ((x1-x2).abs + (y1-y2).abs) / 20.0
  if x1 < x2 
    x = x1 + d
  else
    x = x1 - d
  end
  if y1 < y2 
    y = y1 + d
  else
    y = y1 - d
  end
  PcbElementLine(x1, y, x1, y2, thickness) +
  PcbElementLine(x, y1, x2, y1, thickness) +
  PcbElementLine(x1, y, x, y1, thickness) +
  PcbElementLine(x2, y2, x2, y1, thickness) +
  PcbElementLine(x2, y2, x1, y2, thickness)
end

def WriteElementToFile(el, filename)
  dir = AskStr('elementdir')
  begin
    File.open(dir + filename, "w") do |file|
      file.puts(el)
    end
  rescue => e
    puts e.message
  end
end

# functions below generate fancy elemenents -- feel free to add more...

def Generate(filename)
  case $Device
    when 'DIP'
      GenDIP(filename)
    when 'SIP'
      GenSIP(filename)
    when 'QFP'
      GenQFP(filename)
    when 'CAPPR'
      GenCAPPR(filename)
    when 'TRIMR'
      GenTRIMR(filename)
   when 'PinHole'
      GenPinHole(filename)
   when 'MountingHole'
      GenMountingHole(filename)
  else
    puts "Can't generate device #{$Device}!"
  end
end

# note: we generate an element symmetric to mark at (0,0)
# we start with upper left corner with negative coordinates...
# o  o       o
# o  o  and     o
# o  o       o
def GenDIP(name)
  leftgap = rightgap = 0
  width = GetDim('width')
  pins = GetCnt('pins')
  if pins < 2 then print "GenDIP(#{name}): We need at least two pins!\n" end
  if pins > 2
    pitch = GetDim('pitch')
    if pitch < 1000 # 10 mil
      print "GenDIP(#{name}): pitch is too small!\n"
    end
  else
    pitch = 0
  end
  paddia = GetDim('pad-dia')
  drilldia = GetScaledDrillDia()
  #drilldia = GetDim('drill-dia')
  if [width, paddia, drilldia].min < 1000 # 10 mil
    print "GenDIP(#{name}): Width, paddia or drilldia too small!\n"
  end
  silkwidth = GetDim('silkwidth')
  silkoffset = GetDim('silkoffset')
  ovalpads = %w[1 yes oval ovalpads true].include?(AskStr('ovalpads'))
  silkbox = GetStr('silkbox')
  unless %w[outer inner custom].include?(silkbox); silkbox = 'none' end
  p1silkmark = AskStr('p1silkmark') # we can draw: semicircle, notch, damage or slash
  if %w[1 yes mark silkmark true].include?(p1silkmark)
    p1silkmark = 'semicircle'
  end
  p1coppermark = GetStr('p1coppermark') # we can mark with: square or octagon
  if p1coppermark == 'octagon';
  elsif %w[square 1 yes mark p1mark coppermark p1coppermark true].include?(p1coppermark)
    p1coppermark = 'square'
  else
   p1coppermark = ''
  end
  rows = (pins + 1) / 2
  x = -width / 2.0 # start at upper left corner with negative coordinates
  y = -(pitch / 2.0) * (rows - 1)
  boxoffset = silkoffset + (silkwidth + paddia) / 2.0
  if silkbox == 'outer'
    bx = x - boxoffset
    by = y - boxoffset
  elsif silkbox == 'inner'
    bx = x + boxoffset
    by = y
  elsif silkbox == 'custom'
    bx = -GetDim('silkboxwidth') / 2.0
    by = -GetDim('silkboxheight') / 2.0
    if bx - boxoffset > x
      silkbox = 'inner'
    elsif by + boxoffset < y
      silkbox = 'outer'
      if bx + boxoffset > x
        leftgap = 2 * (y.abs + silkoffset) + paddia + silkwidth
        dy = (pitch / 2.0) * (pins - rows - 1)
        rightgap = 2 * (dy + silkoffset) + paddia + silkwidth
        if p1silkmark == 'damage'
          p1silkmark = 'slash'
        end
      end
    else
      silkbox = 'none'
      print "GenDIP(#{name}): Custom silkbox touches pads -- not drawn!\n"
    end
  else
    bx = by = 0
  end
  if (-bx < MinSilkWidth) or (-by < MinSilkWidth)
    silkbox = 'none'; bx = by = 0
  end
  tx = [x, bx].min
  ty = [y- paddia / 2.0, by - silkwidth / 2.0].min - (PCB_DefaultTextSize + RefdesToSilkOffset) * GetCnt('refdessize')
  r = GenElementHeader(tx, ty, 0) + "(\n"
  pinflags = p1coppermark
  if p1coppermark == ''
    padflags = 'onsolder'
  else
    padflags = 'square,onsolder'
  end
  dy = pitch
  (1..pins).each do |n|
    r += GenPin(x, y, paddia, drilldia, n, n, pinflags)
    if ovalpads 
      r += PcbSmartPad(x - paddia / 4.0, y, x + paddia / 4.0, y, paddia, n, n, padflags) 
    end
    pinflags = ''
    padflags = 'onsolder'
    if n == rows
      x = -x
      y = (pitch / 2.0) * (pins - rows - 1)
      dy = -dy
    else
      y += dy
    end
  end
  unless silkbox == 'none'
    if leftgap > 0
      r += GenGapBox(bx, by, -bx, -by, leftgap, rightgap)
    elsif p1silkmark == 'damage'
      r += GenDamagedBox(bx, by, -bx, -by)
    else
      r += GenSilkBox(bx, by, -bx, -by)
    end
    if p1silkmark == 'semicircle'
      r += GenSilkArc(0, by, bx.abs * 0.2, bx.abs * 0.2, 0, 180)
    elsif p1silkmark == 'slash'
      r += GenSilkLine(bx + 0.05 * (bx + by), by + 0.05 * (bx + by), bx, by)
    elsif p1silkmark == 'notch'
      r += GenSilkLine(0.2 * bx, by, 0, by - 0.2 * bx)
      r += GenSilkLine(-0.2 * bx, by, 0, by - 0.2 * bx)
    end
  end
  r += GenAttributes() + ")\n"
  WriteElementToFile(r, name)
end

# note: we generate an element symmetric to mark at (0,0)
# we start with upper left corner with negative coordinates...
#  -----------
# | o o o o o |
#  -----------
def GenSIP(name)
  pins = GetCnt('pins')
  if pins <= 0 then print "GenSIP(#{name}): We need at least one pin!\n" end
  pitch = GetDim('pitch')
  paddia = GetDim('pad-dia')
  drilldia = GetScaledDrillDia()
  if [pitch, paddia, drilldia].min < 1000 # 10 mil
    print "GenSIP(#{name}): Pitch, paddia or drilldia too small!\n"
  end
  silkwidth = GetDim('silkwidth')
  silkoffset = GetDim('silkoffset')
  ovalpads = %w[1 yes oval ovalpads true].include?(AskStr('ovalpads'))
  silkbox = GetStr('silkbox')
  unless %w[outer custom].include?(silkbox); silkbox = 'none' end
  p1silkmark = AskStr('p1silkmark') # we can draw: damage or slash
  if %w[1 yes mark silkmark true].include?(p1silkmark)
    p1silkmark = 'slash'
  end
  p1coppermark = AskStr('p1coppermark') # we can mark with: square or octagon
  if p1coppermark == 'octagon';
  elsif %w[square 1 yes mark p1mark coppermark p1coppermark true].include?(p1coppermark)
    p1coppermark = 'square'
  else
   p1coppermark = ''
  end
  x = -(pitch / 2.0) * (pins - 1)
  y = 0
  boxoffset = silkoffset + (silkwidth + paddia) / 2.0
  gap = 0
  if silkbox == 'outer'
    bx = x - boxoffset
    by = y - boxoffset
  elsif silkbox == 'custom'
    bx = -GetDim('silkboxwidth') / 2.0
    by = -GetDim('silkboxheight') / 2.0
    if by <= y - boxoffset
      if bx <= x - boxoffset
        gap = 0
      else
        gap = 2 * boxoffset
        if p1silkmark == 'damage'
          p1silkmark = 'slash'
        end
      end
    else
      silkbox = 'none'
      print "GenSIP(#{name}): Custom silkbox touches pads -- not drawn!\n"
    end
  else
    bx = by = 0
  end
  tx = [x, bx].min
  ty = [y - paddia / 2.0, by - silkwidth / 2.0].min - (PCB_DefaultTextSize + RefdesToSilkOffset) * GetCnt('refdessize')
  r = GenElementHeader(tx, ty, 0) + "(\n"
  pinflags = p1coppermark
  if p1coppermark == ''
    padflags = 'onsolder'
  else
    padflags = 'square,onsolder'
  end
  (1..pins).each do |n|
    r += GenPin(x, y, paddia, drilldia, n, n, pinflags)
    if ovalpads 
      r += PcbSmartPad(x, y - paddia / 4.0, x, y + paddia / 4.0, paddia, n, n, padflags)
    end
    pinflags = ''
    padflags = 'onsolder'
    x += pitch
  end
  unless silkbox == 'none'
    if gap > 0
      r += GenGapBox(bx, by, -bx, -by, gap, gap)
    elsif p1silkmark == 'damage'
      r += GenDamagedBox(bx, by, -bx, -by)
    else
      r += GenSilkBox(bx, by, -bx, -by)
    end
    if p1silkmark == 'slash'
      r += GenSilkLine(bx + 0.05 * (bx + by), by + 0.05 * (bx + by), bx, by)
    end
  end
  r += GenAttributes() + ")\n"
  WriteElementToFile(r, name)
end

# note: we generate an element symmetric to mark at (0,0)
# we start with upper left corner with negative coordinates...
# o  o       o   o       ooo       o
# o  o  and  o O o  and  o o  and    o  and  o   o
# o  o       o   o       ooo       o           o
def GenQFP(name)
  leftgap = rightgap = 0
  pins = GetCnt('pins')
  if pins < 2 then print "GenQFP(#{name}): We need at least two pins!\n" end
  width = GetDim('width')
  rows = GetCnt('rows')
  if rows <= 0 then rows = pins / 4 end
  cols = [(pins - 2 * rows + 1) / 2, 0].max # pins at bottom, at top may be one less
  quad = pins > 2 * rows
  if (rows > 1) or (cols > 1)
    pitch = GetDim('pitch')
    if pitch < 1000 # 10 mil
      print "GenQFP(#{name}): pitch is too small!\n"
    end
  else
    pitch = 0
  end
  padthickness = GetDim('padthickness')
  padlength = GetDim('padlength')
  cpw = GetDim('centerpadwidth') / 2.0
  cph = GetDim('centerpadheight') / 2.0
  if (cpw < MinSilkWidth) or (cph < MinSilkWidth) then cpw = cph = 0 end
  clearance = GetDim('clearance')
  if quad
    height = GetDim('height')
    if width < MinSilkWidth then width = height end
    if height < MinSilkWidth then height = width end
    if width < 1000 # 10 mil
      print "GenQFP(#{name}): Width or height is too small!\n"
    end
  else
    height = 0
  end
  if [width, padthickness, padlength].min < 1000 # 10 mil
    print "GenQFP(#{name}): Width, padthickness or padlength too small!\n"
  end
  silkwidth = GetDim('silkwidth')
  silkoffset = GetDim('silkoffset')
  ovalpads = %w[1 yes oval ovalpads true].include?(AskStr('ovalpads'))
  silkbox = GetStr('silkbox')
  unless %w[outer inner custom].include?(silkbox); silkbox = 'none' end
  p1silkmark = AskStr('p1silkmark') # we can draw: circle, damage or slash
  if %w[1 yes mark p1mark silkmark p1silkmark true].include?(p1silkmark)
    p1silkmark = 'slash'
  end
  p1coppermark = %w[1 yes true mark p1mark coppermark p1coppermark].include?(AskStr('p1coppermark'))
  x = -width / 2.0 # y is center of topmost pad
  if quad then y = -height / 2.0 else y = -(pitch / 2.0) * (rows - 1) end
  boxoffset = silkoffset + (silkwidth + padlength) / 2.0
  if silkbox == 'outer' 
    bx = x - boxoffset
    by = y - boxoffset
  elsif silkbox == 'inner'
    bx = x + boxoffset
    if quad then
      by = y + boxoffset
    else
      if cph > 0
        by = -cph - silkoffset - silkwidth / 2.0
      else
        by = y
      end
    end 
  elsif silkbox == 'custom'
    bx = -GetDim('silkboxwidth') / 2.0
    by = -GetDim('silkboxheight') / 2.0
    if quad
      if bx + boxoffset < x and by + boxoffset < y
        silkbox = 'outer'
      elsif bx - boxoffset > x and by - boxoffset > y
        silkbox = 'inner'
      else
        silkbox = 'none'
      end
    else
      if bx - boxoffset > x
        silkbox = 'inner'
      elsif by + boxoffset < y
        silkbox = 'outer'
        if bx + boxoffset > x
          leftgap = 2 * (y.abs + silkoffset) + padthickness + silkwidth
          dy = (pitch / 2.0) * (pins - rows - 1)
          rightgap = 2 * (dy + silkoffset) + padthickness + silkwidth
          if p1silkmark == 'damage'
            p1silkmark = 'slash'
          end
        end
      else
        silkbox = 'none'
      end
    end
    if silkbox == 'none'
      print "GenQFP(#{name}): Custom silkbox touches pads -- not drawn!\n"
    end
  else
    bx = by = 0
  end
  if (-bx < MinSilkWidth) or (-by < MinSilkWidth)
    silkbox = 'none'; bx = by = 0
  end
  if (x + padlength / 2.0 + clearance > -cpw) or
     (quad and (y + padlength / 2.0 + clearance > -cph))
    print "GenQFP(#{name}): Centerpad touches pads!\n"
    Process.exit
  end
  if (silkbox != 'none') and (cpw > 0)
    if (bx + silkoffset + silkwidth / 2.0 > -cpw + 1) or (by + silkoffset + silkwidth / 2.0 > -cph + 1) # eps 0.01mil
      print "GenQFP(#{name}): Silkbox overlaps Center Pad!\n"
    end
  end
  tx = [x, bx].min
  if quad then dy = padlength else dy = padthickness end
  ty = [y - dy / 2.0, by - silkwidth / 2.0].min - (PCB_DefaultTextSize + RefdesToSilkOffset) * GetCnt('refdessize')
  r = GenElementHeader(tx, ty, 0) + "(\n"
  if ovalpads
    padflags = p1flags = ''
    if p1coppermark
      p1flags = 'square'
    end
  else
    padflags = p1flags = 'square'
    if p1coppermark
      p1flags = ''
    end
  end
  x, y, dx, dy, xext, yext = 0 # make these values global to do-loop
  (1..pins).each do |n|
    if n == 1
      x = -width / 2.0
      y = -(pitch / 2.0) * (rows - 1)
      dx = 0
      dy = pitch
      xext = padlength / 2.0
      yext = padthickness / 2.0
    end
    if n == rows + 1
      x = -(pitch / 2.0) * (cols - 1)
      y = height / 2.0
      dx = pitch
      dy = 0
      xext = padthickness / 2.0
      yext = padlength / 2.0
    end
    if n == (rows + cols) + 1
      x = width / 2.0
      if quad then y = rows else y = pins - rows end    
      y = (pitch / 2.0) * (y - 1)
      dx = 0
      dy = -pitch
      xext = padlength / 2.0
      yext = padthickness / 2.0
    end 
    if n == (2 * rows + cols) + 1
      x = (pitch / 2.0) * (pins - 2 * rows - cols - 1)
      y = - height / 2.0
      dx = -pitch
      dy = 0
      xext = padthickness / 2.0
      yext = padlength / 2.0
    end
    r += GenPad(x - xext, y - yext, x + xext, y + yext, n, n, p1flags)
    p1flags = padflags
    x += dx
    y += dy
  end
  if cpw > 0
    r += GenPad(-cpw, -cph, cpw, cph, pins + 1, pins + 1, 'square')
  end
  unless silkbox == 'none'
    if leftgap > 0
      r += GenGapBox(bx, by, -bx, -by, leftgap, rightgap)
    elsif p1silkmark == 'damage'
      r += GenDamagedBox(bx, by, -bx, -by)
    else
      r += GenSilkBox(bx, by, -bx, -by)
    end
    if p1silkmark == 'circle'
      dx = -(bx + by) / 20.0
      if silkbox == 'inner'
        dy = 2 * dx + silkwidth # offset of circle to upper left corner
      else
        dy = -dx - silkwidth
      end  
      r += GenSilkArc(bx + dy, by + dy, dx, dx, 0, 360)
    elsif p1silkmark == 'slash'
      r += GenSilkLine(bx + 0.05 * (bx + by), by + 0.05 * (bx + by), bx, by)
    end
  end
  r += GenAttributes() + ")\n"
  WriteElementToFile(r, name)
end

def GenCAPPR(name)
  cx = cy = cw = ch = paddia = silkwidth = silkoffset = 0

  touchpad = lambda {|i, px, py|
    x = cx - Math.cos(i*Math::PI/180) * cw # position on the silk circle
    y = cy + Math.sin(i*Math::PI/180) * ch
    return (x - px)**2 + (y - py)**2 <= ((paddia + silkwidth) / 2.0 + silkoffset)**2
  }

  width = GetDim('width')
  paddia = GetDim('pad-dia')
  drilldia = GetScaledDrillDia()
  #drilldia = GetDim('drill-dia')
  if [width, paddia, drilldia].min < 1000 # 10 mil
    print "GenCAPPR(#{name}): Width, paddia or drilldia too small!\n"
  end
  silkdia = GetDim('silkcircle-dia')
  silkwidth = GetDim('silkwidth')
  silkoffset = GetDim('silkoffset')
  silkmark = AskStr('silkmark') # we can draw: pjplus, pjminus, pjcircle with j=1,2
  p1coppermark = AskStr('p1coppermark') # we can mark with: square or octagon
  if p1coppermark == 'octagon';
  elsif %w[square 1 yes mark p1mark coppermark p1coppermark true].include?(p1coppermark)
    p1coppermark = 'square'
  else
   p1coppermark = ''
  end
  x2 = width / 2.0
  x1 = -x2
  y1 = y2 = 0
  cx = cy = 0
  cw = ch = silkdia / 2.0
  tx = [x1, -cw].min
  ty = [-paddia / 2.0, cy - ch - silkwidth / 2.0].min - (PCB_DefaultTextSize + RefdesToSilkOffset) * GetCnt('refdessize')
  r = GenElementHeader(tx, ty, 0) + "(\n"
  r += GenPin(x1, y1, paddia, drilldia, 1, 1, p1coppermark)
  r += GenPin(x2, y2, paddia, drilldia, 2, 2, '')
  i = 0 # start pointing to neg x (left), sweep counterclockwise
  while i < 360
    break if touchpad.call(i, x1, y1) or touchpad.call(i, x2, y2)
    i += 1
  end
  if i == 360
    r += GenSilkArc(cx, cy, cw, ch, 0, 360)
  else
    j = i
    sweep = 0
    lasttouch = j
    while j <= i + 360
      if touchpad.call(j, x1, y1) or touchpad.call(j, x2, y2) # or  j == i + 360
        if sweep > 1
          r += GenSilkArc(cx, cy, cw, ch, lasttouch + 1, sweep - 1)
        end
        sweep = 0
        lasttouch = j
      else
        sweep += 1
      end
      j += 1
    end
  end
  d = silkdia / 10.0
  x2 = [cx - cw - silkwidth / 2.0 - silkoffset, x1 - paddia /2.0 - silkoffset].min - silkwidth / 2.0 
  x1 = x2 - d
  if silkmark[0..1] == 'p2'
    silkmark[0..1] = 'p1'
    x1 = -x1
    x2 = -x2
  end
  if silkmark == 'p1minus'
    r += GenSilkLine(x1, cy, x2, cy)
  elsif silkmark == 'p1plus'
   r += GenSilkLine(x1, cy, x2, cy)
   r += GenSilkLine((x1 + x2) / 2.0, cy - d / 2.0, (x1 + x2) / 2.0, cy + d / 2.0)
  elsif silkmark == 'p1circle'
   r += GenSilkArc((x1 + x2) / 2.0, cy, d / 2.0, d / 2.0, 0, 360)
  end
  r += GenAttributes() + ")\n"
  WriteElementToFile(r, name)
end

def GenTRIMR(name)
  cx = cy = cw = ch = paddia = silkwidth = silkoffset = 0

  touchpad = lambda {|i, px, py|
    x = cx - Math.cos(i*Math::PI/180) * cw # position on the silk circle
    y = cy + Math.sin(i*Math::PI/180) * ch
    return (x - px)**2 + (y - py)**2 <= ((paddia + silkwidth) / 2.0 + silkoffset)**2
  }

  paddia = GetDim('pad-dia')
  drilldia = GetScaledDrillDia()
  #drilldia = GetDim('drill-dia')
  if [paddia, drilldia].min < 1000 # 10 mil
    print "GenTRIMR(#{name}): Paddia or drilldia too small!\n"
  end
  x1 = GetDim('x1')
  y1 = GetDim('y1')
  x2 = GetDim('x2')
  y2 = GetDim('y2')
  x3 = GetDim('x3')
  y3 = GetDim('y3')
  cx = GetDim('cx')
  cy = GetDim('cy')
  chole = GetDim('chole')
  silkdia = GetDim('silkcircle-dia')
  silkwidth = GetDim('silkwidth')
  silkoffset = GetDim('silkoffset')
  p1coppermark = AskStr('p1coppermark') # we can mark with: square or octagon
  if p1coppermark == 'octagon';
  elsif %w[square 1 yes mark p1mark coppermark p1coppermark true].include?(p1coppermark)
    p1coppermark = 'square'
  else
   p1coppermark = ''
  end
  cw = ch = silkdia / 2.0
  tx = [x1, x2, x3, -cw].min
  ty = [y1, y2, y3].min - paddia / 2.0
  ty = [ty, cy - ch - silkwidth / 2.0].min - (PCB_DefaultTextSize + RefdesToSilkOffset) * GetCnt('refdessize')
  r = GenElementHeader(tx, ty, 0) + "(\n"
  r += GenPin(x1, y1, paddia, drilldia, 1, 1, p1coppermark)
  r += GenPin(x2, y2, paddia, drilldia, 2, 2, '')
  #if ([x3, y3] != [x1, y1]) and ([x3, y3] != [x2, y2]) # rounding errors
  if ((x3-x1).abs > 10 or (y3-y1).abs > 10) and ((x3-x2).abs > 10 or (y3-y2).abs > 10) # 0.1mil 
    r += GenPin(x3, y3, paddia, drilldia, 3, 3, '')
  end
  if chole > MinSilkWidth
    r += GenPin(cx, cy, chole, chole, '', '', 'hole')
  end 
  i = 0 # start pointing to neg x (left), sweep counterclockwise
  while i < 360
    break if touchpad.call(i, x1, y1) or touchpad.call(i, x2, y2) or touchpad.call(i, x3, y3)
    i += 1
  end
  if i == 360
    r += GenSilkArc(cx, cy, cw, ch, 0, 360)
  else
    j = i
    sweep = 0
    lasttouch = j
    while j <= i + 360
      if touchpad.call(j, x1, y1) or touchpad.call(j, x2, y2) or touchpad.call(j, x3, y3)
        if sweep > 1
          r += GenSilkArc(cx, cy, cw, ch, lasttouch + 1, sweep - 1)
        end
        sweep = 0
        lasttouch = j
      else
        sweep += 1
      end
      j += 1
    end
  end
  r += GenAttributes() + ")\n"
  WriteElementToFile(r, name)
end

# hole or single pin
def GenPinHole(name)  
  drilldia = GetScaledDrillDia()
  if drilldia < 1000 # 10 mil
    print "GenPinHole(#{name}): Drilldia too small!\n"
  end
  paddia = GetDim('pad-dia')
  silkdia = GetDim('silk-dia')
  if (silkdia != 0) and (silkdia < drilldia)
    silkdia = -1
    silkwidth = 0
  else
    silkwidth = GetDim('silkwidth')
  end
  if silkdia == 0
    silkoffset = GetDim('silkoffset')
    silkdia = [paddia, drilldia].max + 2 * silkoffset + silkwidth
  end
  tx = - [paddia, drilldia, silkdia + silkwidth].max / 2.0
  ty = tx - (PCB_DefaultTextSize + RefdesToSilkOffset) * GetCnt('refdessize')
  r = GenElementHeader(tx, ty, 0) + "(\n"
  if paddia <= drilldia
    r += GenPin(0, 0, drilldia, drilldia, '', '', 'hole')
  else
    r += GenPin(0, 0, paddia, drilldia, 1, 1, '')
  end
  if silkdia > 0
    r += GenSilkArc(0, 0, silkdia / 2.0, silkdia / 2.0, 0, 360)
  end
  r += GenAttributes() + ")\n"
  WriteElementToFile(r, name)
end

# similar to GenPinHole(), but using pads, leaving more area for traces on inner layers 
def GenMountingHole(name)  
  drilldia = GetScaledDrillDia()
  if drilldia < 1000 # 10 mil
    print "GenMountingHole(#{name}): Drilldia too small!\n"
  end
  paddia = GetDim('pad-dia')
  silkdia = GetDim('silk-dia')
  if (silkdia != 0) and (silkdia < drilldia)
    silkdia = -1
    silkwidth = 0
  else
    silkwidth = GetDim('silkwidth')
  end
  if silkdia == 0
    silkoffset = GetDim('silkoffset')
    silkdia = [paddia, drilldia].max + 2 * silkoffset + silkwidth
  end
  tx = - [paddia, drilldia, silkdia + silkwidth].max / 2.0
  ty = tx - (PCB_DefaultTextSize + RefdesToSilkOffset) * GetCnt('refdessize')
  r = GenElementHeader(tx, ty, 0) + "(\n"
  if paddia <= drilldia
    r += GenPin(0, 0, drilldia, drilldia, '', '', 'hole')
  else
    minpaddia = drilldia + 2000 # make pad of pin 20mil larger than drill to ensure minimal anular ring 
    r += GenPin(0, 0, minpaddia, drilldia, 1, 1, '')
    if minpaddia < paddia 
      r += PcbSmartPad(0, 0, 0, 0, paddia, 1, 1, '')
      r += PcbSmartPad(0, 0, 0, 0, paddia, 1, 1, 'onsolder')
    end
  end
  if silkdia > 0
    r += GenSilkArc(0, 0, silkdia / 2.0, silkdia / 2.0, 0, 360)
  end
  r += GenAttributes() + ")\n"
  WriteElementToFile(r, name)
end

# Start processing after all functions are read
main

