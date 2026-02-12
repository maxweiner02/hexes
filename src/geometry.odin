package hexes

import pq "core:container/priority_queue"
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
// uses a BFS (Breadth-First-Search) to look for ALL possible hexes within a movement range
// TODO: Use Dijkstra's Algorithm to implement 'cost' values from terrain types
get_accessible_hexes :: proc(
	start_id: Hex_Id,
	movement: int,
	allocator := context.allocator,
) -> []Hex_Id {
	start := game.level.hex_map.hmap[start_id]
	frontier: pq.Priority_Queue(Hex)
	pq.init(&frontier, pq_min_cmp, pq.default_swap_proc)
	pq.push(&frontier, start)

	came_from := make(map[Hex_Id]Hex)
	came_from[start_id] = nil

	cost_so_far := make(map[Hex_Id]int)
	cost_so_far[start_id] = 0

	len := pq.len(&frontier)
	for len > 0 {
		current := pq.peek(&frontier)

		for dir in 0 ..< 6 {
			d := AXIAL_DIRECTION_VECTORS[dir]
			neighbor := Hex {
				q = current.q + int(d[0]),
				r = current.r + int(d[1]),
			}
			hex_id := pack_hex(neighbor)

			new_cost :=
				cost_so_far[pack_hex(current)] +
				TERRAIN_DATA[game.level.hex_map.hmap[hex_id].terrain].movement_cost

			cost_with_new, ok := cost_so_far[hex_id]

			if !ok || new_cost < cost_with_new {
				cost_so_far[hex_id] = new_cost
				priority := new_cost
				pq.push(&frontier, neighbor)
				came_from[hex_id] = current
			}
		}
	}
	return frontier
}

pq_min_cmp :: proc(a, b: Hex_Id) -> bool {
	return a < b
}

AXIAL_DIRECTION_VECTORS := [6]Vec2{{1, 0}, {1, -1}, {0, -1}, {-1, 0}, {-1, 1}, {0, 1}}
