package hexes

draw_pawn :: proc(pawn: ^Pawn) {
	draw_poly(pawn.visual_position, 4, 10, pawn.visual_rotation + 45, pawn.texture)
}

// given a hex_id, return the pawn on it and a bool describing success
get_pawn_for_hex :: proc(hex_id: Hex_Id) -> (^Pawn, bool) {
	// assume that there can only be one pawn on a hex, so once we find it return
	for pawn in game.level.pawns {
		if pawn.position_hex_id == hex_id do return pawn, true
	}

	// didn't have a pawn on it
	return nil, false
}

// give a pawn and a speed, move the pawn alongs its movement_path; return true on completion
move_along_path :: proc(pawn: ^Pawn, speed: f32, dt: f32) -> bool {
	// we have reached the destination (should've caught this in
	// the previous frame but this is to protect against out_of_bounds)
	if pawn.movement_state.move_idx >= len(pawn.movement_state.move_path) do return true

	// set the target to the next node in the movement path
	target := axial_to_pixel(
		game.level.hex_map.layout,
		&game.level.hex_map.hmap[pawn.movement_state.move_path[pawn.movement_state.move_idx]],
	)

	// how far away we are from the next node
	diff := target - pawn.visual_position
	dist := vec2_length(diff)

	// we are close enough, move to the next node on the next frame
	// no need to move the pawn in this frame
	if dist <= 0.001 {
		pawn.movement_state.move_idx += 1
	} else {
		// we aren't close enough, get the direction vector needed
		// to reach the next node
		dir := diff / dist
		// how far we can go in a single frame in that direction
		step := dir * (speed * dt)
		// set the pawns rotation to that direction vector
		pawn.visual_rotation = vec2_to_deg(dir)

		// we are going to reach/overshoot the node in this step
		// so just snap to it and go to the next node on the
		// following frame
		if vec2_length(step) >= dist {
			pawn.visual_position = target
			// recalculates the vision so it updates as the player hits each node
			{
				pawn.position_hex_id = pawn.movement_state.move_path[pawn.movement_state.move_idx]
				if pawn.visible_hex_ids != nil do delete(pawn.visible_hex_ids)
				pawn.visible_hex_ids = get_visible_hexes(pawn.position_hex_id, pawn.sight_range)
			}
			pawn.movement_state.move_idx += 1
		} else {
			// we won't reach the node in this 'step', so just move
			// us along the direction vector, 'step' distance
			pawn.visual_position += step
		}
	}

	// if we have reached the destination, return true to end the
	// animation loop
	return pawn.movement_state.move_idx >= len(pawn.movement_state.move_path)
}

Movement_State :: struct {
	move_path: []Hex_Id,
	move_idx:  int,
	is_moving: bool,
}

// a unit
Pawn :: struct {
	name:               string,
	player_index:       int,
	initiative:         int,
	accessible_hex_ids: []Hex_Id,
	visible_hex_ids:    []Hex_Id,
	position_hex_id:    Hex_Id, // represents the hex coord the pawn is on
	visual_position:    Vec2, // represents the screen position the hex is being drawn on in a given frame
	visual_rotation:    f32, // represents the direction the pawn is 'facing'
	movement_range:     int,
	cur_movement_range: int,
	sight_range:        int,
	movement_state:     Movement_State,
	texture:            ColorEx,
}
