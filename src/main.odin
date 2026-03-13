package hexes

import "core:fmt"
import "core:log"
import "core:mem"

main :: proc() {
	context.logger = log.create_console_logger()

	// help my poor soul find memory leaks
	when ODIN_DEBUG {
		track: mem.Tracking_Allocator
		mem.tracking_allocator_init(&track, context.allocator)
		context.allocator = mem.tracking_allocator(&track)

		defer {
			if len(track.allocation_map) > 0 {
				fmt.eprintf("=== %v allocations not freed: ===\n", len(track.allocation_map))
				for _, entry in track.allocation_map {
					fmt.eprintf("- %v bytes @ %v\n", entry.size, entry.location)
				}
			}
			mem.tracking_allocator_destroy(&track)
		}
	}

	init_window(WINDOW_WIDTH, WINDOW_HEIGHT, GAME_TITLE)
	defer {
		shutdown_message_system()
		shutdown_ui()
		unload_assets()
		shutdown_game()
		close_window()
	}

	set_target_fps(FPS)

	{
		init_game()
		load_assets()
		init_ui()
		init_level()
		init_camera()
		init_player()
		init_encounter_controller()
		init_timer_system()

		free_all(context.temp_allocator)
	}

	run_game()
}
