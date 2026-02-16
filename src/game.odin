package hexes

import "core:math/linalg"
import "core:math/rand"

game: ^Game

init_game :: proc() {
	game = new(Game)

	game.camera = {
		target = {0, 0},
		offset = {WINDOW_WIDTH / 2, WINDOW_HEIGHT / 2},
		zoom   = 1.5,
	}
}

init_level :: proc() {
	test_map := Hex_Map {
		hmap = make(map[i64]Hex),
		layout = {radius = 30, origin = {0, 0}},
	}

	game.level = {
		name    = "Test Level",
		hex_map = test_map,
	}

	all_terrains := [?]Terrain_Type{.Lava, .Grass, .Desert, .Wall}


	for q in -MAP_RADIUS ..= MAP_RADIUS {
		(q >= -MAP_RADIUS && q <= MAP_RADIUS) or_continue

		for r in -MAP_RADIUS ..= MAP_RADIUS {
			(r >= -MAP_RADIUS && r <= MAP_RADIUS) or_continue

			s := -q - r

			(s >= -MAP_RADIUS && s <= MAP_RADIUS) or_continue

			add_hex(&game.level.hex_map, Hex{q = q, r = r, terrain = rand.choice(all_terrains[:])})
		}
	}

	// for now make sure the origin is not impassable so we don't spawn in a wall
	(&game.level.hex_map.hmap[pack_axial(0, 0)]).terrain = .Grass

	compute_map_bounds()
}

shutdown_game :: proc() {
	if game.player.accessible_hex_ids != nil {
		delete(game.player.accessible_hex_ids)
	}

	if game.player.visible_hex_ids != nil {
		delete(game.player.visible_hex_ids)
	}

	if game.player.cached_path != nil {
		delete(game.player.cached_path)
	}

	delete(game.level.hex_map.hmap)

	free(game)
}

run_game_loop :: proc() {
	for !window_should_close() {
		update_one_frame(get_frame_time())
		draw()

		free_all(context.temp_allocator)
	}
}

draw :: proc() {
	begin_drawing()
	clear_background(WHITE)

	{
		begin_2d_mode(game.camera)

		draw_hex_map()

		end_2d_mode()
	}


	end_drawing()
}

update_one_frame :: proc(dt: f32) {
	update_camera(dt)
	update_player(dt)
}

update_camera :: proc(dt: f32) {
	move_camera(dt)
	zoom_camera()
	clamp_camera()
}

move_camera :: proc(dt: f32) {
	mouse_pos := get_mouse_pos()

	if (mouse_pos.x >= 0 && mouse_pos.y <= CAMERA_PAN_MARGIN) || is_key_down(UP) {
		game.camera.target.y -= CAMERA_SPEED * dt
	} else if (mouse_pos.y <= WINDOW_HEIGHT && mouse_pos.y >= WINDOW_HEIGHT - CAMERA_PAN_MARGIN) ||
	   is_key_down(DOWN) {
		game.camera.target.y += CAMERA_SPEED * dt
	}

	if (mouse_pos.x >= 0 && mouse_pos.x <= CAMERA_PAN_MARGIN) || is_key_down(LEFT) {
		game.camera.target.x -= CAMERA_SPEED * dt
	} else if (mouse_pos.x <= WINDOW_WIDTH && mouse_pos.x >= WINDOW_WIDTH - CAMERA_PAN_MARGIN) ||
	   is_key_down(RIGHT) {
		game.camera.target.x += CAMERA_SPEED * dt
	}
}

zoom_camera :: proc() {
	wheel_scroll := get_wheel_scroll()

	if wheel_scroll != 0 {
		game.camera.zoom = clamp(
			linalg.exp2(linalg.log2(game.camera.zoom) + wheel_scroll * 0.1),
			CAMERA_ZOOM_MIN,
			CAMERA_ZOOM_MAX,
		)
	}
}

clamp_camera :: proc() {
	allowed_min_q := game.level.bounds_q[0] + (WINDOW_WIDTH / (2 * game.camera.zoom))
	allowed_max_q := game.level.bounds_q[1] - (WINDOW_WIDTH / (2 * game.camera.zoom))

	allowed_min_r := game.level.bounds_r[0] + (WINDOW_HEIGHT / (2 * game.camera.zoom))
	allowed_max_r := game.level.bounds_r[1] - (WINDOW_HEIGHT / (2 * game.camera.zoom))

	game.camera.target = {
		clamp(game.camera.target.x, allowed_min_q, allowed_max_q),
		clamp(game.camera.target.y, allowed_min_r, allowed_max_r),
	}
}

compute_map_bounds :: proc() {
	hmap := game.level.hex_map.hmap
	layout := game.level.hex_map.layout

	// get the hexes at the polar edges of q and r (x,y)
	min_q_hex, _ := hmap[pack_axial(-MAP_RADIUS, 0)]
	max_q_hex, _ := hmap[pack_axial(MAP_RADIUS, 0)]
	min_r_hex, _ := hmap[pack_axial(0, -MAP_RADIUS)]
	max_r_hex, _ := hmap[pack_axial(0, MAP_RADIUS)]

	// get their pixel coords
	min_q := axial_to_pixel(layout, &min_q_hex).x - cast(f32)layout.radius
	max_q := axial_to_pixel(layout, &max_q_hex).x + cast(f32)layout.radius
	min_r := axial_to_pixel(layout, &min_r_hex).y - cast(f32)layout.radius
	max_r := axial_to_pixel(layout, &max_r_hex).y + cast(f32)layout.radius

	game.level.bounds_q = {min_q, max_q}
	game.level.bounds_r = {min_r, max_r}
}

Level :: struct {
	name:     string,
	hex_map:  Hex_Map,
	bounds_q: Vec2,
	bounds_r: Vec2,
}

Game :: struct {
	level:  Level,
	player: Player,
	camera: Camera,
}
