package hexes

import "core:math/linalg"

init_camera :: proc() {
	game.camera = {
		target = {0, 0},
		offset = {WINDOW_WIDTH / 2, WINDOW_HEIGHT / 2},
		zoom   = 1.5,
	}
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

	if ui_consuming_mouse() do return

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
