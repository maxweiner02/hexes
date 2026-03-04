package hexes

import "core:fmt"
import "core:slice"

init_encounter_controller :: proc() {
	game.encounter_controller = {}
}

prepare_encounter :: proc() {
	enter_state(Start_Encounter{})
}

update_encounter_controller :: proc(dt: f32) {
	encounter_controller := &game.encounter_controller

	switch &var in encounter_controller.state {
	case Start_Encounter:
		if state, ok := update_start_encounter(&var); ok {
			exit_state(var)
			enter_state(state)
		}
	case Start_Turn:
		if state, ok := update_start_turn(&var); ok {
			exit_state(var)
			enter_state(state)
		}
	case Input_Phase:
		if state, ok := update_input_phase(&var, dt); ok {
			exit_state(var)
			enter_state(state)
		}
	case Movement_Action:
		if state, ok := update_movement_action(&var, dt); ok {
			exit_state(var)
			enter_state(state)
		}
	case End_Turn:
		if state, ok := update_end_turn(&var); ok {
			exit_state(var)
			enter_state(state)
		}
	case End_Encounter:
		if state, ok := update_end_encounter(&var); ok {
			exit_state(var)
			enter_state(state)
		}
	}
}

update_start_encounter :: proc(state: ^Start_Encounter) -> (Encounter_State, bool) {
	ctrl := &game.encounter_controller
	if ctrl.initiative_order != nil do delete(ctrl.initiative_order)
	ctrl.initiative_order = build_initiative_order()
	return Start_Turn{pawn_index = 0}, true
}

update_start_turn :: proc(state: ^Start_Turn) -> (Encounter_State, bool) {
	pawn := get_pawn_at_initiative(state.pawn_index)

	pawn.cur_movement_range = pawn.movement_range
	if pawn.accessible_hex_ids != nil do delete(pawn.accessible_hex_ids)
	pawn.accessible_hex_ids = get_accessible_hexes(pawn.position_hex_id, pawn.cur_movement_range)

	// auto-select the current pawn for the human player at the start of their turn
	if pawn.player_index == 0 {
		game.players[0].select_pawn = pawn
	} else {
		// for now lets just skip AI turns
		return End_Turn{pawn_index = state.pawn_index}, true
	}

	return Input_Phase{pawn_index = state.pawn_index}, true
}

update_input_phase :: proc(state: ^Input_Phase, dt: f32) -> (Encounter_State, bool) {
	pawn := get_pawn_at_initiative(state.pawn_index)

	if pawn.player_index == 0 {
		update_player(dt)

		if is_mouse_button_released(RIGHT_CLICK) {
			player := &game.players[0]
			if player.select_pawn == pawn && player.is_hovering {
				for id in pawn.accessible_hex_ids {
					if id == player.hover_hex_id {
						path := get_path_to_hex(
							pawn.position_hex_id,
							player.hover_hex_id,
							pawn.cur_movement_range,
						)
						return Movement_Action {
								pawn_index = state.pawn_index,
								dest = player.hover_hex_id,
								path = path,
							},
							true
					}
				}
			}
		}
	}

	if game.encounter_controller.end_turn_requested {
		game.encounter_controller.end_turn_requested = false
		return End_Turn{pawn_index = state.pawn_index}, true
	}

	return {}, false
}

update_movement_action :: proc(state: ^Movement_Action, dt: f32) -> (Encounter_State, bool) {
	pawn := get_pawn_at_initiative(state.pawn_index)

	if !pawn.movement_state.is_moving {
		if pawn.movement_state.move_path != nil {
			delete(pawn.movement_state.move_path)
		}
		// transfer ownership of path to the pawn's movement state
		pawn.movement_state.move_path = state.path
		state.path = nil
		pawn.movement_state.move_idx = 0
		pawn.movement_state.is_moving = true
	}

	finished := move_along_path(pawn, MOVE_SPEED, dt)
	if finished {
		pawn.movement_state.is_moving = false
		pawn.visual_rotation = 0
		return Input_Phase{pawn_index = state.pawn_index}, true
	}

	return {}, false
}

