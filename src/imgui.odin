package hexes

import "core:hash"

init_ui :: proc() {
	game.ui_context = {
		prev_elements = make([dynamic]UI_Element),
		cur_elements = make([dynamic]UI_Element),
		new_hot_layer = -1,
		default_style = {
			font = get_font_default(),
			font_size = 16,
			spacing = 2,
			text_color = WHITE,
			color = BLACK,
			hover_color = GRAY,
			active_color = LIGHTGRAY,
			disabled_color = LIGHTGRAY,
		},
	}
}

shutdown_ui :: proc() {
	ctx := &game.ui_context

	delete(ctx.cur_elements)
	delete(ctx.prev_elements)
}

begin_ui :: proc() {
	ctx := &game.ui_context

	ctx.prev_elements, ctx.cur_elements = ctx.cur_elements, ctx.prev_elements
	clear(&ctx.cur_elements)
	ctx.new_hot_id = 0
	ctx.new_hot_layer = -1

	ctx.mouse_pos = get_mouse_pos()
	ctx.is_left_press = is_mouse_button_pressed(LEFT_CLICK)
	ctx.is_left_release = is_mouse_button_released(LEFT_CLICK)
	ctx.is_left_hold = is_mouse_button_down(LEFT_CLICK)
	ctx.is_right_press = is_mouse_button_pressed(RIGHT_CLICK)
	ctx.is_right_release = is_mouse_button_released(RIGHT_CLICK)
	ctx.is_right_hold = is_mouse_button_down(RIGHT_CLICK)
}

end_ui :: proc() {
	ctx := &game.ui_context

	ctx.hot_id = ctx.new_hot_id

	if !ctx.is_left_hold do ctx.active_id = 0
}

@(private = "file")
ui_id :: proc(label: string) -> UI_Id {
	return UI_Id(hash.fnv64a(transmute([]byte)label))
}

ui_consuming_mouse :: proc() -> bool {
	ctx := &game.ui_context
	for elem in ctx.prev_elements {
		if check_collision_point_rect(ctx.mouse_pos, elem.rect) do return true
	}
	return false
}

ui_button :: proc(rect: Rectangle, label: string, params: Button_Params) -> Button_State {
	ctx := &game.ui_context
	style := ctx.default_style

	element := UI_Element {
		id    = ui_id(label),
		layer = params.layer,
		rect  = rect,
	}

	append(&ctx.cur_elements, element)

	if params.disabled {
		draw_button(rect, params.text, style.disabled_color)
		return .Disabled
	}

	is_hovered := check_collision_point_rect(ctx.mouse_pos, rect)

	if is_hovered {
		check_layers: for elem in ctx.prev_elements {
			if elem.layer > element.layer && check_collision_point_rect(ctx.mouse_pos, elem.rect) {
				is_hovered = false
				break check_layers
			}
		}
	}

	if is_hovered && element.layer >= ctx.new_hot_layer {
		ctx.new_hot_layer = element.layer
		ctx.new_hot_id = element.id
	}

	if ctx.hot_id == element.id && ctx.is_left_press {
		ctx.active_id = element.id
	}

	if ctx.active_id == element.id {
		draw_button(rect, params.text, style.active_color)
		if ctx.is_left_release do return .Pressed
		return .Hovered
	}

	if is_hovered {
		draw_button(rect, params.text, style.hover_color)
		return .Hovered
	}

	draw_button(rect, params.text, style.color)
	return .Normal
}

@(private = "file")
draw_button :: proc(rect: Rectangle, text: string, color: ColorEx) {
	style := &game.ui_context.default_style

	draw_rectangle(rect, color)

	if text != "" {
		text_size := measure_text_ex(style.font, text, style.font_size, style.spacing)
		pos: Vec2 = {
			rect.x + rect.width / 2 - text_size.x / 2,
			rect.y + rect.height / 2 - text_size.y / 2,
		}
		draw_text(style.font, text, pos, style.font_size, style.spacing, style.text_color)
	}
}

Default_Style :: struct {
	font:           Font,
	font_size:      f32,
	spacing:        f32,
	text_color:     ColorEx,
	color:          ColorEx,
	hover_color:    ColorEx,
	active_color:   ColorEx,
	disabled_color: ColorEx,
}

Button_Params :: struct {
	text:             string,
	layer:            UI_Layer,
	normal_texture:   Texture_2D,
	hovered_texture:  Texture_2D,
	pressed_texture:  Texture_2D,
	disabled_texture: Texture_2D,
	disabled:         bool,
}

Button_State :: enum {
	Normal,
	Hovered,
	Pressed,
	Disabled,
}

ui_window :: proc(rect: Rectangle, label: string) -> Window_State {
	ctx := &game.ui_context
	style := ctx.default_style

	element := UI_Element {
		id    = ui_id(label),
		rect  = rect,
		layer = 0,
	}

	append(&ctx.cur_elements, element)

	draw_rectangle(rect, style.color)

	if check_collision_point_rect(ctx.mouse_pos, rect) do return .Hovered

	return .Normal
}

Window_State :: enum {
	Normal,
	Hovered,
}

UI_Id :: u64

UI_Layer :: int

UI_LAYER_BASE: UI_Layer : 0
UI_LAYER_PANEL: UI_Layer : 10
UI_LAYER_POPUP: UI_Layer : 20

UI_Element :: struct {
	id:    UI_Id,
	rect:  Rectangle,
	layer: UI_Layer,
}

UI_Context :: struct {
	// ui element hovered during the last frame; 0 = None
	hot_id:           UI_Id,
	// ui element being held down during the last frame; 0 = None
	active_id:        UI_Id,
	// ui element hovered during *this* frame
	new_hot_id:       UI_Id,
	// elements from last frame (built from cur_elements
	// at the end of the frame)
	prev_elements:    [dynamic]UI_Element,
	// elements during this frame (committed to prev_elements
	// at the end of drawing)
	cur_elements:     [dynamic]UI_Element,
	// highest layer the mouse is over this frame. -1 = None
	new_hot_layer:    int,
	mouse_pos:        Vec2,
	is_left_press:    bool,
	is_left_release:  bool,
	is_left_hold:     bool,
	is_right_press:   bool,
	is_right_release: bool,
	is_right_hold:    bool,

	// default styling for when no texture is provided
	default_style:    Default_Style,
}
