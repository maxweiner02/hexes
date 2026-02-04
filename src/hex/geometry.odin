package hex

import "core:math"
import "vendor:raylib"

SQRT3_F64: f64 = math.sqrt(cast(f64)3.0)

axial_to_pixel :: proc(layout: Layout, h: Hex) -> raylib.Vector2 {
	// x = (√3 * q + √3/2 * r) * radius
	x :=
		(cast(f32)SQRT3_F64 * cast(f32)h.q + cast(f32)(SQRT3_F64 / 2) * cast(f32)h.r) *
		cast(f32)layout.radius
	// y = (0 * q + 3/2 * r) * radius
	y := (0 * cast(f32)h.q + 1.5 * cast(f32)h.r) * cast(f32)layout.radius

	return {x + layout.origin.x, y + layout.origin.y}
}

hex_corner_offset :: proc(layout: Layout, corner: int) -> raylib.Vector2 {
	// angle = 2π * (corner + 0.5) / 6
	radians := (2 * math.PI) * ((cast(f64)corner + 0.5) / 6)
	cx := cast(f32)layout.radius * cast(f32)math.cos(radians)
	cy := cast(f32)layout.radius * cast(f32)math.sin(radians)
	return {cx, cy}
}

hex_corners :: proc(layout: Layout, h: Hex) -> [6]raylib.Vector2 {
	center := axial_to_pixel(layout, h)
	result: [6]raylib.Vector2
	for i in 0 ..< 6 {
		offset := hex_corner_offset(layout, i)
		result[i] = {center.x + offset.x, center.y + offset.y}
	}
	return result
}
