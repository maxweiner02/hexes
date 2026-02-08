package hexes

import "core:fmt"
import "core:strings"
import "vendor:raylib"

draw_coordinates :: proc(layout: Layout, h: ^Hex, color: raylib.Color) {
	center := axial_to_pixel(layout, h)
	coords := fmt.tprintf("%d,%d,%d", h.q, h.r, -h.q - h.r)
	text := strings.clone_to_cstring(coords)
	defer delete(text)

	text_width := raylib.MeasureText(text, 12)
	x := i32(center.x) - text_width / 2
	y := i32(center.y) - 6

	raylib.DrawText(text, x, y, 10, color)
}

draw_hex :: proc(layout: Layout, h: ^Hex) {
	corners := hex_corners(layout, h)
	center := axial_to_pixel(layout, h)

	// draw hex fill
	color := h.hovered ? raylib.BLUE : raylib.YELLOW
	if h.selected do color = raylib.GREEN
	raylib.DrawPoly(center, 6, cast(f32)layout.radius, 30, color)

	for i in 0 ..< 6 {
		// draw borders
		j := (i + 1) % 6
		raylib.DrawLineV(corners[i], corners[j], raylib.BLACK)
	}

	// draw coord text
	draw_coordinates(layout, h, raylib.BLACK)
}

// Iterate over the HexMap and draw each stored hex at its coordinates.
draw_hex_map :: proc(m: HexMap, layout: Layout) {
	for _, &hp in m {
		draw_hex(layout, &hp)
	}
}
