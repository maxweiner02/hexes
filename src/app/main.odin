package app

import "src:hex"
import "src:render"
import "vendor:raylib"

main :: proc() {
	width: i32 = 960
	height: i32 = 720
	raylib.InitWindow(width, height, cstring("hexes"))
	defer raylib.CloseWindow()
	raylib.SetTargetFPS(60)

	// Pointy-topped axial layout
	layout := hex.Layout {
		radius = 30,
		origin = raylib.Vector2{cast(f32)width / 2, cast(f32)height / 2}, // center the grid
	}

	map_radius: i32 = 4 // small map radius

	m := make(hex.HexMap)
	defer delete(m)

	for q in -map_radius ..= map_radius {
		for r in -map_radius ..= map_radius {
			s := -q - r
			if (q >= -map_radius && q <= map_radius) &&
			   (r >= -map_radius && r <= map_radius) &&
			   (s >= -map_radius && s <= map_radius) {
				hp := new(hex.Hex)
				hp^.q = q
				hp^.r = r
				// selected defaults to false
				hex.set_hex(&m, hp)
			}
		}
	}

	for !raylib.WindowShouldClose() {
		raylib.BeginDrawing()
		defer raylib.EndDrawing()
		raylib.ClearBackground(raylib.RAYWHITE)

		render.draw_hex_map(layout, m)
	}
}
