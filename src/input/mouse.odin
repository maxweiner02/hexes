package input

import "src:hex"
import "vendor:raylib"

// Contains information regarding the input state
InputState :: struct {
	last_hovered_key: i64,
	has_last_hovered: bool,
}

set_last_hovered :: proc(input: ^InputState, key: i64) {
	input^.has_last_hovered = true
	input^.last_hovered_key = key
}

clear_last_hovered :: proc(input: ^InputState) {
	input^.has_last_hovered = false
	input^.last_hovered_key = 0
}

// returns a bool that says if the mouse is within a hex
point_in_hex :: proc(layout: hex.Layout, h: ^hex.Hex, p: raylib.Vector2) -> bool {
	corners := hex.hex_corners(layout, h^)
	return raylib.CheckCollisionPointPoly(p, &corners[0], 6)
}

// helper to get mouse position; returns a Vector2
get_mouse_pos :: proc() -> raylib.Vector2 {
	return raylib.GetMousePosition()
}

// goes through the HexMap and returns a pointer to the Hex that the mouse is overlapping with
pick_hex :: proc(m: ^hex.HexMap, layout: hex.Layout, p: raylib.Vector2) -> (^hex.Hex, bool) {
	for _, hp in m {
		if point_in_hex(layout, hp, p) do return hp, true
	}
	return nil, false
}

handle_hover :: proc(input: ^InputState, m: ^hex.HexMap, layout: hex.Layout) {
	mouse_pos := get_mouse_pos()
	hovered_hex, ok := pick_hex(m, layout, mouse_pos)
	if ok {
		// if there is no hovered tile, then set it
		if input.has_last_hovered == false {set_last_hovered(input, hex.pack_hex(hovered_hex))
		} else if hex.pack_hex(hovered_hex) != input^.last_hovered_key {
			// if the existing hovered tile doesnt match the tile under the mouse, update it
			set_last_hovered(input, hex.pack_hex(hovered_hex))
		}
	} else {
		// no hex is being hovered over
		clear_last_hovered(input)
	}
}

// Orchestrates all mouse events
handle_mouse :: proc(input: ^InputState, m: ^hex.HexMap, layout: hex.Layout) {
	handle_hover(input, m, layout)
}
