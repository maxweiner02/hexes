package hexes

import "core:c"
import "vendor:raylib"

init_window :: raylib.InitWindow

close_window :: raylib.CloseWindow

set_target_fps :: raylib.SetTargetFPS

get_frame_time :: raylib.GetFrameTime

window_should_close :: raylib.WindowShouldClose

begin_drawing :: raylib.BeginDrawing

end_drawing :: raylib.EndDrawing

clear_background :: raylib.ClearBackground

ColorEx :: raylib.Color

draw_poly :: proc(center: Vec2, sides: int, radius: f32, rotation: f32, color: ColorEx) {
	raylib.DrawPoly(center, c.int(sides), radius, rotation, color)
}

draw_poly_lines :: proc(center: Vec2, sides: int, radius: f32, rotation: f32, color: ColorEx) {
	raylib.DrawPolyLines(center, c.int(sides), radius, rotation, color)
}

check_collision_point_poly :: raylib.CheckCollisionPointPoly

get_mouse_pos :: raylib.GetMousePosition

is_mouse_button_pressed :: raylib.IsMouseButtonPressed

is_key_down :: raylib.IsKeyDown

LEFT_CLICK :: raylib.MouseButton.LEFT
RIGHT_CLICK :: raylib.MouseButton.RIGHT

SHIFT_KEY :: raylib.KeyboardKey.LEFT_SHIFT

BLACK :: raylib.BLACK
WHITE :: raylib.WHITE
YELLOW :: raylib.YELLOW
BLUE :: raylib.BLUE
GREEN :: raylib.GREEN
