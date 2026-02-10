package hexes


init_player :: proc() {
	game.player = {
		hover_hex_id  = 0,
		select_hex_id = 0,
		is_hovering   = false,
		is_selecting  = false,
	}
}

update_player :: proc(dt: f32) {
	update_player_hover(dt)
	update_player_selection(dt)
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

Player :: struct {
	hover_hex_id:              Hex_Id,
	select_hex_id:             Hex_Id,
	is_hovering, is_selecting: bool,
}
