package hexes

import "core:hash"
import "core:strings"
import "core:unicode/utf8"
import "vendor:raylib"

init_ui :: proc() {
	game.ui_context = {
		prev_elements = make([dynamic]UI_Element),
		cur_elements = make([dynamic]UI_Element),
		layout_context_stack = make([dynamic]Layout_Context),
		new_hot_layer = -1,
		ui_style = {
			font = get_font(),
			font_size = 16,
			spacing = 2,
			padding = 4,
			text_color = WHITE,
			color = BLACK,
			hover_color = GRAY,
			active_color = LIGHTGRAY,
			disabled_color = LIGHTGRAY,
		},
	}
	game.ui_context.cursor_blink = create_timer(0.5)
	game.ui_context.cursor_visible = true
}

shutdown_ui :: proc() {
	ctx := &game.ui_context

	delete(ctx.cur_elements)
	delete(ctx.prev_elements)
	delete(ctx.layout_context_stack)
	delete(ctx.queued_chars)
	destroy_timer(ctx.cursor_blink)
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
	ctx.is_backspace_down = is_key_pressed(BACKSPACE) || is_key_pressed_repeat(BACKSPACE)
	ctx.is_enter_press = is_key_pressed(ENTER)

	for {
		char := get_char_pressed()
		if char == 0 do break
		append(&ctx.queued_chars, char)
	}

	if timer_is_expired(ctx.cursor_blink) {
		ctx.cursor_visible = !ctx.cursor_visible
		reset_timer(ctx.cursor_blink)
	}
}

end_ui :: proc() {
	ctx := &game.ui_context

	ctx.hot_id = ctx.new_hot_id

	if !ctx.is_left_hold do ctx.active_id = 0
	if ctx.is_left_press && ctx.new_hot_id != ctx.focused_id do ctx.focused_id = 0

	clear_dynamic_array(&ctx.queued_chars)
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
	style := ctx.ui_style
	rect := layout_rect(rect)

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

	is_hovered := ui_is_hovered(rect, element.layer)

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
	style := &game.ui_context.ui_style

	draw_rectangle(rect, color)

	if text != "" {
		text_size := measure_text_ex(get_font(), text, style.font_size, style.spacing)
		pos: Vec2 = {
			rect.x + rect.width / 2 - text_size.x / 2,
			rect.y + rect.height / 2 - text_size.y / 2,
		}
		draw_text(get_font(), text, pos, style.font_size, style.spacing, style.text_color)
	}
}

begin_window :: proc(
	rect: Rectangle,
	label: string,
	padding: f32 = game.ui_context.ui_style.padding,
) -> Window_State {
	ctx := &game.ui_context
	rect := layout_rect(rect)

	layout := Layout_Context {
		window_rect     = rect,
		cursor_start_x  = rect.x + padding,
		cursor          = {rect.x + padding, rect.y + padding},
		available_width = rect.width - padding * 2,
		padding         = padding,
	}

	append(&ctx.layout_context_stack, layout)

	return ui_window(rect, label)
}

layout_offset :: proc(pos: Vec2) -> Vec2 {
	layout := get_current_layout()
	if layout == nil do return pos
	return pos + Vec2{layout.window_rect.x, layout.window_rect.y}
}

layout_rect :: proc(rect: Rectangle) -> Rectangle {
	layout := get_current_layout()
	if layout == nil do return rect
	return Rectangle {
		x = layout.window_rect.x + rect.x,
		y = layout.window_rect.y + rect.y,
		width = rect.width,
		height = rect.height,
	}
}

layout_row :: proc(height: f32) {
	layout := get_current_layout()
	if layout == nil do return

	layout.cursor.y += layout.row_height
	layout.cursor.x = layout.cursor_start_x
	layout.row_height = height
}

// returns a window-relative rect for the next column slot
layout_col :: proc(width: f32) -> Rectangle {
	layout := get_current_layout()
	if layout == nil do return {}
	start_x := layout.cursor.x

	computed_width: f32
	if width < 0 {
		computed_width = (layout.cursor_start_x + layout.available_width) - start_x
	} else if width < 1.0 {
		computed_width = layout.available_width * width
	} else {
		computed_width = width
	}

	layout.cursor.x += computed_width

	return Rectangle {
		x = start_x - layout.window_rect.x,
		y = layout.cursor.y - layout.window_rect.y,
		width = computed_width,
		height = layout.row_height,
	}
}

ui_label :: proc(rect: Rectangle, text: string, font_size: f32, spacing: f32, color: ColorEx) {
	r := layout_rect(rect)
	draw_text(get_font(), text, {r.x, r.y}, font_size, spacing, color)
}

