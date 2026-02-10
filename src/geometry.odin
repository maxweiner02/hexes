package hexes

import "core:math"
import "vendor:raylib"

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
	q := int(math.round_f32(q_frac))
	r := int(math.round_f32(r_frac))
	// get remainder
	q_frac -= cast(f32)q
	r_frac -= cast(f32)r
	// get delta
	dq := abs(q_frac) >= abs(r_frac) ? math.round_f32(q_frac + 0.5 * r_frac) : 0
	dr := abs(q_frac) < abs(r_frac) ? math.round_f32(r_frac + 0.5 * q_frac) : 0
	return Hex{q = q + int(dq), r = r + int(dr)}
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
axial_linedraw :: proc(a: Hex, b: Hex, allocator := context.temp_allocator) -> []Hex {
	dist := axial_distance(a, b)
	results := make([dynamic]Hex, 0, allocator)
	defer delete(results)
	for i in 0 ..= dist {
		append(&results, axial_lerp(a, b, (1.0 / dist * i)))
	}
	return results[:]
}

// given a hex_id and a movement range, return an array of hex_ids that can be reached
get_accessible_hexes :: proc(
	start_id: Hex_Id,
	movement: int,
	allocator := context.allocator,
) -> []Hex_Id {
	start := game.level.hex_map.hmap[start_id]

	visited := make(map[i64]bool, allocator)
	defer delete(visited)
	visited[start_id] = true

	fringes := make([dynamic][dynamic]Hex, 0, allocator)
	defer delete(fringes)
	start_arr := make([dynamic]Hex, 0, allocator)
	append(&start_arr, start)
	append(&fringes, start_arr)

	for k in 1 ..= movement {
		// start an empty frontier for distance k
		arr := make([dynamic]Hex, 0, allocator)
		append(&fringes, arr)

		prev := fringes[k - 1]
		for h in prev {
			// iterate 6 axial directions
			for dir in 0 ..< 6 {
				d := AXIAL_DIRECTION_VECTORS[dir]
				neighbor := Hex {
					q = h.q + int(d[0]),
					r = h.r + int(d[1]),
				}
				hex_id := pack_hex(neighbor)

				// out-of-bounds or blocked: skip if not present in map
				if !(hex_id in game.level.hex_map.hmap) {
					continue
				}

				// don't add it if the terrain is impassable
				if !terrain_of(game.level.hex_map.hmap[hex_id].terrain).passable do continue

				// already visited: skip
				if hex_id in visited {
					continue
				}

				// mark visited and add to current frontier
				visited[hex_id] = true
				append(&fringes[k], neighbor)
			}
		}
	}

	for ring in fringes {
		delete(ring)
	}

	result := make([]Hex_Id, len(visited), allocator)
	i := 0
	for id in visited {
		result[i] = id
		i += 1
	}
	return result
}

AXIAL_DIRECTION_VECTORS := [6]Vec2{{1, 0}, {1, -1}, {0, -1}, {-1, 0}, {-1, 1}, {0, 1}}
