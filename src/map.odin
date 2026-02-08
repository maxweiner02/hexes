package hexes

HexMap :: map[i64]Hex

pack_axial :: proc(q: i32, r: i32) -> i64 {
	return (i64(q) << 32) | i64(cast(u32)r)
}

pack_hex :: proc(h: Hex) -> i64 {
	return pack_axial(h.q, h.r)
}

unpack_axial :: proc(key: i64) -> (q: i32, r: i32) {
	return i32(key >> 32), i32(key)
}

set_hex :: proc(m: ^HexMap, h: Hex) {
	m^[pack_hex(h)] = h
}

delete_hex :: proc(m: ^HexMap, h: ^Hex) {
	delete_key(m, pack_hex(h^))
}

has_hex :: proc(m: ^HexMap, q: i32, r: i32) -> bool {
	_, ok := m^[pack_axial(q, r)]
	return ok
}

get_hex :: proc(m: ^HexMap, q: i32, r: i32) -> (^Hex, bool) {
	h, ok := &m^[pack_axial(q, r)]
	return h, ok
}
