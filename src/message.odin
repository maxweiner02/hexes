package hexes

import "core:container/queue"
import "core:strings"

init_message_system :: proc() {
	game.message_system = {}

	queue.init(&game.message_system.message_queue, MESSAGE_CAPACITY)
}

shutdown_message_system :: proc() {
	sys := &game.message_system

	for queue.len(sys.message_queue) > 0 {
		message := queue.dequeue(&sys.message_queue)

		delete(message.msg)
	}

	queue.destroy(&sys.message_queue)
}

add_message :: proc(message: string) {
	sys := &game.message_system

	queue.push_back(
		&sys.message_queue,
		Message {
			msg = strings.clone(message),
			text_size = measure_text_ex(
				get_font_default(),
				message,
				MESSAGE_FONT_SIZE,
				MESSAGE_SPACING,
			),
		},
	)

	queue_len := queue.len(sys.message_queue)
	max_messages := get_max_visible_messages()

	// we were at the bottom beforen adding the new message
	if sys.message_offset == (queue_len - 1) - max_messages {
		// we have filled the message box so we need to auto-scroll
		if queue_len > max_messages {
			sys.message_offset = queue_len - max_messages
		}
	}
}

update_messages :: proc(dt: f32) {
	sys := &game.message_system

	// labeled loops are cool, Odin is so dope!
	reduce_queue: for queue.len(sys.message_queue) > MESSAGE_CAPACITY {
		_, ok := queue.pop_front_safe(&sys.message_queue)

		ok or_break reduce_queue
	}
}

@(private = "file")
get_max_visible_messages :: proc() -> int {
	return (MESSAGE_BOX_HEIGHT - MESSAGE_BOX_MARGIN) / (MESSAGE_FONT_SIZE + MESSAGE_BOX_MARGIN)
}

@(private = "file")
get_message_box_rect :: proc() -> Rectangle {
	return Rectangle {
		5,
		cast(f32)get_screen_height() - MESSAGE_BOX_HEIGHT - 5,
		MESSAGE_BOX_WIDTH,
		MESSAGE_BOX_HEIGHT,
	}
}

draw_messages :: proc() {
	rect := get_message_box_rect()
	sys := &game.message_system

	if begin_window(rect, "message_box") == .Hovered {
		mouse_wheel_move := get_wheel_scroll()

		if mouse_wheel_move < 0 &&
		   sys.message_offset < queue.len(sys.message_queue) - get_max_visible_messages() {
			sys.message_offset += 1
		} else if mouse_wheel_move > 0 {
			sys.message_offset -= 1

			if sys.message_offset < 0 {
				sys.message_offset = 0
			}
		}
	}

	last_pos := Vec2{rect.x + MESSAGE_BOX_MARGIN, rect.y + MESSAGE_BOX_MARGIN}

	for message_index := sys.message_offset;
	    message_index < queue.len(sys.message_queue);
	    message_index += 1 {
		message := queue.get_ptr(&sys.message_queue, message_index)

		(last_pos.y + message.text_size.y < rect.y + rect.height) or_break

		draw_text(
			get_font_default(),
			message.msg,
			last_pos,
			MESSAGE_FONT_SIZE,
			MESSAGE_SPACING,
			WHITE,
		)

		last_pos.y += message.text_size.y + MESSAGE_BOX_MARGIN
	}

	end_window()
}

Message_System :: struct {
	message_queue:  queue.Queue(Message),
	message_offset: int,
}

Message :: struct {
	msg:       string,
	text_size: Vec2,
}

MESSAGE_FONT_SIZE :: 16
MESSAGE_SPACING :: 2

MESSAGE_BOX_WIDTH :: 350
MESSAGE_BOX_HEIGHT :: 144
MESSAGE_BOX_MARGIN :: 4

MESSAGE_CAPACITY :: 120
