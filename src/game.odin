package hexes

import mu "vendor:microui"

game: ^Game

init_game :: proc() {
	game = new(Game)
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

	free(game)
}

run_game :: proc() {
	prepare_encounter()

	for !window_should_close() {
		begin_ui()
		update_one_frame(get_frame_time())
		draw()
		end_ui()

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

draw_ui :: proc() {
	end_btn_rect := Rectangle {
		x      = WINDOW_WIDTH - 105,
		y      = 5,
		width  = 100,
		height = 26,
	}

	if ui_button(
		   end_btn_rect,
		   "end_turn_btn",
		   Button_Params{text = "End Turn", layer = UI_LAYER_PANEL},
	   ) ==
	   .Pressed {
		game.encounter_controller.end_turn_requested = true
	}

	draw_messages()
}

update_one_frame :: proc(dt: f32) {
	update_camera(dt)
	update_timers(dt)
	update_player_hover(dt)
	update_encounter_controller(dt)
	update_messages(dt)
}

Game :: struct {
	level:                Level,
	players:              [2]Player,
	camera:               Camera,
	ui_context:           UI_Context,
	encounter_controller: Encounter_State_Controller,
	timer_system:         Timer_System,
	message_system:       Message_System,
}
