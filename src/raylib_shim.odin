package hexes

import "core:c"
import "core:strings"
import "vendor:raylib"

init_window :: raylib.InitWindow

close_window :: raylib.CloseWindow

set_target_fps :: raylib.SetTargetFPS

get_frame_time :: raylib.GetFrameTime

window_should_close :: raylib.WindowShouldClose

begin_2d_mode :: raylib.BeginMode2D

end_2d_mode :: raylib.EndMode2D

begin_drawing :: raylib.BeginDrawing

end_drawing :: raylib.EndDrawing

clear_background :: raylib.ClearBackground

draw_poly :: proc(center: Vec2, sides: int, radius: f32, rotation: f32, color: ColorEx) {
	raylib.DrawPoly(center, c.int(sides), radius, rotation, color)
}

draw_poly_lines :: proc(center: Vec2, sides: int, radius: f32, rotation: f32, color: ColorEx) {
	raylib.DrawPolyLines(center, c.int(sides), radius, rotation, color)
}

measure_text :: proc(
	text: string,
	fontSize: f32,
	spacing: f32,
	allocator := context.temp_allocator,
) -> Vec2 {
	ctext := strings.clone_to_cstring(text, allocator)
	return raylib.MeasureTextEx(raylib.GetFontDefault(), ctext, fontSize, spacing)
}

draw_text :: proc(
	text: string,
	pos: Vec2,
	fontSize: f32,
	spacing: f32,
	color: ColorEx,
	allocator := context.temp_allocator,
) {
	ctext := strings.clone_to_cstring(text, allocator)
	raylib.DrawTextEx(raylib.GetFontDefault(), ctext, pos, fontSize, spacing, color)
}

check_collision_point_poly :: raylib.CheckCollisionPointPoly

get_mouse_pos :: raylib.GetMousePosition
get_wheel_scroll :: raylib.GetMouseWheelMove

screen_to_world_2d :: raylib.GetScreenToWorld2D

is_mouse_button_pressed :: raylib.IsMouseButtonPressed
is_mouse_button_released :: raylib.IsMouseButtonReleased

LEFT_CLICK :: raylib.MouseButton.LEFT
RIGHT_CLICK :: raylib.MouseButton.RIGHT

is_key_down :: raylib.IsKeyDown

UP :: raylib.KeyboardKey.UP
DOWN :: raylib.KeyboardKey.DOWN
LEFT :: raylib.KeyboardKey.LEFT
RIGHT :: raylib.KeyboardKey.RIGHT

BLACK :: raylib.BLACK
WHITE :: raylib.WHITE
YELLOW :: raylib.YELLOW
BLUE :: raylib.BLUE
GREEN :: raylib.GREEN

SELECTED_WHITE :: ColorEx{245, 245, 245, 165}

ColorEx :: raylib.Color

Camera :: raylib.Camera2D
