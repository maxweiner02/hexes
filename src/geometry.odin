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

// given two hex ids, returns an array of all Hexes that form a line between
axial_linedraw :: proc(
	id_a: Hex_Id,
	id_b: Hex_Id,
	allocator := context.temp_allocator,
) -> []Hex_Id {
	a, a_exists := game.level.hex_map.hmap[id_a]
	b, b_exists := game.level.hex_map.hmap[id_b]
	if !a_exists || !b_exists do return {}
	dist := axial_distance(a, b)
	results := make([dynamic]Hex_Id, allocator)
	for i in 0 ..= dist {
		append(&results, pack_hex(axial_lerp(a, b, (1.0 / dist * i))))
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
			if .Passable not_in neighbor_data.properties do continue

			// calc the movement cost before adding it to frontier
			terrain := TERRAIN_DATA[neighbor_data.terrain]
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

// given a start, end, and movement cost, use A* algorithm to find a path;
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

			if .Passable not_in neighbor_hex.properties do continue

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

	path := make([dynamic]Hex_Id, allocator)
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
	include_id: Hex_Id = -1,
	allocator := context.allocator,
) -> [][2]Vec2 {
	layout := game.level.hex_map.layout

	// build the full group, optionally including the extra id
	// need this so we can include the player's current position
	group := make([dynamic]Hex_Id, 0, context.temp_allocator)
	if include_id != -1 {
		append(&group, include_id)
	}
	append(&group, ..hex_ids)
	full_group := group[:]

	segments := make([dynamic][2]Vec2, allocator)
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

get_visible_hexes :: proc(
	current_id: Hex_Id,
	sight_range: int,
	allocator := context.allocator,
) -> []Hex_Id {
	results := make([dynamic]Hex_Id, allocator)
	append(&results, current_id)

	// scan each of the 6 sextants independently and build the results array
	for dir in 0 ..< 6 {
		scan_sextant(current_id, Direction(dir), sight_range, &results)
	}

	return results[:]
}

@(private = "file")
// go ring-by-ring outwards checking if there are any walls to cast a shadow and then calculating
// which hexes are hidden by any shadows in a given 60 degree sextant
scan_sextant :: proc(
	center_id: Hex_Id,
	sextant_index: Direction,
	sight_range: int,
	results: ^[dynamic]Hex_Id,
) {
	shadows := make([dynamic][2]f32, context.temp_allocator)

	// loop through 'sight_range' number of rings, ignoring ring 0 (current position)
	for ring in 1 ..= sight_range {
		// each sextant will have 'ring' number of hexes and is zero-indexed
		for pos in 0 ..< ring {
			// ex: 0th
			hex_start_slope := f32(pos) / f32(ring)
			// ex: 0th (first) position on 2nd ring = 0.5 (since that hexes range ends halfway through the arc)
			hex_end_slope := f32(pos + 1) / f32(ring)

			hex_id := axial_from_sextant(center_id, sextant_index, ring, pos)

			hex, exists := game.level.hex_map.hmap[hex_id]

			if !exists do continue

			// if fully shadowed by a closer wall, skip it since casting another shadow would be redundant
			// and it isn't visible so it shouldn't be appended to the results
			if is_shadowed(hex_start_slope, hex_end_slope, &shadows) do continue

			// it's visible (not covered by a closer shadow), so add it to the results
			append(results, hex_id)
			// update the .Discovered flag so it is no longer fully blacked out
			if .Discovered not_in hex.state {
				(&game.level.hex_map.hmap[hex_id]).state += {.Discovered}
			}

			// if it's not transparent it will cast a shadow for hexes behind it, so add the range
			// it covers to the shadows array
			if .Transparent not_in hex.properties {
				add_shadow(&shadows, hex_start_slope, hex_end_slope)

				// early exit: if the entire sextant is shadowed, stop processing further rings
				// this will happen if the only hex in the first ring is not transparent and saves
				// us from continuing through the sextant
				// TODO: add a more robust early exit that handles subsequent rows being wholly
				// made up of non-transparent hexes
				if len(shadows) == 1 && shadows[0][0] <= 0.0 && shadows[0][1] >= 1.0 {
					return
				}
			}
		}
	}
}

@(private = "file")
// given a center, sextant index (Direction), ring number, and position in the ring, return a hex_id
axial_from_sextant :: proc(
	center_id: Hex_Id,
	sextant_index: Direction,
	ring: int,
	pos_in_ring: int,
) -> Hex_Id {
	// this vector moves us 'out' from the center to form the primary edge
	// of the fan
	primary := AXIAL_DIRECTION_VECTORS[int(sextant_index)]
	// this is the tangential step that happens after we make the primary move
	// we must move 120 degrees counter-clockwise from the primary vector to
	// ensure that we move along the 'arc' of the 60 degree sextant
	step := AXIAL_DIRECTION_VECTORS[(int(sextant_index) + 2) % 6]

	// current position
	center_hex := game.level.hex_map.hmap[center_id]

	// ex: from 0,0 in sextant 0, ring 2, pos 1 (2nd position but zero indexed)
	// primary vector = {1, 0} | step vector = {0, -1}
	// q = 0 + (2 * 1) + (1 * 0) -> q = 2
	q := center_hex.q + (ring * int(primary.x)) + (pos_in_ring * int(step.x))
	// r = 0 + (2 * 0) + (1 * -1) -> r = -1
	r := center_hex.r + (ring * int(primary.y)) + (pos_in_ring * int(step.y))

	return pack_axial(q, r)
}

@(private = "file")
// add a new shadow f32 pair, ensuring proper low -> high ordering and merging overlapping ranges
add_shadow :: proc(shadows: ^[dynamic][2]f32, new_start: f32, new_end: f32) {
	start := new_start
	end := new_end

	// find the insertion point and merge with any overlapping intervals
	i := 0
	for i < len(shadows) {
		shadow := shadows[i]

		// this shadow ends before the new shadow starts: skip it
		if shadow[1] < start {
			i += 1
			continue
		}

		// this shadow starts after the new shadow ends: stop, found insertion point
		if shadow[0] > end do break

		// overlapping - merge by extending the new range and remove the old interval
		start = min(start, shadow[0])
		end = max(end, shadow[1])
		ordered_remove(shadows, i)
	}

	// insert the merged interval at position i
	inject_at(shadows, i, [2]f32{start, end})
}

@(private = "file")
// given a start and end slope, check if it is within any shadow slope ranges
is_shadowed :: proc(hex_start_slope: f32, hex_end_slope: f32, shadows: ^[dynamic][2]f32) -> bool {
	uncovered_start := hex_start_slope

	for shadow in shadows {
		// current shadow starts past the area we are checking so the area cannot be shadowed
		// we are confident of this because shadows are ordered low -> high so no subsequent
		// shadow will start earlier than the current one, and all previous ones have already been
		// checked and passed through the loop without returning/breaking
		if shadow[0] > uncovered_start do break

		// this shadow covers some of the remaining range so we move the start
		// of the 'uncovered area' to the end of the current shadow range
		if shadow[1] > uncovered_start {
			uncovered_start = shadow[1]
		}

		// the start of the 'uncovered area' is past the end of the range we are
		// checking so we are now confident that this range is shadowed
		if uncovered_start >= hex_end_slope do return true
	}

	// assuming we have broken out of the loop, the area between the start and end slope
	// are uncovered
	return false
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
