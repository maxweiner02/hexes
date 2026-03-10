package hexes

init_timer_system :: proc() {}

update_timers :: proc(dt: f32) {
	sys := &game.timer_system

	for &timer in sys.timers {
		timer.is_active or_continue
		(timer.is_expired == false) or_continue

		timer.elapsed += dt

		if timer.elapsed >= timer.duration do timer.is_expired = true
	}
}

create_timer :: proc(duration: f32) -> ^Timer {
	timer := get_next_available_timer()

	timer^ = Timer {
		duration   = duration,
		elapsed    = 0,
		is_active  = true,
		is_expired = false,
	}

	return timer
}

reset_timer :: proc(timer: ^Timer) {
	timer.elapsed = 0
	timer.is_expired = false
}

destroy_timer :: proc(timer: ^Timer) {
	timer.is_active = false
}

timer_is_expired :: proc(timer: ^Timer) -> bool {
	return timer.is_expired
}

get_next_available_timer :: proc() -> (^Timer, bool) #optional_ok {
	sys := &game.timer_system

	start_index := sys.next_unused

	for start_index != get_next_unused_index() {
		timer := &sys.timers[sys.next_unused]

		sys.next_unused = get_next_unused_index()
		if !timer.is_active {
			return timer, true
		}
	}

	return nil, false
}

get_next_unused_index :: proc() -> int {
	return (game.timer_system.next_unused + 1) % len(game.timer_system.timers)
}

Timer_System :: struct {
	timers:      [64]Timer,
	next_unused: int,
}

Timer :: struct {
	duration:   f32,
	elapsed:    f32,
	is_expired: bool,
	is_active:  bool,
}
