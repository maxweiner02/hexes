package hexes

import "vendor:raylib"

apply_input_to_map :: proc(input_state: InputState, m: ^HexMap) {
	// go through HexMap
	for _, &hp in m {
		// we have a hovered hex, find it
		if input_state.has_last_hovered == true {
			// get coords for hovered hex
			q, r := unpack_axial(input_state.last_hovered_key)
			// make sure it exists
			hovered_hex, ok := get_hex(m, q, r)
			if ok {
				// found it, make hovered true
				if &hp == hovered_hex {
					hp.hovered = true
				} else {
					// not it, hover needs to be false
					hp.hovered = false
				}
			}
		} else {
			hp.hovered = false
		}

		// we have a clicked hex, find it
		if input_state.has_last_selected == true {
			// get coords for clicked hex
			q, r := unpack_axial(input_state.last_selected_key)
			// make sure it exists
			clicked_hex, ok := get_hex(m, q, r)
			if ok {
				// found it, make selected true
				if &hp == clicked_hex {
					hp.selected = true
				} else {
					// not it, selected needs to be false
					hp.selected = false
				}
			}
		} else {
			hp.selected = false
		}
	}

}

main :: proc() {
	width: i32 = 960
	height: i32 = 720
	raylib.InitWindow(width, height, cstring("hexes"))
	defer raylib.CloseWindow()
	raylib.SetTargetFPS(60)

	layout := Layout {
		radius = 30,
		origin = raylib.Vector2{cast(f32)width / 2, cast(f32)height / 2}, // center the grid
	}

	// Input State
	input_state := InputState {
		last_hovered_key  = 0,
		last_selected_key = 0,
		has_last_hovered  = false,
		has_last_selected = false,
	}

	map_radius: i32 = 6

	m := make(HexMap)
	defer delete(m)

	for q in -map_radius ..= map_radius {
		for r in -map_radius ..= map_radius {
			s := -q - r
			if (q >= -map_radius && q <= map_radius) &&
			   (r >= -map_radius && r <= map_radius) &&
			   (s >= -map_radius && s <= map_radius) {
				hp := Hex {
					q = q,
					r = r,
				}
				// selected defaults to false
				set_hex(&m, hp)
			}
		}
	}

	for !raylib.WindowShouldClose() {
		// check all inputs to mutate the InputState
		handle_mouse(&input_state, m, layout)

		// mutate the hexMap according to the InputState
		apply_input_to_map(input_state, &m)

		raylib.BeginDrawing()
		defer raylib.EndDrawing()
		raylib.ClearBackground(raylib.RAYWHITE)

		draw_hex_map(m, layout)
	}
}
