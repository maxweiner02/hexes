package hexes

import "core:math/rand"

init_level :: proc() {
	test_map := Hex_Map {
		hmap = make(map[i64]Hex),
		layout = {radius = 30, origin = {0, 0}},
	}

	game.level = {
		name    = "Test Level",
		hex_map = test_map,
	}

	all_terrains := [?]Terrain_Type{.Lava, .Grass, .Desert, .Wall}


	for q in -MAP_RADIUS ..= MAP_RADIUS {
		(q >= -MAP_RADIUS && q <= MAP_RADIUS) or_continue

		for r in -MAP_RADIUS ..= MAP_RADIUS {
			(r >= -MAP_RADIUS && r <= MAP_RADIUS) or_continue

			s := -q - r

			(s >= -MAP_RADIUS && s <= MAP_RADIUS) or_continue

			new_hex := Hex {
				q         = q,
				r         = r,
				terrain   = rand.choice(all_terrains[:]),
				structure = .None,
			}

			// for now make sure the origin is not impassable so we don't spawn in a wall
			if new_hex.q == 0 && new_hex.r == 0 do new_hex.terrain = .Grass
			if new_hex.q == 2 && new_hex.r == -2 do new_hex.terrain = .Grass
			if new_hex.q == -2 && new_hex.r == 2 do new_hex.terrain = .Grass

			if new_hex.q == 1 && new_hex.r == 1 {
				new_hex.terrain = .Grass
				new_hex.structure = .Fence
			}

			resolve_properties(&new_hex)
			add_hex(&game.level.hex_map, new_hex)
		}
	}

	compute_map_bounds()

	// create pawns
	{
		pawn_one := new(Pawn)
		pawn_one^ = Pawn {
			name               = "Pawn One",
			player_index       = 0,
			initiative         = 2,
			accessible_hex_ids = nil,
			visible_hex_ids    = nil,
			position_hex_id    = pack_axial(0, 0),
			visual_position    = axial_to_pixel(
				game.level.hex_map.layout,
				&game.level.hex_map.hmap[pack_axial(0, 0)],
			),
			visual_rotation    = 0,
			movement_range     = 4,
			cur_movement_range = 4,
			sight_range        = 4,
			movement_state     = {},
			texture            = PINK,
		}

		pawn_two := new(Pawn)
		pawn_two^ = Pawn {
			name               = "Pawn Two",
			player_index       = 0,
			initiative         = 4,
			accessible_hex_ids = nil,
			visible_hex_ids    = nil,
			position_hex_id    = pack_axial(2, -2),
			visual_position    = axial_to_pixel(
				game.level.hex_map.layout,
				&game.level.hex_map.hmap[pack_axial(2, -2)],
			),
			visual_rotation    = 0,
			movement_range     = 6,
			cur_movement_range = 6,
			sight_range        = 6,
			movement_state     = {},
			texture            = PURPLE,
		}

		pawn_three := new(Pawn)
		pawn_three^ = Pawn {
			name               = "Pawn Three",
			player_index       = 1,
			initiative         = 6,
			accessible_hex_ids = nil,
			visible_hex_ids    = nil,
			position_hex_id    = pack_axial(-2, 2),
			visual_position    = axial_to_pixel(
				game.level.hex_map.layout,
				&game.level.hex_map.hmap[pack_axial(-2, 2)],
			),
			visual_rotation    = 0,
			movement_range     = 4,
			cur_movement_range = 4,
			sight_range        = 4,
			movement_state     = {},
			texture            = BLUE,
		}

		pawns := make([]^Pawn, 3)
		pawns[0] = pawn_one
		pawns[1] = pawn_two
		pawns[2] = pawn_three

		game.level.pawns = pawns

		for pawn in game.level.pawns {
			pawn.visible_hex_ids = get_visible_hexes(pawn.position_hex_id, pawn.sight_range)
			pawn.accessible_hex_ids = get_accessible_hexes(
				pawn.position_hex_id,
				pawn.cur_movement_range,
			)
		}
	}
}

compute_map_bounds :: proc() {
	hmap := game.level.hex_map.hmap
	layout := game.level.hex_map.layout

	// get the hexes at the polar edges of q and r (x,y)
	min_q_hex, _ := hmap[pack_axial(-MAP_RADIUS, 0)]
	max_q_hex, _ := hmap[pack_axial(MAP_RADIUS, 0)]
	min_r_hex, _ := hmap[pack_axial(0, -MAP_RADIUS)]
	max_r_hex, _ := hmap[pack_axial(0, MAP_RADIUS)]

	// get their pixel coords
	min_q := axial_to_pixel(layout, &min_q_hex).x - cast(f32)layout.radius
	max_q := axial_to_pixel(layout, &max_q_hex).x + cast(f32)layout.radius
	min_r := axial_to_pixel(layout, &min_r_hex).y - cast(f32)layout.radius
	max_r := axial_to_pixel(layout, &max_r_hex).y + cast(f32)layout.radius

	game.level.bounds_q = {min_q, max_q}
	game.level.bounds_r = {min_r, max_r}
}

Level :: struct {
	name:        string,
	pawns:       []^Pawn,
	hex_map:     Hex_Map,
	bounds_q:    Vec2,
	bounds_r:    Vec2,
	ui_elements: [dynamic]Rectangle,
}
