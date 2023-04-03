extends Object

static func http_headers(headers: PackedStringArray):
	var out = {}
	for header in headers:
		var data = header.split(":", true, 1)
		out[data[0]] = data[1].strip_edges()
		
	return out
