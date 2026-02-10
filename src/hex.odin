package hexes

import "core:fmt"
import "core:math"

// q + r + s = 0
s_of :: proc(h: Hex) -> int {
	return -h.q - h.r
}

add_hex :: proc(hmap: ^Hex_Map, hex: Hex) {
	hmap^.hmap[pack_hex(hex)] = hex
}

pack_hex :: proc(hex: Hex) -> Hex_Id {
	return pack_axial(hex.q, hex.r)
}

pack_axial :: proc(q: int, r: int) -> Hex_Id {
	return (i64(q) << 32) | i64(u32(r))
}

@(private = "file")
get_hex :: proc(m: ^Hex_Map, q: int, r: int) -> (^Hex, bool) {
	h, ok := &m^.hmap[pack_axial(q, r)]
	return h, ok
}

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

@(private = "file")
draw_coordinates :: proc(layout: Hex_Layout, h: ^Hex, color: ColorEx) {
	center := axial_to_pixel(layout, h)
	coords := fmt.tprintf("%d,%d,%d", h.q, h.r, -h.q - h.r)

	pos := measure_text(coords, 10, 1)
	x := f32(center.x) - pos.x / 2
	y := f32(center.y) - 6

	draw_text(coords, {x, y}, 10, 1, color)
}

@(private = "file")
draw_hex :: proc(hex: ^Hex) {
	layout := game.level.hex_map.layout

	color: ColorEx

	switch hex.terrain {
	case Terrain_Type.Lava:
		color = RED
	case Terrain_Type.Grass:
		color = GREEN
	case Terrain_Type.Desert:
		color = YELLOW
	case Terrain_Type.Snow:
		color = WHITE
	}

	hex_id := pack_hex(hex^)

	if game.player.is_selecting && game.player.select_hex_id == hex_id {
		color = BLUE
	}

	center := axial_to_pixel(layout, hex)

	draw_poly(center, 6, f32(layout.radius), 30, color)

	if game.player.is_hovering && game.player.hover_hex_id == hex_id {
		draw_poly(center, 6, f32(layout.radius), 30, SELECTED_WHITE)
	}

	for reachable_id in game.player.accessible_hex_ids {
		if hex_id == reachable_id {
			draw_poly(center, 6, f32(layout.radius), 30, REACHABLE_WHITE)
		}
	}

	draw_poly_lines(center, 6, f32(layout.radius), 30, BLACK)

	if hex_id == game.player.location_hex_id {
		draw_poly(center, 4, 10, 0, PURPLE)
	} else {
		draw_coordinates(layout, hex, BLACK)
	}

}

draw_hex_map :: proc() {
	for _, &hex in game.level.hex_map.hmap {
		draw_hex(&hex)
	}
}

Hex_Id :: i64

Terrain_Type :: enum int {
	Lava,
	Grass,
	Desert,
	Snow,
}

Terrain :: struct {
	name:     string,
	passable: bool,
}

terrain_of :: proc(t: Terrain_Type) -> Terrain {
	return game.level.terrains[cast(int)t]
}

Hex :: struct {
	q, r:    int,
	terrain: Terrain_Type,
}

Hex_Layout :: struct {
	radius: int,
	origin: Vec2,
}

Hex_Map :: struct {
	hmap:   map[Hex_Id]Hex,
	layout: Hex_Layout,
}
