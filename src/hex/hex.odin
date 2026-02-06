package hex

Hex :: struct {
	q:        i32,
	r:        i32,
	selected: bool,
	hovered:  bool,
}

// q + r + s = 0
s_of :: proc(h: Hex) -> i32 {
	return -h.q - h.r
}

toggle_selection :: proc(h: ^Hex) {
	h^.selected = !h^.selected
}

set_hovered :: proc(h: ^Hex, hovering: bool) {
	h^.hovered = hovering
}
