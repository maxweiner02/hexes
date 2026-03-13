package hexes

import "core:fmt"

draw_hex_info :: proc() {
	INFO_FONT_SIZE :: 12
	INFO_SPACING :: 1
	INFO_ROW_HEIGHT :: 20
	INFO_PADDING :: 6
	INFO_WINDOW_MARGIN :: 4
	INFO_WINDOW_WIDTH :: 250

	if !game.players[0].is_hovering do return

	hex := game.level.hex_map.hmap[game.players[0].hover_hex_id]
	pawn, has_pawn := get_pawn_for_hex(game.players[0].hover_hex_id)

	// in order for window to show must be hovering a hex so terrain will
	// always be present
	row_count := 1
	if hex.structure != .None do row_count += 1
	if has_pawn do row_count += 1
	window_height := f32(INFO_PADDING + row_count * INFO_ROW_HEIGHT)

	begin_window(
		Rectangle {
			x = WINDOW_WIDTH - INFO_WINDOW_WIDTH - INFO_WINDOW_MARGIN,
			y = f32(WINDOW_HEIGHT) - window_height - INFO_WINDOW_MARGIN,
			width = INFO_WINDOW_WIDTH,
			height = window_height,
		},
		"hex_info_panel",
		INFO_PADDING,
	)

	layout_row(INFO_ROW_HEIGHT)
	r := layout_col(-1)
	terrain_str := fmt.tprintf(
		"Terrain - %v | Cost - %v",
		hex.terrain,
		TERRAIN_DATA[hex.terrain].movement_cost,
	)
	draw_text(get_font(), terrain_str, {r.x, r.y}, INFO_FONT_SIZE, INFO_SPACING, WHITE)

	if hex.structure != .None {
		layout_row(INFO_ROW_HEIGHT)
		r = layout_col(-1)
		structure_str := fmt.tprintf("Structure - %v", hex.structure)
		draw_text(get_font(), structure_str, {r.x, r.y}, INFO_FONT_SIZE, INFO_SPACING, WHITE)
	}

	if has_pawn {
		layout_row(INFO_ROW_HEIGHT)
		r = layout_col(0.5)
		draw_text(
			get_font(),
			fmt.tprintf("Unit - %v", pawn.name),
			{r.x, r.y},
			INFO_FONT_SIZE,
			INFO_SPACING,
			WHITE,
		)
		r = layout_col(0.5)
		draw_text(
			get_font(),
			fmt.tprintf("Movement - %v", pawn.cur_movement_range),
			{r.x, r.y},
			INFO_FONT_SIZE,
			INFO_SPACING,
			WHITE,
		)
	}

	end_window()
}

draw_end_turn :: proc() {
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
}
