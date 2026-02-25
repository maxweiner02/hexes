package hexes

import "core:fmt"
import mu "vendor:microui"

init_mu :: proc() -> ^mu.Context {
	font := new(Font)
	font^ = get_font_default()

	style := new(mu.Style)
	style^ = mu.default_style

	style.font = mu.Font(font)

	ctx := new(mu.Context)

	mu.init(ctx)

	ctx.style = style
	ctx.text_width = mu_text_width
	ctx.text_height = mu_text_height

	return ctx
}

mu_text_width :: proc(font: mu.Font, str: string) -> i32 {
	rl_font := get_raylib_font_from_mu(font)
	return cast(i32)measure_text_ex(rl_font, str, cast(f32)rl_font.baseSize, 1).x
}

mu_text_height :: proc(font: mu.Font) -> i32 {
	rl_font := get_raylib_font_from_mu(font)
	return rl_font.baseSize
}

draw_microui_commands :: proc(ctx: ^mu.Context) {
	cmd: ^mu.Command = nil

	for mu.next_command(ctx, &cmd) {
		#partial switch &var in cmd.variant {
		case ^mu.Command_Rect:
			{
				rect := Rectangle {
					cast(f32)var.rect.x,
					cast(f32)var.rect.y,
					cast(f32)var.rect.w,
					cast(f32)var.rect.h,
				}

				draw_rectangle(rect, transmute(ColorEx)var.color)
			}
		case ^mu.Command_Text:
			{
				color := transmute(ColorEx)var.color

				vec2d := Vec2{cast(f32)var.pos.x, cast(f32)var.pos.y}

				font := (get_raylib_font_from_mu(var.font))

				draw_text(font, var.str, vec2d, cast(f32)font.baseSize, 1, color)
			}
		}
	}
}

update_mu_inputs :: proc(ctx: ^mu.Context) {
	mouse_pos := get_mouse_pos()
	mu.input_mouse_move(ctx, i32(mouse_pos.x), i32(mouse_pos.y))
	if is_mouse_button_pressed(
		LEFT_CLICK,
	) {mu.input_mouse_down(ctx, i32(mouse_pos.x), i32(mouse_pos.y), .LEFT)
	}
	if is_mouse_button_released(LEFT_CLICK) {
		mu.input_mouse_up(ctx, i32(mouse_pos.x), i32(mouse_pos.y), .LEFT)
	}
}

update_end_turn_button :: proc(ctx: ^mu.Context) {
	win_width: i32 = 110
	win_height: i32 = 40
	win_x: i32 = WINDOW_WIDTH - win_width - 5
	win_y: i32 = 5

	if mu.begin_window(
		ctx,
		"end_turn",
		{win_x, win_y, win_width, win_height},
		{.NO_CLOSE, .NO_SCROLL, .NO_TITLE, .AUTO_SIZE, .NO_FRAME},
	) {
		mu.layout_row(ctx, {win_width - 16})
		if .SUBMIT in mu.button(ctx, "End Turn") {
			game.turn_state_ctrl.state = .EndTurn
		}
		mu.end_window(ctx)
	}
}

update_hovered_hex_window :: proc(ctx: ^mu.Context) {
	if !game.player.is_hovering do return

	// at 14 font_size, the window will be 78 px tall with 3 rows
	if mu.begin_window(
		ctx,
		"hovered_hex",
		{WINDOW_WIDTH - (150 + 5), WINDOW_HEIGHT - (78 + 5), 0, 0},
		{.NO_CLOSE, .NO_INTERACT, .NO_RESIZE, .NO_SCROLL, .NO_TITLE, .AUTO_SIZE},
	) {
		mu.layout_row(ctx, {150 - 10})

		terrain_str := fmt.tprintf(
			"Terrain - %v | Cost - %v",
			game.level.hex_map.hmap[game.player.hover_hex_id].terrain,
			TERRAIN_DATA[game.level.hex_map.hmap[game.player.hover_hex_id].terrain].movement_cost,
		)

		mu.text(ctx, terrain_str)

		if game.level.hex_map.hmap[game.player.hover_hex_id].structure != .None {
			structure_str := fmt.tprintf(
				"Structure - %v",
				game.level.hex_map.hmap[game.player.hover_hex_id].structure,
			)

			mu.text(ctx, structure_str)
		}

		pawn, ok := get_pawn_for_hex(game.player.hover_hex_id)
		if ok {
			pawn_str := fmt.tprintf("Unit - %v", pawn.name)
			mu.text(ctx, pawn_str)

			movement_str := fmt.tprintf("Movement - %v", pawn.cur_movement_range)
			mu.text(ctx, movement_str)
		}

		mu.end_window(ctx)
	}
}

get_raylib_font_from_mu :: proc(f: mu.Font) -> Font {
	if f == nil {
		fmt.println("[FALLBACK]font ptr is null")
		return get_font_default()
	}
	return (cast(^Font)f)^
}

get_raylib_font_from_ctx :: proc(ctx: ^mu.Context) -> Font {
	return get_raylib_font_from_mu(ctx.style.font)
}
