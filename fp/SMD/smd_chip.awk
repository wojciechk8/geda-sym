BEGIN {
	help_auto()
	set_arg(P, "?shape", "square")
	set_arg(P, "?outline", "true")
	
	SIZE["0402", "x"] = parse_dim("0.7mm")
	SIZE["0402", "y"] = parse_dim("0.9mm")
	SIZE["0402", "c"] = parse_dim("1.3mm")
	
	SIZE["0603", "x"] = parse_dim("1mm")
	SIZE["0603", "y"] = parse_dim("1.1mm")
	SIZE["0603", "c"] = parse_dim("1.7mm")
	
	SIZE["0805", "x"] = parse_dim("1.5mm")
	SIZE["0805", "y"] = parse_dim("1.3mm")
	SIZE["0805", "c"] = parse_dim("1.9mm")
	
	SIZE["1206", "x"] = parse_dim("1.8mm")
	SIZE["1206", "y"] = parse_dim("1.6mm")
	SIZE["1206", "c"] = parse_dim("2.8mm")
	
	SIZE["1210", "x"] = parse_dim("2.7mm")
	SIZE["1210", "y"] = parse_dim("1.6mm")
	SIZE["1210", "c"] = parse_dim("2.8mm")
	
	SIZE["2010", "x"] = parse_dim("2.7mm")
	SIZE["2010", "y"] = parse_dim("1.8mm")
	SIZE["2010", "c"] = parse_dim("4.4mm")
	
	SIZE["2512", "x"] = parse_dim("3.2mm")
	SIZE["2512", "y"] = parse_dim("1.8mm")
	SIZE["2512", "c"] = parse_dim("5.6mm")
	
	OUTLINE_DIST = parse_dim("0.25mm")

	proc_args(P, "x,y,z,g,c,size,shape,outline")
	x = parse_dim(P["x"])
	y = parse_dim(P["y"])
	z = parse_dim(P["z"])
	g = parse_dim(P["g"])
	c = parse_dim(P["c"])
	#size = substr(P["size"], 0, 4)
	size = P["size"]
	shape = P["shape"]
	outline = tobool(P["outline"])
	
	if (!SIZE[size, "x"])
		error("no predefined size " size)

	if (size == "") {
		if (!x)
			error("x must be given")
		if (z && g)
			y = (z - g) / 2
		if (c && g)
			y = c - g
		if (c && z)
			y = z - c
		if (y && z)
			c = z - y
		if (y && g)
			c = g + y
		if (!(y && c))
			error("not enough parameters")
	# predefined size
	} else {
		x = SIZE[size, "x"]
		y = SIZE[size, "y"]
		c = SIZE[size, "c"]
	}

	# assume only x, y, c are given
	element_begin("", "R1", "1k"   ,0,0, c/2 + (y/2) + (OUTLINE_DIST*2), -(x/2 + OUTLINE_DIST))

	if (x > y) {
		element_pad(-c/2, -(x/2 - y/2), -c/2, x/2 - y/2, y, 1, shape == "square" ? "square" : "", "", y + 2*DEFAULT["pad_mask"])
		element_pad(c/2, -(x/2 - y/2), c/2, x/2 - y/2, y, 2, shape == "square" ? "square" : "", "", y + 2*DEFAULT["pad_mask"])
	} else {
		element_pad(-(c/2 + (y/2 - x/2)), 0, -(c/2 - (y/2 - x/2)), 0, x, 1, shape == "square" ? "square" : "", "", x + 2*DEFAULT["pad_mask"])
		element_pad(c/2 - (y/2 - x/2), 0, c/2 + (y/2 - x/2), 0, x, 2, shape == "square" ? "square" : "", "", x + 2*DEFAULT["pad_mask"])
	}

	if (outline)
		element_rectangle(-(c/2 + y/2 + OUTLINE_DIST), -(x/2 + OUTLINE_DIST), c/2 + y/2 + OUTLINE_DIST, x/2 + OUTLINE_DIST)
	
	element_end()
}
