package hex

Hex :: struct {
	q: i32,
	r: i32,
}

// q + r + s = 0
s_of :: proc(h: Hex) -> i32 {
	return -h.q - h.r
}

//add get_neighbors, get_distance, etc
