package hexes

import "core:fmt"
import mu "vendor:microui"

init_player :: proc() {
	pawn_one := new(Pawn)
	pawn_one^ = Pawn {
		name               = "Pawn One",
		accessible_hex_ids = nil,
		visible_hex_ids    = nil,
		location_hex_id    = pack_axial(0, 0),
		movement_range     = 4,
		sight_range        = 4,
		texture            = PINK,
	}

	pawn_two := new(Pawn)
	pawn_two^ = Pawn {
		name               = "Pawn Two",
		accessible_hex_ids = nil,
		visible_hex_ids    = nil,
		location_hex_id    = pack_axial(2, -2),
		movement_range     = 6,
		sight_range        = 6,
		texture            = PURPLE,
	}

	pawns := make([]^Pawn, 2)
	pawns[0] = pawn_one
	pawns[1] = pawn_two

	ui_context_ptr := new(mu.Context)


	game.player = {
		ui_context        = ui_context_ptr,
		pawns             = pawns,
		select_pawn       = nil,
		visible_hex_ids   = nil,
		cached_path       = nil,
		hover_hex_id      = 0,
		prev_hover_hex_id = 0,
		select_hex_id     = 0,
		is_hovering       = false,
		is_selecting      = false,
	}

	mu.init(game.player.ui_context)
	game.player.ui_context.text_width = mu.default_atlas_text_width
	game.player.ui_context.text_height = mu.default_atlas_text_height

	for pawn in game.player.pawns {
		pawn.visible_hex_ids = get_visible_hexes(pawn.location_hex_id, pawn.sight_range)
		pawn.accessible_hex_ids = get_accessible_hexes(pawn.location_hex_id, pawn.movement_range)
	}

	// since the player has vision over all pawns' vision we need to merge them
	game.player.visible_hex_ids = resolve_all_visible_hexes(game.player.pawns)
}

update_player :: proc(dt: f32) {
	update_player_hover(dt)
	update_player_selection(dt)
	update_player_movement(dt)
}

@(private = "file")
update_player_hover :: proc(dt: f32) {
	mouse_pos := get_mouse_pos()
	mouse_world := screen_to_world_2d(mouse_pos, game.camera)

	hex, ok := get_hex_for_vec(&game.level.hex_map, mouse_world)

	game.player.is_hovering = ok

	if ok {
		game.player.hover_hex_id = pack_hex(hex^)
	}

	// recalculate cached path only when the hovered hex changes
	hover_changed := game.player.hover_hex_id != game.player.prev_hover_hex_id
	game.player.prev_hover_hex_id = game.player.hover_hex_id

	if hover_changed && game.player.is_hovering {
		if game.player.cached_path != nil {
			delete(game.player.cached_path)
			game.player.cached_path = nil
		}

		// only calculate path if a pawn is selected and the hovered hex is accessible for that pawn
		if game.player.select_pawn != nil {
			hovering_accessible: bool
			for id in game.player.select_pawn.accessible_hex_ids {
				if id == game.player.hover_hex_id {
					hovering_accessible = true
					break
				}
			}

			if hovering_accessible {
				game.player.cached_path = get_path_to_hex(
					game.player.select_pawn.location_hex_id,
					game.player.hover_hex_id,
					game.player.select_pawn.movement_range,
				)
			}
		}
	} else if !game.player.is_hovering && game.player.cached_path != nil {
		delete(game.player.cached_path)
		game.player.cached_path = nil
	}
}

@(private = "file")
update_player_selection :: proc(dt: f32) {
	if !is_mouse_button_released(LEFT_CLICK) do return

	game.player.is_selecting = game.player.is_hovering

	if game.player.is_selecting {
		game.player.select_hex_id = game.player.hover_hex_id

		pawn, ok := get_pawn_for_hex(game.player.select_hex_id)

		if ok {
			game.player.select_pawn = pawn
		} else {
			game.player.select_pawn = nil
		}
	}
}

update_player_movement :: proc(dt: f32) {
	if !is_mouse_button_released(RIGHT_CLICK) do return

	if game.player.select_pawn == nil do return

	if game.player.is_hovering {
		can_move: bool
		for id in game.player.select_pawn.accessible_hex_ids {
			if id == game.player.hover_hex_id {
				can_move = true
				break
			}
		}

		if can_move {
			game.player.select_pawn.location_hex_id = game.player.hover_hex_id

			if game.player.cached_path != nil {
				delete(game.player.cached_path)
				game.player.cached_path = nil
			}

			if game.player.select_pawn.accessible_hex_ids != nil {
				delete(game.player.select_pawn.accessible_hex_ids)
			}

			if game.player.select_pawn.visible_hex_ids != nil {
				delete(game.player.select_pawn.visible_hex_ids)
			}

			game.player.select_pawn.visible_hex_ids = get_visible_hexes(
				game.player.select_pawn.location_hex_id,
				game.player.select_pawn.sight_range,
			)

			game.player.select_pawn.accessible_hex_ids = get_accessible_hexes(
				game.player.select_pawn.location_hex_id,
				game.player.select_pawn.movement_range,
			)

			if game.player.visible_hex_ids != nil {
				delete(game.player.visible_hex_ids)
			}

			game.player.visible_hex_ids = resolve_all_visible_hexes(game.player.pawns)
		}
	}
}

update_hovered_hex_window :: proc(ctx: ^mu.Context) {
	if !game.player.is_hovering do return

	// at 14 font_size, the window will be 78 px tall with 3 rows
	if mu.begin_window(
		ctx,
		"Hovered Hex",
		{WINDOW_WIDTH - (150 + 5), WINDOW_HEIGHT - (78 + 5), 0, 0},
		{.NO_CLOSE, .NO_INTERACT, .NO_RESIZE, .NO_SCROLL, .NO_TITLE, .AUTO_SIZE},
	) {
		mu.layout_row(ctx, {150 - 10})

		terrain_str := fmt.tprintf(
			"Terrain - %v",
			game.level.hex_map.hmap[game.player.hover_hex_id].terrain,
		)

		mu.text(ctx, terrain_str)

		if game.level.hex_map.hmap[game.player.hover_hex_id].structure != .None {
			structure_str := fmt.tprintf(
				"Structure - %v",
				game.level.hex_map.hmap[game.player.hover_hex_id].structure,
			)

			mu.text(ctx, structure_str)
		}

		pawn, ok := get_pawn_for_hex(game.player.hover_hex_id)
		if ok {
			pawn_str := fmt.tprintf("Unit - %v", pawn.name)

			mu.text(ctx, pawn_str)
		}

		mu.end_window(ctx)
	}
}

Player :: struct {
	ui_context:                ^mu.Context,
	pawns:                     []^Pawn,
	visible_hex_ids:           []Hex_Id,
	cached_path:               []Hex_Id,
	select_pawn:               ^Pawn,
	hover_hex_id:              Hex_Id,
	prev_hover_hex_id:         Hex_Id,
	select_hex_id:             Hex_Id,
	is_hovering, is_selecting: bool,
}
