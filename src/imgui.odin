package hexes

// im_button :: proc(
// 	rect: Rectangle,
// 	label: string,
// 	color := GRAY,
// 	text_color := BLACK,
// 	font_size: f32 = 16,
// 	spacing: f32 = 1,
// ) -> bool {
// 	mouse_over_button := check_collision_point_rect(get_mouse_pos(), rect)

// 	draw_rectangle_rounded(rect, mouse_over_button ? LIGHTGRAY : color)

// 	text_size := measure_text_ex(get_font_default(), label, font_size, spacing)

// 	draw_text(
// 		get_font_default(),
// 		label,
// 		{rect.x + rect.width / 2 - text_size.x / 2, rect.y + rect.height / 2 - text_size.y / 2},
// 		font_size,
// 		spacing,
// 		text_color,
// 	)

// 	return mouse_over_button && is_mouse_button_released(.LEFT)
// }
