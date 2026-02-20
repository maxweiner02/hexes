package hexes

// given a hex_id, return the pawn on it and a bool describing success
get_pawn_for_hex :: proc(hex_id: Hex_Id) -> (^Pawn, bool) {
	// assume that there can only be one pawn on a hex, so once we find it return
	for pawn in game.player.pawns {
		if pawn.location_hex_id == hex_id do return pawn, true
	}

	// didn't have a pawn on it
	return nil, false
}

// a controllable unit
Pawn :: struct {
	name:               string,
	accessible_hex_ids: []Hex_Id,
	visible_hex_ids:    []Hex_Id,
	location_hex_id:    Hex_Id,
	movement_range:     int,
	sight_range:        int,
	texture:            ColorEx,
}
