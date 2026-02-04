package app

import "src:hex"
import "src:render"
import "vendor:raylib"

main :: proc() {
	width: i32 = 960
	height: i32 = 720
	raylib.InitWindow(width, height, cstring("Hex Grid (axial) - Odin + raylib"))
	defer raylib.CloseWindow()
	raylib.SetTargetFPS(60)

	// Pointy-topped axial layout
	layout := hex.Layout {
		radius = 30,
		origin = raylib.Vector2{cast(f32)width / 2, cast(f32)height / 2}, // center the grid
	}

	map_radius: i32 = 4 // small map radius

	for !raylib.WindowShouldClose() {
		raylib.BeginDrawing()
		defer raylib.EndDrawing()
		raylib.ClearBackground(raylib.RAYWHITE)

		render.draw_hex_map(layout, map_radius)
	}
}
