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

	for q in -MAP_RADIUS ..= MAP_RADIUS {
		(q >= -MAP_RADIUS && q <= MAP_RADIUS) or_continue

		for r in -MAP_RADIUS ..= MAP_RADIUS {
			(r >= -MAP_RADIUS && r <= MAP_RADIUS) or_continue

			s := -q - r

			(s >= -MAP_RADIUS && s <= MAP_RADIUS) or_continue

			add_hex(
				&game.level.hex_map,
				Hex{q = q, r = r, terrain = Terrain(rand.int_range(0, 4))},
			)
		}
	}
}

shutdown_game :: proc() {
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

Level :: struct {
	name:    string,
	hex_map: Hex_Map,
}

Game :: struct {
	level:  Level,
	player: Player,
	camera: Camera,
}
