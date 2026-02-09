package hexes


game: ^Game

init_game :: proc() {
	game = new(Game)

	game^ = {}
}

init_test_map :: proc() {
	game.test_map = {
		hmap = make(map[i64]Hex),
		layout = {radius = 30, origin = {WINDOW_WIDTH / 2, WINDOW_HEIGHT / 2}},
	}

	for q in -MAP_RADIUS ..= MAP_RADIUS {
		(q >= -MAP_RADIUS && q <= MAP_RADIUS) or_continue

		for r in -MAP_RADIUS ..= MAP_RADIUS {
			(r >= -MAP_RADIUS && r <= MAP_RADIUS) or_continue

			s := -q - r

			(s >= -MAP_RADIUS && s <= MAP_RADIUS) or_continue

			add_hex(&game.test_map, Hex{q = q, r = r})
		}
	}
}

shutdown_game :: proc() {
	ba_destroy(&game.player.select_hex_idx)
	delete(game.test_map.hmap)

	free(game)
}

run_game_loop :: proc() {
	for !window_should_close() {
		update_one_frame(get_frame_time())
		draw()

		free_all(context.temp_allocator)
	}
}

update_one_frame :: proc(dt: f32) {
	update_player(dt)
}

draw :: proc() {
	begin_drawing()
	clear_background(WHITE)

	draw_hex_map()

	end_drawing()
}

Game :: struct {
	test_map: Hex_Map,
	player:   Player,
}
