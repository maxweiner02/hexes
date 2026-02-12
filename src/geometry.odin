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

// Dijkstra node: pairs a hex with its accumulated movement cost for the priority queue
// this isn't strictly necessary but it made it easier to read
Dijkstra_Node :: struct {
	hex_id: Hex_Id,
	// the accumulated movement cost along the path to reach this tile
	cost:   int,
}

// lowest cost has highest priority and will always be at the front of the queue
pq_node_less :: proc(a, b: Dijkstra_Node) -> bool {
	return a.cost < b.cost
}

// Given a hex_id and a movement budget, return all reachable hex_ids using
// Dijkstra's algorithm, paying attention to movement cost and passability.
// Pardon the comments, this is took a while to wrap my head around
get_accessible_hexes :: proc(
	start_id: Hex_Id,
	movement: int,
	allocator := context.allocator,
) -> []Hex_Id {

	// set up the priority queue to make sure that the lowest cost node/hex
	// is always at the front of the queue and is processed first.
	frontier: pq.Priority_Queue(Dijkstra_Node)
	pq.init(&frontier, pq_node_less, pq.default_swap_proc(Dijkstra_Node))
	defer pq.destroy(&frontier)

	// start with the location the user is on; cost is zero because no movement
	// is needed to get here
	pq.push(&frontier, Dijkstra_Node{hex_id = start_id, cost = 0})

	// records the lowest known cost to reach any visited hex, and also gives
	// us an easy way to check if a hex has been visited before
	cost_so_far := make(map[Hex_Id]int)
	defer delete(cost_so_far)
	cost_so_far[start_id] = 0

	// keep going until there is nothing left to explore (we have run out of
	// movement points or we are surrounded by impassable options on every
	// direction)
	for pq.len(frontier) > 0 {
		current := pq.pop(&frontier)

		best_path, ok := cost_so_far[current.hex_id]

		// if we already found a cheaper path to this hex, move on
		// this is why the priority queue is useful.  the hex N can be present
		// multiple times and by ensuring the current cheapest way to get hex N
		// is processed first we can stop redundant work. brute force would
		// work without the priority queue (and at most sizes the extra work is
		// negligible) but Dijkstra's Algo calls for a priority queue conceptually
		// and Odin happened to have one!
		if ok && current.cost > best_path {
			continue
		}

		current_hex := game.level.hex_map.hmap[current.hex_id]

		// we get the hex coords for each of the six possible neighbors
		for dir in 0 ..< 6 {
			d := AXIAL_DIRECTION_VECTORS[dir]
			neighbor_hex := Hex {
				q = current_hex.q + int(d[0]),
				r = current_hex.r + int(d[1]),
			}
			neighbor_id := pack_hex(neighbor_hex)

			// need to do this safety check since we aren't sure a given neighbor
			// is out of bounds or not
			neighbor_data, ok := game.level.hex_map.hmap[neighbor_id]
			if !ok do continue

			// if not passable, move on
			terrain := TERRAIN_DATA[neighbor_data.terrain]
			if !terrain.passable do continue

			// calc the movement cost before adding it to frontier
			new_cost := current.cost + terrain.movement_cost

			// will go over movement budget, move on
			if new_cost > movement do continue

			// check if we visited it, and if so what it would've cost previously
			old_cost, visited := cost_so_far[neighbor_id]
			// if we never visited it, add it to the map of costs and frontier queue
			// if we have visited it and this new way is cheaper, set the cost in
			// the cost map to the cheaper cost; also add it to the frontier queue to
			// be processed
			if !visited || new_cost < old_cost {
				cost_so_far[neighbor_id] = new_cost
				// add it to the queue to be processed
				pq.push(&frontier, Dijkstra_Node{hex_id = neighbor_id, cost = new_cost})
			}
		}
	}

	// collect all reachable hexes (excluding the start position)
	results := make([dynamic]Hex_Id, allocator)
	for id in cost_so_far {
		if id != start_id {
			append(&results, id)
		}
	}

	return results[:]
}

AXIAL_DIRECTION_VECTORS := [6]Vec2{{1, 0}, {1, -1}, {0, -1}, {-1, 0}, {-1, 1}, {0, 1}}
