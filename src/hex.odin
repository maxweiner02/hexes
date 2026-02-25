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

// Vec2 point at index 0 is the bottom-right corner and goes clockwise
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
	font := get_raylib_font_from_ctx(game.ui_context)
	center := axial_to_pixel(layout, h)
	coords := fmt.tprintf("%d,%d,%d", h.q, h.r, -h.q - h.r)

	pos := measure_text_ex(font, coords, 10, 1)
	x := f32(center.x) - pos.x / 2
	y := f32(center.y) - 6

	draw_text(font, coords, {x, y}, 10, 1, color)
}

@(private = "file")
draw_hex :: proc(hex: ^Hex) {
	layout := game.level.hex_map.layout

	hex_id := pack_hex(hex^)

	center := axial_to_pixel(layout, hex)

	draw_poly(center, 6, f32(layout.radius), 30, TERRAIN_DATA[hex.terrain].texture)

	if hex.structure == .Fence {
		draw_poly(center, 4, 20, 45, BROWN)
	}

	// determine visibility
	is_visible := false
	for visible_id in game.player.visible_hex_ids {
		if hex_id == visible_id {
			is_visible = true
			break
		}
	}

	if !is_visible {
		if .Discovered in game.level.hex_map.hmap[hex_id].state {
			draw_poly(center, 6, f32(layout.radius), 30, DISCOVERED_GREY)
		} else {
			draw_poly(center, 6, f32(layout.radius), 30, BLACK)
		}
	}

	if game.player.is_selecting && game.player.select_hex_id == hex_id {
		// right now don't color selected, but eventually put something here
	}

	if game.player.is_hovering && game.player.hover_hex_id == hex_id {
		draw_poly(center, 6, f32(layout.radius), 30, SELECTED_WHITE)
	}

	if game.player.select_pawn != nil {
		for reachable_id in game.player.select_pawn.accessible_hex_ids {
			if hex_id == reachable_id {
				draw_poly(center, 6, f32(layout.radius), 30, REACHABLE_WHITE)
			}
		}
	}

	draw_poly_lines(center, 6, f32(layout.radius), 30, BLACK)
}

@(private = "file")
draw_path :: proc(hex_ids: []Hex_Id) {
	if len(hex_ids) < 2 do return

	layout := game.level.hex_map.layout

	// Catmull-Rom splines don't pass through the first and last control points,
	// so we duplicate them to ensure the curve reaches the endpoints
	point_count := len(hex_ids) + 2
	path_centers := make([]Vec2, point_count, context.temp_allocator)

	for i in 0 ..< len(hex_ids) {
		hex := game.level.hex_map.hmap[hex_ids[i]]
		center := axial_to_pixel(layout, &hex)
		// need to make sure we leave the 0th index open for the duplicated center
		path_centers[i + 1] = center
	}

	// duplicate first and last points to make sure the line goes through them
	path_centers[0] = path_centers[1]
	path_centers[point_count - 1] = path_centers[point_count - 2]

	draw_spline(path_centers, point_count, 6, game.player.select_pawn.texture)
}

@(private = "file")
draw_outline :: proc(segments: [][2]Vec2, thickness: f32, color: ColorEx) {
	for seg in segments {
		draw_line(seg[0], seg[1], thickness, color)
	}
}

draw_hex_map :: proc() {
	for _, &hex in game.level.hex_map.hmap {
		draw_hex(&hex)
	}

	for pawn in game.player.pawns {
		draw_pawn(pawn)
	}

	if game.player.select_pawn != nil {
		// this is the outline for the accessible hexes
		outline := get_poly_outline(
			game.player.select_pawn.accessible_hex_ids,
			game.player.select_pawn.position_hex_id,
			context.temp_allocator,
		)
		draw_outline(outline, 3, game.player.select_pawn.texture)
	}

	// this is the path using A* to the hovered hex
	if game.player.is_hovering &&
	   game.player.cached_path != nil &&
	   game.turn_state_ctrl.state == .PlayerTurn {
		draw_path(game.player.cached_path)
	}

	// LoS Testing
	// {
	// 	cur_center := axial_to_pixel(
	// 		game.level.hex_map.layout,
	// 		&game.level.hex_map.hmap[game.player.position_hex_id],
	// 	)
	// 	hover_center := axial_to_pixel(
	// 		game.level.hex_map.layout,
	// 		&game.level.hex_map.hmap[game.player.hover_hex_id],
	// 	)
	// 	draw_line(cur_center, hover_center, 2, BLUE)
	// }
}

// Take a pointer to a hex and update its properties based on its terrain and structure
resolve_properties :: proc(hex: ^Hex) {
	terrain_properties := TERRAIN_DATA[hex.terrain].properties
	structure_properties := STRUCTURE_DATA[hex.structure].properties

	// use a bit_set 'intersect' operation
	hex.properties = terrain_properties & structure_properties
}

Hex_Id :: i64

Hex_Map :: struct {
	hmap:   map[Hex_Id]Hex,
	layout: Hex_Layout,
}

Hex_Layout :: struct {
	radius: int,
	origin: Vec2,
}

Hex :: struct {
	q, r:       int,
	terrain:    Terrain_Type,
	structure:  Structure_Type,
	properties: Properties,
	state:      State,
}

Terrain :: struct {
	movement_cost: int,
	properties:    Properties,
	texture:       ColorEx,
}

Terrain_Type :: enum {
	Lava,
	Grass,
	Desert,
	Wall,
}

TERRAIN_DATA := [Terrain_Type]Terrain {
	.Lava = {movement_cost = 1, properties = {.Transparent}, texture = RED},
	.Grass = {movement_cost = 1, properties = {.Passable, .Transparent}, texture = GREEN},
	.Desert = {movement_cost = 2, properties = {.Passable, .Transparent}, texture = YELLOW},
	.Wall = {movement_cost = 1, properties = {}, texture = GRAY},
}

Structure :: struct {
	movement_cost: int,
	properties:    Properties,
	texture:       ColorEx,
}

Structure_Type :: enum {
	None,
	Fence,
}

STRUCTURE_DATA := [Structure_Type]Structure {
	.None = {movement_cost = 0, properties = {.Transparent, .Passable}, texture = TRANSPARENT},
	.Fence = {movement_cost = 1, properties = {.Transparent}, texture = BROWN},
}

Properties :: bit_set[Property_Flags;u32]

// Property Flags are dependent on terrain/structure/etc and need to be recalculated often
Property_Flags :: enum {
	Passable,
	Transparent,
}

State :: bit_set[State_Flags;u32]

// State Flags are attatched to the hex and is not affected by terrain/structure/etc
State_Flags :: enum {
	Discovered,
}
