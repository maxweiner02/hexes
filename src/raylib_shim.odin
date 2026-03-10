package hexes

import "core:math"
import "core:strings"
import "vendor:raylib"

init_window :: raylib.InitWindow

close_window :: raylib.CloseWindow

get_screen_height :: raylib.GetScreenHeight

get_screen_width :: raylib.GetScreenWidth

set_target_fps :: raylib.SetTargetFPS

get_frame_time :: raylib.GetFrameTime

window_should_close :: raylib.WindowShouldClose

begin_2d_mode :: raylib.BeginMode2D

end_2d_mode :: raylib.EndMode2D

begin_drawing :: raylib.BeginDrawing

end_drawing :: raylib.EndDrawing

clear_background :: raylib.ClearBackground

get_font_default :: raylib.GetFontDefault

vec2_length :: raylib.Vector2Length

vec2_to_deg :: proc(dir: Vec2) -> f32 {
	radians := math.atan2_f32(dir.y, dir.x)
	return radians * raylib.RAD2DEG
}

draw_poly :: proc(center: Vec2, sides: int, radius: f32, rotation: f32, color: ColorEx) {
	raylib.DrawPoly(center, i32(sides), radius, rotation, color)
}

draw_poly_lines :: proc(center: Vec2, sides: int, radius: f32, rotation: f32, color: ColorEx) {
	raylib.DrawPolyLines(center, i32(sides), radius, rotation, color)
}

draw_line :: proc(start: Vec2, end: Vec2, thickness: f32, color: ColorEx) {
	raylib.DrawLineEx(start, end, thickness, color)
}

draw_spline :: proc(points: []Vec2, count: int, thickness: f32, color: ColorEx) {
	raylib.DrawSplineCatmullRom(raw_data(points), i32(count), thickness, color)
}

// points is a 4-length array of Vec2s that represent N-1 ..= N+2 points of the desired path;
// seg_frac is a f32 between 0.0 ..= 1.0 that represents the progress along the desired path
get_spline :: proc(points: [4]Vec2, seg_frac: f32) -> Vec2 {
	return raylib.GetSplinePointCatmullRom(points[0], points[1], points[2], points[3], seg_frac)
}

draw_rectangle :: proc(rect: Rectangle, color: ColorEx) {
	raylib.DrawRectangleRec(rect, color)
}

draw_rectangle_rounded :: proc(rect: Rectangle, color: ColorEx) {
	raylib.DrawRectangleRounded(rect, 0.2, 0, color)
}

measure_text :: proc(text: string, fontSize: i32, allocator := context.temp_allocator) -> i32 {
	ctext := strings.clone_to_cstring(text, allocator)
	return raylib.MeasureText(ctext, fontSize)
}

measure_text_ex :: proc(
	font: Font,
	text: string,
	fontSize: f32,
	spacing: f32,
	allocator := context.temp_allocator,
) -> Vec2 {
	ctext := strings.clone_to_cstring(text, allocator)
	return raylib.MeasureTextEx(font, ctext, fontSize, spacing)
}

draw_text :: proc(
	font: Font,
	text: string,
	pos: Vec2,
	fontSize: f32,
	spacing: f32,
	color: ColorEx,
	allocator := context.temp_allocator,
) {
	ctext := strings.clone_to_cstring(text, allocator)
	raylib.DrawTextEx(font, ctext, pos, fontSize, spacing, color)
}

Font :: raylib.Font

Rectangle :: raylib.Rectangle

check_collision_point_poly :: raylib.CheckCollisionPointPoly
check_collision_point_rect :: raylib.CheckCollisionPointRec

get_mouse_pos :: raylib.GetMousePosition
get_wheel_scroll :: raylib.GetMouseWheelMove
get_char_pressed :: raylib.GetCharPressed

screen_to_world_2d :: raylib.GetScreenToWorld2D

is_mouse_button_pressed :: raylib.IsMouseButtonPressed
is_mouse_button_released :: raylib.IsMouseButtonReleased
is_mouse_button_down :: raylib.IsMouseButtonDown

LEFT_CLICK :: raylib.MouseButton.LEFT
RIGHT_CLICK :: raylib.MouseButton.RIGHT

is_key_down :: raylib.IsKeyDown
is_key_pressed_repeat :: raylib.IsKeyPressedRepeat

UP :: raylib.KeyboardKey.UP
DOWN :: raylib.KeyboardKey.DOWN
LEFT :: raylib.KeyboardKey.LEFT
RIGHT :: raylib.KeyboardKey.RIGHT
BACKSPACE :: raylib.KeyboardKey.BACKSPACE

BLACK :: raylib.BLACK
WHITE :: raylib.WHITE
YELLOW :: raylib.YELLOW
BLUE :: raylib.BLUE
GREEN :: raylib.GREEN
RED :: raylib.RED
PURPLE :: raylib.PURPLE
GRAY :: raylib.GRAY
LIGHTGRAY :: raylib.LIGHTGRAY
BROWN :: raylib.BROWN
PINK :: raylib.PINK

TRANSPARENT :: ColorEx{0, 0, 0, 0}
SELECTED_WHITE :: ColorEx{245, 245, 245, 165}
REACHABLE_WHITE :: ColorEx{255, 255, 255, 80}
DISCOVERED_GREY :: ColorEx{80, 80, 80, 200}

ColorEx :: raylib.Color

Camera :: raylib.Camera2D

Texture_2D :: raylib.Texture2D

// raygui shims

im_button :: proc(rect: Rectangle, str: string) -> bool {
	cstr := strings.clone_to_cstring(str, context.temp_allocator)
	return raylib.GuiButton(rect, cstr)
}
