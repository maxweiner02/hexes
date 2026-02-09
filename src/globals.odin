package hexes

import "core:math"

WINDOW_WIDTH :: 960
WINDOW_HEIGHT :: 720
GAME_TITLE :: "Hexes"

FPS :: 60

MAP_RADIUS :: 6
MAP_DIAMETER :: 2 * MAP_RADIUS + 1
MAP_HEX_COUNT :: MAP_DIAMETER * MAP_DIAMETER

Vec2 :: [2]f32

SQRT3_F64: f64 = math.sqrt(f64(3.0))