update_end_turn :: proc(state: ^End_Turn) -> (Encounter_State, bool) {
	ctrl := &game.encounter_controller
	next_pawn_index := (state.pawn_index + 1) % len(ctrl.initiative_order)
	if next_pawn_index == 0 {
		ctrl.turn_num += 1
	}
	return Start_Turn{pawn_index = next_pawn_index}, true
}

update_end_encounter :: proc(state: ^End_Encounter) -> (Encounter_State, bool) {
	return {}, false
}

enter_state :: proc(state: Encounter_State) {
	encounter_controller := &game.encounter_controller
	encounter_controller.state = state

	#partial switch &var in encounter_controller.state {}
}

exit_state :: proc(state: Encounter_State) {
	#partial switch var in state {
	case Input_Phase:
		player := &game.players[0]
		if player.cached_path != nil {
			delete(player.cached_path)
			player.cached_path = nil
		}
	case Movement_Action:
		pawn := get_pawn_at_initiative(var.pawn_index)

		// deduct movement cost along the path
		path_cost := 0
		if pawn.movement_state.move_path != nil {
			for id in pawn.movement_state.move_path[1:] {
				hex := game.level.hex_map.hmap[id]
				path_cost += TERRAIN_DATA[hex.terrain].movement_cost
			}
		}
		pawn.cur_movement_range -= path_cost
		pawn.position_hex_id = var.dest

		if pawn.movement_state.move_path != nil {
			delete(pawn.movement_state.move_path)
			pawn.movement_state.move_path = nil
		}

		// free path if ownership transfer didn't happen
		if var.path != nil {
			delete(var.path)
		}

		if pawn.accessible_hex_ids != nil do delete(pawn.accessible_hex_ids)
		if pawn.visible_hex_ids != nil do delete(pawn.visible_hex_ids)
		pawn.visible_hex_ids = get_visible_hexes(pawn.position_hex_id, pawn.sight_range)
		pawn.accessible_hex_ids = get_accessible_hexes(
			pawn.position_hex_id,
			pawn.cur_movement_range,
		)

		player := &game.players[0]
		if player.visible_hex_ids != nil do delete(player.visible_hex_ids)
		player.visible_hex_ids = resolve_player_visible_hexes(pawn.player_index)

		hex_coords := unpack_hex_id(pawn.position_hex_id)
		movement_msg := fmt.tprintf("%v moved to (%v, %v)", pawn.name, hex_coords.q, hex_coords.r)
		add_message(movement_msg)
	}
}

get_current_pawn :: proc() -> ^Pawn {
	ctrl := &game.encounter_controller
	if len(ctrl.initiative_order) == 0 do return nil
	#partial switch state in ctrl.state {
	case Input_Phase:
		return get_pawn_at_initiative(state.pawn_index)
	case Movement_Action:
		return get_pawn_at_initiative(state.pawn_index)
	}
	return nil
}

get_pawn_at_initiative :: proc(initiative_idx: int) -> ^Pawn {
	ctrl := &game.encounter_controller
	return game.level.pawns[ctrl.initiative_order[initiative_idx]]
}

@(private = "file")
build_initiative_order :: proc() -> []int {
	n := len(game.level.pawns)
	order := make([]int, n)
	for i in 0 ..< n {
		order[i] = i
	}
	// sort descending by initiative so the highest goes first
	slice.sort_by(order, proc(a, b: int) -> bool {
		return game.level.pawns[a].initiative > game.level.pawns[b].initiative
	})
	return order
}

get_current_phase :: proc() -> Encounter_State {
	return game.encounter_controller.state
}

Encounter_State_Controller :: struct {
	state:              Encounter_State,
	turn_num:           int,
	initiative_order:   []int,
	end_turn_requested: bool,
}

Encounter_State :: union {
	Start_Encounter,
	Start_Turn,
	Input_Phase,
	Movement_Action,
	End_Turn,
	End_Encounter,
}

Start_Encounter :: struct {}

Start_Turn :: struct {
	pawn_index: int,
}

Input_Phase :: struct {
	pawn_index: int,
}

Movement_Action :: struct {
	pawn_index: int,
	dest:       Hex_Id,
	path:       []Hex_Id,
}

End_Turn :: struct {
	pawn_index: int,
}

End_Encounter :: struct {}
