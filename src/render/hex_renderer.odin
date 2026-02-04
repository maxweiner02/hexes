package render

import "core:fmt"
import "core:math"
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
	for i in 0 ..< 6 {
		j := (i + 1) % 6
		raylib.DrawLineV(corners[i], corners[j], color)
	}
	draw_coordinates(layout, h, color)
}

draw_hex_map :: proc(layout: hex.Layout, map_radius: i32) {
	for q in -map_radius ..= map_radius {
		for r in -map_radius ..= map_radius {
			s := -q - r
			if math.abs(q) <= map_radius &&
			   math.abs(r) <= map_radius &&
			   math.abs(s) <= map_radius {
				draw_hex(layout, hex.Hex{q = q, r = r}, raylib.BLACK)
			}
		}
	}
}
