package hexes


init_player :: proc() {
	game.player = {
		hover_hex_key  = 0,
		select_hex_idx = {},
		is_hovering    = false,
		is_selecting   = false,
	}

	ba_init(&game.player.select_hex_idx, MAP_HEX_COUNT)
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
				idx := get_hex_idx(hex.q, hex.r)
				if is_key_down(SHIFT_KEY) {
					is_selected := ba_get(&game.player.select_hex_idx, uint(idx))
					if is_selected {
						ba_unset(&game.player.select_hex_idx, uint(idx))
					} else {
						ba_set(&game.player.select_hex_idx, uint(idx), true)
					}
				} else {
					ba_clear(&game.player.select_hex_idx)
					ba_set(&game.player.select_hex_idx, uint(idx), true)
				}
			} else {
				ba_clear(&game.player.select_hex_idx)
			}
		}
	}
}

Player :: struct {
	hover_hex_key:             i64,
	select_hex_idx:            Bit_Array,
	is_hovering, is_selecting: bool,
}
