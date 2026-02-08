package hexes

import "core:fmt"
import "core:math"
import "core:strings"
import "vendor:raylib"

// q + r + s = 0
s_of :: proc(h: Hex) -> int {
	return -h.q - h.r
}

add_hex :: proc(hmap: ^Hex_Map, hex: Hex) {
	hmap^.hmap[pack_hex(hex)] = hex
}

pack_hex :: proc(hex: Hex) -> i64 {
	return pack_axial(hex.q, hex.r)
}

@(private = "file")
pack_axial :: proc(q: int, r: int) -> i64 {
	return (i64(q) << 32) | i64(u32(r))
}

@(private = "file")
unpack_axial :: proc(key: i64) -> (q: i32, r: i32) {
	return i32(key >> 32), i32(key)
}

@(private = "file")
set_hex :: proc(m: ^Hex_Map, h: Hex) {
	m^.hmap[pack_hex(h)] = h
}

@(private = "file")
delete_hex :: proc(m: ^Hex_Map, h: ^Hex) {
	delete_key(&m^.hmap, pack_hex(h^))
}

@(private = "file")
has_hex :: proc(m: ^Hex_Map, q: int, r: int) -> bool {
	_, ok := m^.hmap[pack_axial(q, r)]
	return ok
}

@(private = "file")
get_hex :: proc(m: ^Hex_Map, q: int, r: int) -> (^Hex, bool) {
	h, ok := &m^.hmap[pack_axial(q, r)]
	return h, ok
}

// --- Geometry (consolidated from geometry.odin) ---

@(private = "file")
axial_to_pixel :: proc(layout: Hex_Layout, h: ^Hex) -> Vec2 {
	// x = (√3 * q + √3/2 * r) * radius
	x :=
		(cast(f32)SQRT3_F64 * cast(f32)h.q + cast(f32)(SQRT3_F64 / 2) * cast(f32)h.r) *
		cast(f32)layout.radius
	// y = (0 * q + 3/2 * r) * radius
	y := (0 * cast(f32)h.q + 1.5 * cast(f32)h.r) * cast(f32)layout.radius

	return {x + layout.origin.x, y + layout.origin.y}
}

@(private = "file")
hex_corner_offset :: proc(layout: Hex_Layout, corner: int) -> Vec2 {
	// angle = 2π * (corner + 0.5) / 6
	radians := (2 * math.PI) * ((cast(f64)corner + 0.5) / 6)
	cx := cast(f32)layout.radius * cast(f32)math.cos(radians)
	cy := cast(f32)layout.radius * cast(f32)math.sin(radians)
	return {cx, cy}
}

@(private = "file")
hex_corners :: proc(layout: Hex_Layout, h: ^Hex) -> [6]Vec2 {
	center := axial_to_pixel(layout, h)
	result: [6]Vec2
	for i in 0 ..< 6 {
		offset := hex_corner_offset(layout, i)
		result[i] = {center.x + offset.x, center.y + offset.y}
	}
	return result
}


get_hex_for_vec :: proc(hmap: ^Hex_Map, pos: Vec2) -> (^Hex, bool) {
	for _, &hex in hmap.hmap {
		corners := hex_corners(hmap.layout, &hex)

		check_collision_point_poly(pos, &corners[0], 6) or_continue

		return &hex, true
	}

	return nil, false
}

draw_coordinates :: proc(layout: Hex_Layout, h: ^Hex, color: raylib.Color) {
	center := axial_to_pixel(layout, h)
	coords := fmt.tprintf("%d,%d,%d", h.q, h.r, -h.q - h.r)
	text := strings.clone_to_cstring(coords)
	defer delete(text)

	text_width := raylib.MeasureText(text, 12)
	x := i32(center.x) - text_width / 2
	y := i32(center.y) - 6

	raylib.DrawText(text, x, y, 10, color)
}

draw_hex :: proc(hex: ^Hex) {
	layout := game.test_map.layout

	color := YELLOW

	if game.player.is_hovering && game.player.hover_hex_key == pack_hex(hex^) {
		color = BLUE
	}

	if game.player.is_selecting && game.player.select_hex_key == pack_hex(hex^) {
		color = GREEN
	}

	center := axial_to_pixel(layout, hex)

	draw_poly(center, 6, f32(layout.radius), 30, color)
	draw_poly_lines(center, 6, f32(layout.radius), 30, BLACK)

	draw_coordinates(layout, hex, raylib.BLACK)
}

draw_hex_map :: proc() {
	for _, &hex in game.test_map.hmap {
		draw_hex(&hex)
	}
}

Hex :: struct {
	q, r:              int,
	selected, hovered: bool,
}

Hex_Layout :: struct {
	origin: raylib.Vector2,
	radius: i32,
}

Hex_Map :: struct {
	hmap:   map[i64]Hex,
	layout: Hex_Layout,
}
