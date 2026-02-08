package hexes

import "core:math"
import "vendor:raylib"

SQRT3_F64: f64 = math.sqrt(cast(f64)3.0)

axial_to_pixel :: proc(layout: Layout, h: ^Hex) -> raylib.Vector2 {
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

hex_corners :: proc(layout: Layout, h: ^Hex) -> [6]raylib.Vector2 {
	center := axial_to_pixel(layout, h)
	result: [6]raylib.Vector2
	for i in 0 ..< 6 {
		offset := hex_corner_offset(layout, i)
		result[i] = {center.x + offset.x, center.y + offset.y}
	}
	return result
}

axial_subtract :: proc(a: Hex, b: Hex) -> raylib.Vector2 {
	return {cast(f32)(a.q - b.q), cast(f32)(a.r - b.r)}
}

axial_distance :: proc(a: Hex, b: Hex) -> f32 {
	vec := axial_subtract(a, b)
	return (abs(vec.x) + abs(vec.x + vec.y) + abs(vec.y)) / 2
}

// use q,r, to determine which hex a floating point axial coord is in
axial_round :: proc(vec: raylib.Vector2) -> Hex {
	q_frac := vec.x
	r_frac := vec.y
	// round to whole number
	q := cast(i32)math.round_f32(q_frac)
	r := cast(i32)math.round_f32(r_frac)
	// get remainder
	q_frac -= cast(f32)q
	r_frac -= cast(f32)r
	// get delta
	dq := abs(q_frac) >= abs(r_frac) ? math.round_f32(q_frac + 0.5 * r_frac) : 0
	dr := abs(q_frac) < abs(r_frac) ? math.round_f32(r_frac + 0.5 * q_frac) : 0
	return Hex{q = q + cast(i32)dq, r = r + cast(i32)dr}
}

// draw vector2 between two hexes using linear interpolation
lerp :: proc(a: f32, b: f32, dist: f32) -> f32 {
	return a + (b - a) * dist
}

axial_lerp :: proc(a: Hex, b: Hex, dist: f32) -> Hex {
	// Linearly interpolate q and r as floats, then round to nearest axial hex
	q_frac := lerp(cast(f32)a.q, cast(f32)b.q, dist)
	r_frac := lerp(cast(f32)a.r, cast(f32)b.r, dist)
	return axial_round(raylib.Vector2{q_frac, r_frac})
}

// given two Hexes, returns an array of all Hexes that form a line between
axial_linedraw :: proc(a: Hex, b: Hex) -> [dynamic]Hex {
	dist := axial_distance(a, b)
	results := make([dynamic]Hex, 0)
	for i in 0 ..= dist {
		append(&results, axial_lerp(a, b, (1.0 / dist * i)))
	}
	return results
}
