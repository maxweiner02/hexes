package hexes

init_player :: proc() {
	game.player = {
		hover_hex_key  = 0,
		is_hovering    = false,
		select_hex_key = 0,
		is_selecting   = false,
	}
}

update_player :: proc(dt: f32) {
	mouse_pos := get_mouse_pos()

	// hovering
	{
		hex, ok := get_hex_for_vec(&game.test_map, mouse_pos)

		game.player.is_hovering = ok

		if ok {
			game.player.hover_hex_key = pack_hex(hex^)
		}
	}

	// selecting
	{
		if is_mouse_button_pressed(LEFT_CLICK) {
			hex, ok := get_hex_for_vec(&game.test_map, mouse_pos)

			game.player.is_selecting = ok

			if ok {
				game.player.select_hex_key = pack_hex(hex^)
			}
		}
	}
}

Player :: struct {
	hover_hex_key:  i64,
	is_hovering:    bool,
	select_hex_key: i64,
	is_selecting:   bool,
}
