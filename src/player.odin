package hexes

init_player :: proc() {
	game.players[0] = {}
	game.players[0].visible_hex_ids = resolve_player_visible_hexes(0)
}

// returns the merged visible hex ids for all pawns belonging to player_idx
resolve_player_visible_hexes :: proc(player_idx: int, allocator := context.allocator) -> []Hex_Id {
	player_pawns := make([dynamic]^Pawn, context.temp_allocator)
	for pawn in game.level.pawns {
		if pawn.player_index == player_idx {
			append(&player_pawns, pawn)
		}
	}
	return resolve_all_visible_hexes(player_pawns[:], allocator)
}

update_player :: proc(dt: f32) {
	update_player_selection(dt)
}

update_player_hover :: proc(dt: f32) {
	mouse_pos := get_mouse_pos()
	mouse_world := screen_to_world_2d(mouse_pos, game.camera)

	player := &game.players[0]

	hex, ok := get_hex_for_vec(&game.level.hex_map, mouse_world)

	player.is_hovering = ok && !ui_consuming_mouse()

	if ok {
		player.hover_hex_id = pack_hex(hex^)
	}

	// recalculate cached path only when the hovered hex changes
	hover_changed := player.hover_hex_id != player.prev_hover_hex_id
	player.prev_hover_hex_id = player.hover_hex_id

	_, is_input_phase := game.encounter_controller.state.(Input_Phase)

	if hover_changed && player.is_hovering && is_input_phase {
		if player.cached_path != nil {
			delete(player.cached_path)
			player.cached_path = nil
		}

		// only calculate path if the selected pawn is the current (active) pawn
		current_pawn := get_current_pawn()
		if player.select_pawn != nil && current_pawn != nil && player.select_pawn == current_pawn {
			hovering_accessible: bool
			for id in player.select_pawn.accessible_hex_ids {
				if id == player.hover_hex_id {
					hovering_accessible = true
					break
				}
			}

			if hovering_accessible {
				player.cached_path = get_path_to_hex(
					player.select_pawn.position_hex_id,
					player.hover_hex_id,
					player.select_pawn.cur_movement_range,
				)
			}
		}
	} else if !player.is_hovering && player.cached_path != nil && is_input_phase {
		delete(player.cached_path)
		player.cached_path = nil
	}
}

@(private = "file")
update_player_selection :: proc(dt: f32) {
	_, is_input_phase := game.encounter_controller.state.(Input_Phase)
	if !is_input_phase do return
	if !is_mouse_button_released(LEFT_CLICK) do return

	player := &game.players[0]
	player.is_selecting = player.is_hovering

	if player.is_selecting {
		player.select_hex_id = player.hover_hex_id

		pawn, ok := get_pawn_for_hex(player.select_hex_id)
		player.select_pawn = ok ? pawn : nil

		// if we select a hex without a pawn we need to clear
		// the cached path
		if !ok && player.cached_path != nil {
			delete(player.cached_path)
			player.cached_path = nil
		}
	}
}

Player :: struct {
	visible_hex_ids:           []Hex_Id,
	cached_path:               []Hex_Id,
	select_pawn:               ^Pawn,
	hover_hex_id:              Hex_Id,
	prev_hover_hex_id:         Hex_Id,
	select_hex_id:             Hex_Id,
	is_hovering, is_selecting: bool,
}
