package hexes

init_player :: proc() {
	pawn_one := new(Pawn)
	pawn_one^ = Pawn {
		name               = "Pawn One",
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

	pawns := make([]^Pawn, 2)
	pawns[0] = pawn_one
	pawns[1] = pawn_two

	game.player = {
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

	for pawn in game.player.pawns {
		pawn.visible_hex_ids = get_visible_hexes(pawn.position_hex_id, pawn.sight_range)
		pawn.accessible_hex_ids = get_accessible_hexes(
			pawn.position_hex_id,
			pawn.cur_movement_range,
		)
	}

	// since the player has vision over all pawns' vision we need to merge them
	game.player.visible_hex_ids = resolve_all_visible_hexes(game.player.pawns)
}

update_player :: proc(dt: f32) {
	update_mu_inputs(game.ui_context)
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

	if hover_changed && game.player.is_hovering && game.turn_state_ctrl.state == .PlayerTurn {
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
					game.player.select_pawn.position_hex_id,
					game.player.hover_hex_id,
					game.player.select_pawn.cur_movement_range,
				)
			}
		}
	} else if !game.player.is_hovering &&
	   game.player.cached_path != nil &&
	   game.turn_state_ctrl.state == .PlayerTurn {
		delete(game.player.cached_path)
		game.player.cached_path = nil
	}
}

@(private = "file")
update_player_selection :: proc(dt: f32) {
	if game.turn_state_ctrl.state != .PlayerTurn do return
	if !is_mouse_button_released(LEFT_CLICK) do return

	game.player.is_selecting = game.player.is_hovering

	if game.player.is_selecting {
		game.player.select_hex_id = game.player.hover_hex_id

		pawn, ok := get_pawn_for_hex(game.player.select_hex_id)
		game.player.pending_action = Select {
			pawn = ok ? pawn : nil,
		}
	}
}

update_player_movement :: proc(dt: f32) {
	if game.turn_state_ctrl.state != .PlayerTurn do return
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
			game.player.pending_action = Move {
				pawn = game.player.select_pawn,
				dest = game.player.hover_hex_id,
			}
		}
	}
}

Player :: struct {
	pawns:                     []^Pawn,
	visible_hex_ids:           []Hex_Id,
	cached_path:               []Hex_Id,
	select_pawn:               ^Pawn,
	hover_hex_id:              Hex_Id,
	prev_hover_hex_id:         Hex_Id,
	select_hex_id:             Hex_Id,
	is_hovering, is_selecting: bool,
	pending_action:            Player_Action,
}

Player_Action :: union {
	Move,
	Select,
}

Select :: struct {
	pawn: ^Pawn,
}

Move :: struct {
	pawn: ^Pawn,
	dest: Hex_Id,
}