ui_textbox :: proc(rect: Rectangle, label: string, builder: ^strings.Builder) -> Textbox_State {
	ctx := &game.ui_context
	style := ctx.ui_style
	rect := layout_rect(rect)

	element := UI_Element {
		rect  = rect,
		id    = ui_id(label),
		layer = UI_LAYER_PANEL,
	}

	append(&ctx.cur_elements, element)

	draw_rectangle(rect, WHITE)

	is_hovered := ui_is_hovered(rect, element.layer)

	if is_hovered && element.layer >= ctx.new_hot_layer {
		ctx.new_hot_layer = element.layer
		ctx.new_hot_id = element.id
	}

	if ctx.hot_id == element.id && ctx.is_left_press {
		ctx.active_id = element.id
		ctx.focused_id = element.id
		ctx.cursor_visible = true
	}

	if ctx.focused_id == element.id {
		for char in ctx.queued_chars {
			strings.write_rune(builder, char)
		}
		if ctx.is_backspace_down && len(builder.buf) > 0 {
			string := strings.to_string(builder^)
			_, rune_size := utf8.decode_last_rune_in_string(string)
			resize(&builder.buf, len(builder.buf) - rune_size)
		}
	}

	text := strings.to_string(builder^)
	visible_text := get_visible_text(rect, text)

	if visible_text != "" {
		pos := Vec2{rect.x + style.padding, rect.y + rect.height / 2 - style.font_size / 2}
		draw_text(get_font(), visible_text, pos, style.font_size, style.spacing, BLACK)
	}

	if ctx.focused_id == element.id {
		if ctx.cursor_visible {
			text_size := measure_text_ex(get_font(), visible_text, style.font_size, style.spacing)
			cursor_x := rect.x + style.padding + text_size.x + 2
			draw_line({cursor_x, rect.y + 2}, {cursor_x, rect.y + rect.height - 2}, 1, BLACK)
		}
		if ctx.is_enter_press do return .Submitted
	}

	if ctx.active_id == element.id {
		if ctx.is_left_release do return .Focused
		return .Hovered
	}

	if is_hovered {
		return .Hovered
	}

	return .Normal
}

@(private = "file")
get_visible_text :: proc(rect: Rectangle, text: string) -> string {
	ctx := &game.ui_context
	style := ctx.ui_style

	available_width := rect.width - style.padding * 2

	result_str := text

	for {
		text_width := measure_text_ex(get_font(), result_str, style.font_size, style.spacing)
		if text_width.x > available_width {
			_, rune_size := utf8.decode_rune_in_string(result_str)
			result_str = result_str[rune_size:]
		} else {
			return result_str
		}
	}
}

@(private = "file")
ui_is_hovered :: proc(rect: Rectangle, layer: UI_Layer) -> bool {
	ctx := &game.ui_context

	if !check_collision_point_rect(ctx.mouse_pos, rect) do return false

	for elem in ctx.prev_elements {
		if elem.layer > layer && check_collision_point_rect(ctx.mouse_pos, elem.rect) do return false
	}

	return true
}

@(private = "file")
get_current_layout :: proc() -> ^Layout_Context {
	ctx := &game.ui_context
	if len(ctx.layout_context_stack) == 0 do return nil
	return &ctx.layout_context_stack[len(ctx.layout_context_stack) - 1]
}

end_window :: proc() {
	ctx := &game.ui_context

	pop(&ctx.layout_context_stack)
}

get_window_rect :: proc() -> Rectangle {
	layout := get_current_layout()
	if layout == nil do return {}
	return layout.window_rect
}

@(private = "file")
ui_window :: proc(rect: Rectangle, label: string, texture: Texture_2D = {}) -> Window_State {
	ctx := &game.ui_context
	style := ctx.ui_style

	element := UI_Element {
		id    = ui_id(label),
		rect  = rect,
		layer = UI_LAYER_PANEL,
	}

	append(&ctx.cur_elements, element)

	draw_rectangle(rect, style.color)

	if check_collision_point_rect(ctx.mouse_pos, rect) do return .Hovered

	return .Normal
}

UI_Style :: struct {
	font:           Font,
	font_size:      f32,
	spacing:        f32,
	padding:        f32,
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

Window_State :: enum {
	Normal,
	Hovered,
}

Textbox_State :: enum {
	Normal,
	Hovered,
	Focused,
	Disabled,
	Submitted,
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

Layout_Context :: struct {
	// window's rect
	window_rect:     Rectangle,
	// current position the draw cursor
	cursor:          Vec2,
	// X pos of the start of each row (rect.x + padding)
	cursor_start_x:  f32,
	// height of the current row
	row_height:      f32,
	// total width available in a row (not including padding)
	available_width: f32,
	// padding on edges of rect
	padding:         f32,
}

UI_Context :: struct {
	// ui element hovered during the last frame; 0 = None
	hot_id:               UI_Id,
	// ui element being held down during the last frame; 0 = None
	active_id:            UI_Id,
	// ui element currently focused (will take any keyboard inputs)
	focused_id:           UI_Id,
	// ui element hovered during *this* frame
	new_hot_id:           UI_Id,
	// elements from last frame (built from cur_elements
	// at the end of the frame)
	prev_elements:        [dynamic]UI_Element,
	// elements during this frame (committed to prev_elements
	// at the end of drawing)
	cur_elements:         [dynamic]UI_Element,
	// highest layer the mouse is over this frame. -1 = None
	new_hot_layer:        int,
	mouse_pos:            Vec2,
	is_left_press:        bool,
	is_left_release:      bool,
	is_left_hold:         bool,
	is_right_press:       bool,
	is_right_release:     bool,
	is_right_hold:        bool,
	is_backspace_down:    bool,
	is_enter_press:       bool,

	// runes typed this frame
	queued_chars:         [dynamic]rune,
	// textbox cursor blink timer and visibility bool
	cursor_blink:         ^Timer,
	cursor_visible:       bool,

	// default styling for when no texture is provided
	ui_style:             UI_Style,
	// stack of layout_context structs for windows
	layout_context_stack: [dynamic]Layout_Context,
}
