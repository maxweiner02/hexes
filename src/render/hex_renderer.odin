package render

import "core:fmt"
import "core:strings"
import "src:hex"
import "vendor:raylib"

draw_coordinates :: proc(layout: hex.Layout, h: hex.Hex, color: raylib.Color) {
	center := hex.axial_to_pixel(layout, h)
	coords := fmt.tprintf("%d,%d,%d", h.q, h.r, -h.q - h.r)
	text := strings.clone_to_cstring(coords)
	defer delete(text)

	text_width := raylib.MeasureText(text, 12)
	x := i32(center.x) - text_width / 2
	y := i32(center.y) - 6

	raylib.DrawText(text, x, y, 10, color)
}

draw_hex :: proc(layout: hex.Layout, h: hex.Hex, color: raylib.Color) {
	corners := hex.hex_corners(layout, h)
	center := hex.axial_to_pixel(layout, h)
	for i in 0 ..< 6 {
		// fill in background
		if raylib.CheckCollisionPointPoly(raylib.GetMousePosition(), &corners[0], 6) {
			raylib.DrawPoly(center, 6, cast(f32)layout.radius, 30, raylib.BLUE)
		} else {
			color := h.selected ? raylib.GREEN : raylib.YELLOW
			raylib.DrawPoly(center, 6, cast(f32)layout.radius, 30, color)
		}

		// draw borders
		j := (i + 1) % 6
		raylib.DrawLineV(corners[i], corners[j], color)
	}
	draw_coordinates(layout, h, color)
}

// Iterate over the HexMap and draw each stored hex at its coordinates.
draw_hex_map :: proc(layout: hex.Layout, m: hex.HexMap) {
	for _, hp in m {
		draw_hex(layout, hp^, raylib.BLACK)
	}
}
