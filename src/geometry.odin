package hexes

import pq "core:container/priority_queue"
import "core:math"
import "core:slice"
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
@(private = "file")
Dijkstra_Node :: struct {
	hex_id: Hex_Id,
	// the accumulated movement cost along the path to reach this tile
	cost:   int,
}

// lowest cost has highest priority and will always be at the front of the queue
@(private = "file")
dijkstra_node_less :: proc(a, b: Dijkstra_Node) -> bool {
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
	pq.init(&frontier, dijkstra_node_less, pq.default_swap_proc(Dijkstra_Node))
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

// the same as the Dijkstra_Node but with an added field for the heuristic
@(private = "file")
A_Star_Node :: struct {
	hex_id:   Hex_Id,
	cost:     int,
	priority: int,
}

// instead of wanting the lowest cost, we want the lowest heuristic (distance to goal)
@(private = "file")
a_star_node_less :: proc(a: A_Star_Node, b: A_Star_Node) -> bool {
	return a.priority < b.priority
}

// given a start, end, and movement cost, use A* algorithm to find a path
// this is very similar to the Dijkstra Algorithm
get_path_to_hex :: proc(
	start_id: Hex_Id,
	end_id: Hex_Id,
	movement: int,
	allocator := context.allocator,
) -> []Hex_Id {
	frontier: pq.Priority_Queue(A_Star_Node)
	pq.init(&frontier, a_star_node_less, pq.default_swap_proc(A_Star_Node))
	defer pq.destroy(&frontier)

	cost_so_far := make(map[Hex_Id]int)
	defer delete(cost_so_far)

	// we need a came_from map for this so we can construct the best path
	// taken instead of just returning ALL hexes in the cost_so_far map
	came_from := make(map[Hex_Id]Hex_Id)
	defer delete(came_from)

	// get start and end hex for heuristics
	start_hex := game.level.hex_map.hmap[start_id]
	end_hex := game.level.hex_map.hmap[end_id]

	// seed the queue and map
	// NOTE: The heuristic is just the axial_distance from end_hex to
	// the current_hex (which starts off as our start_hex)
	pq.push(
		&frontier,
		A_Star_Node {
			hex_id = start_id,
			cost = 0,
			priority = int(axial_distance(end_hex, start_hex)),
		},
	)
	cost_so_far[start_id] = 0

	for pq.len(frontier) > 0 {
		current := pq.pop(&frontier)

		// we made it!
		if current.hex_id == end_id do break

		best_path, ok := cost_so_far[current.hex_id]

		if best_path < current.cost do continue

		current_hex := game.level.hex_map.hmap[current.hex_id]

		for direction in 0 ..< 6 {
			dir := AXIAL_DIRECTION_VECTORS[direction]

			neighbor := Hex {
				q = current_hex.q + int(dir.x),
				r = current_hex.r + int(dir.y),
			}

			neighbor_id := pack_hex(neighbor)
			neighbor_hex, ok := game.level.hex_map.hmap[neighbor_id]

			if !ok do continue

			if !TERRAIN_DATA[neighbor_hex.terrain].passable do continue

			new_cost := current.cost + TERRAIN_DATA[neighbor_hex.terrain].movement_cost

			if new_cost > movement do continue

			old_cost, visited := cost_so_far[neighbor_id]
			if !visited || new_cost < old_cost {
				cost_so_far[neighbor_id] = new_cost
				priority := new_cost + int(axial_distance(end_hex, neighbor_hex))
				pq.push(
					&frontier,
					A_Star_Node{hex_id = neighbor_id, cost = new_cost, priority = priority},
				)
				came_from[neighbor_id] = current.hex_id
			}
		}
	}

	path := make([dynamic]Hex_Id)
	defer delete(path)
	current_id := end_id
	for current_id != start_id {
		append(&path, current_id)
		current_id = came_from[current_id]
	}
	// add the start_id to include the origin hex in the path
	append(&path, current_id)

	// we traverse through it backwards, so this puts it from start to end
	slice.reverse(path[:])
	return path[:]
}

// given a hex_id and a direction, check if a neighbor exists in that direction
has_neighbor :: proc(hex_id: Hex_Id, direction: Direction) -> bool {
	current_hex, exists := game.level.hex_map.hmap[hex_id]

	// the hex_id provided does not exist
	if !exists do return false

	direction_vec := AXIAL_DIRECTION_VECTORS[int(direction)]

	neighbor := Hex {
		q = current_hex.q + int(direction_vec.x),
		r = current_hex.r + int(direction_vec.y),
	}

	neighbor_id := pack_hex(neighbor)

	return neighbor_id in game.level.hex_map.hmap
}

// given a group of hex_ids, a hex_id, and a direction, check if the hex in that direction
// is within the group
has_neighbor_in_group :: proc(group: []Hex_Id, hex_id: Hex_Id, direction: Direction) -> bool {
	current_hex, exists := game.level.hex_map.hmap[hex_id]

	// the hex_id provided does not exist
	if !exists do return false

	direction_vec := AXIAL_DIRECTION_VECTORS[int(direction)]

	neighbor := Hex {
		q = current_hex.q + int(direction_vec.x),
		r = current_hex.r + int(direction_vec.y),
	}

	neighbor_id := pack_hex(neighbor)

	return slice.contains(group, neighbor_id)
}

// given a grouping of hex_ids, return any line segments that border hexes outside of the group
// include_id is an optional extra hex to treat as part of the group (e.g. the player's position)
get_poly_outline :: proc(
	hex_ids: []Hex_Id,
	include_id: Hex_Id = 0,
	allocator := context.allocator,
) -> [][2]Vec2 {
	layout := game.level.hex_map.layout

	// build the full group, optionally including the extra id
	// need this so we can include the player's current position
	group := make([dynamic]Hex_Id, 0, context.temp_allocator)
	if include_id != 0 {
		append(&group, include_id)
	}
	append(&group, ..hex_ids)
	full_group := group[:]

	segments := make([dynamic][2]Vec2)
	defer delete(segments)

	for hex_id in full_group {
		// we are confident that we will always include real hexes, but just in case
		hex, exists := game.level.hex_map.hmap[hex_id]
		if !exists do continue

		// get the corner vec2 of the hex
		corners := hex_corners(layout, &hex)

		// go in each direction and check if there is a neighbor outside the group
		// or we are at a map edge
		for dir in 0 ..< 6 {
			if !has_neighbor_in_group(full_group, hex_id, Direction(dir)) {
				// get the line segment (pair of Vec2) for that direction's face
				corner_indices := DIRECTION_TO_VERTEX[dir]
				append(&segments, [2]Vec2{corners[corner_indices[0]], corners[corner_indices[1]]})
			}
		}
	}

	// make the slice so we don't return a dynamic array
	result := make([dynamic][2]Vec2, allocator)
	append(&result, ..segments[:])
	return result[:]
}

// index 0 is the right edge and goes counter-clockwise
AXIAL_DIRECTION_VECTORS := [6]Vec2{{1, 0}, {1, -1}, {0, -1}, {-1, 0}, {-1, 1}, {0, 1}}

// corner index pairs for each direction vector
DIRECTION_TO_VERTEX := [6][2]int{{5, 0}, {4, 5}, {3, 4}, {2, 3}, {1, 2}, {0, 1}}

// semantic way to refer to a direction from a hex
Direction :: enum {
	Right,
	Top_Right,
	Top_Left,
	Left,
	Bottom_Left,
	Bottom_Right,
}
