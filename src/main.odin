package hexes

import "core:log"

main :: proc() {
	context.logger = log.create_console_logger()

	init_window(WINDOW_WIDTH, WINDOW_HEIGHT, GAME_TITLE)
	defer {
		shutdown_game()
		close_window()
	}

	set_target_fps(FPS)

	{
		init_game()
		init_test_map()
		init_player()

		free_all(context.temp_allocator)
	}

	run_game_loop()
}
