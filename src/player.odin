package hexes


init_player :: proc() {
	game.player = {
		accessible_hex_ids = nil,
		location_hex_id    = pack_axial(0, 0),
		hover_hex_id       = 0,
		select_hex_id      = 0,
		is_hovering        = false,
		is_selecting       = false,
		movement_range     = 8,
	}

	game.player.accessible_hex_ids = get_accessible_hexes(
		pack_axial(0, 0),
		game.player.movement_range,
	)
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
}

@(private = "file")
update_player_selection :: proc(dt: f32) {
	if !is_mouse_button_released(LEFT_CLICK) do return

	game.player.is_selecting = game.player.is_hovering

	if game.player.is_selecting {
		game.player.select_hex_id = game.player.hover_hex_id
	}
}

update_player_movement :: proc(dt: f32) {
	if !is_mouse_button_released(RIGHT_CLICK) do return

	if game.player.is_hovering {
		can_move: bool
		for id in game.player.accessible_hex_ids {
			if id == game.player.hover_hex_id {
				can_move = true
				break
			}
		}

		if can_move {
			game.player.location_hex_id = game.player.hover_hex_id

			if game.player.accessible_hex_ids != nil {
				delete(game.player.accessible_hex_ids)
			}

			game.player.accessible_hex_ids = get_accessible_hexes(
				game.player.location_hex_id,
				game.player.movement_range,
			)
		}
	}
}

Player :: struct {
	accessible_hex_ids:        []Hex_Id,
	location_hex_id:           Hex_Id,
	hover_hex_id:              Hex_Id,
	select_hex_id:             Hex_Id,
	is_hovering, is_selecting: bool,
	movement_range:            int,
}
