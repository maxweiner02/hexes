package hexes

update_turn :: proc(ctrl: ^Turn_State_Controller, dt: f32) {
	switch ctrl.state {
	case .StartEncounter:
		ctrl.state = .PlayerTurn
	case .PlayerTurn:
		if game.player.pending_action != nil {
			ctrl.state = .PlayerInput
		}
	case .PlayerInput:
		ctrl.state = .ResolveInput
	case .ResolveInput:
		switch action in game.player.pending_action {
		case Move:
			{
				if !action.pawn.movement_state.is_moving {
					if action.pawn.movement_state.move_path != nil do delete(action.pawn.movement_state.move_path)
					action.pawn.movement_state.move_path = game.player.cached_path
					action.pawn.movement_state.move_idx = 0
					action.pawn.movement_state.is_moving = true
				}

				finished_moving := move_along_path(action.pawn, MOVE_SPEED, dt)
				if finished_moving {
					action.pawn.movement_state.is_moving = false
					action.pawn.movement_state.move_path = nil
					action.pawn.visual_rotation = 0
					resolve_player_action()
					ctrl.state = .PlayerTurn
				}
			}
		case Select:
			resolve_player_action()
			ctrl.state = .PlayerTurn
		}
	case .EnemyTurn:
		// TODO - for now go straight to playerTurn
		ctrl.state = .PlayerTurn
	case .EnemyInput:
	// TODO - oh god
	case .EndTurn:
		ctrl.turn_num += 1
		for pawn in game.player.pawns {
			pawn.cur_movement_range = pawn.movement_range
			if pawn.accessible_hex_ids != nil do delete(pawn.accessible_hex_ids)
			pawn.accessible_hex_ids = get_accessible_hexes(
				pawn.position_hex_id,
				pawn.cur_movement_range,
			)
		}
		ctrl.state = .PlayerTurn
	case .EndEncounter:
	// TODO - probably change scenes to select next lvl
	}
}

@(private = "file")
resolve_player_action :: proc() {
	defer game.player.pending_action = nil

	switch action in game.player.pending_action {
	case Move:
		path_cost := 0
		for id in game.player.cached_path[1:] {
			hex := game.level.hex_map.hmap[id]
			path_cost += TERRAIN_DATA[hex.terrain].movement_cost
		}
		action.pawn.cur_movement_range -= path_cost
		action.pawn.position_hex_id = action.dest

		if game.player.cached_path != nil {
			delete(game.player.cached_path)
			game.player.cached_path = nil
		}
		if action.pawn.accessible_hex_ids != nil do delete(action.pawn.accessible_hex_ids)
		if action.pawn.visible_hex_ids != nil do delete(action.pawn.visible_hex_ids)

		action.pawn.visible_hex_ids = get_visible_hexes(
			action.pawn.position_hex_id,
			action.pawn.sight_range,
		)
		action.pawn.accessible_hex_ids = get_accessible_hexes(
			action.pawn.position_hex_id,
			action.pawn.cur_movement_range,
		)

		if game.player.visible_hex_ids != nil do delete(game.player.visible_hex_ids)
		game.player.visible_hex_ids = resolve_all_visible_hexes(game.player.pawns)

	case Select:
		game.player.select_pawn = action.pawn
	}
}

Turn_State_Controller :: struct {
	state:    Turn_State,
	turn_num: int,
}

Turn_State :: enum {
	StartEncounter,
	EndEncounter,
	PlayerTurn,
	PlayerInput,
	EnemyTurn,
	EnemyInput,
	ResolveInput,
	EndTurn,
}
