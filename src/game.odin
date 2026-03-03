package hexes

import mu "vendor:microui"

game: ^Game

init_game :: proc() {
	game = new(Game)

	game.ui_context = init_mu()
}

shutdown_game :: proc() {
	for pawn in game.level.pawns {
		if pawn == nil do continue
		if pawn.accessible_hex_ids != nil do delete(pawn.accessible_hex_ids)
		if pawn.visible_hex_ids != nil do delete(pawn.visible_hex_ids)
		free(pawn)
	}
	delete(game.level.pawns)

	if game.players[0].visible_hex_ids != nil {
		delete(game.players[0].visible_hex_ids)
	}

	if game.players[0].cached_path != nil do delete(game.players[0].cached_path)

	if game.encounter_controller.initiative_order != nil {
		delete(game.encounter_controller.initiative_order)
	}

	delete(game.level.hex_map.hmap)

	free(game.ui_context.style.font)
	free(game.ui_context.style)
	free(game.ui_context)

	free(game)
}

run_game :: proc() {
	prepare_encounter()

	for !window_should_close() {
		compose_ui(context.temp_allocator)
		update_one_frame(get_frame_time())
		draw()

		free_all(context.temp_allocator)
	}
}

draw :: proc() {
	begin_drawing()
	clear_background(WHITE)


	{
		begin_2d_mode(game.camera)

		draw_hex_map()

		end_2d_mode()
	}

	draw_ui()

	end_drawing()
}

compose_ui :: proc(allocator := context.temp_allocator) {
	game.level.ui_elements = make([dynamic]Rectangle, allocator)

	end_btn_rect := Rectangle {
		x      = WINDOW_WIDTH - 92,
		y      = 5,
		width  = 82,
		height = 22,
	}

	append(&game.level.ui_elements, end_btn_rect)
}

draw_ui :: proc() {
	ui_context := game.ui_context

	mu.begin(ui_context)

	// update_end_turn_button(ui_context)
	update_hovered_hex_window(ui_context)

	mu.end(ui_context)

	draw_microui_commands(ui_context)

	end_btn_rect := Rectangle {
		x      = WINDOW_WIDTH - 92,
		y      = 5,
		width  = 82,
		height = 22,
	}

	if im_button(end_btn_rect, "End Turn") {
		game.encounter_controller.end_turn_requested = true
	}
}

update_one_frame :: proc(dt: f32) {
	update_camera(dt)
	update_timers(dt)
	update_mu_inputs(game.ui_context)
	update_player_hover(dt)
	update_encounter_controller(dt)
}

Game :: struct {
	level:                Level,
	players:              [2]Player,
	camera:               Camera,
	ui_context:           ^mu.Context,
	encounter_controller: Encounter_State_Controller,
	timer_system:         Timer_System,
}
