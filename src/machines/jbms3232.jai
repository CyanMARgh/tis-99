Machine_JBMS3232 :: struct {
	#as using _ := General_Machine.{label = LABEL_JBMS3232, type = .JBMS3232};
	vt=()=>VT.{
		c_draw = c_draw,
		input_communicator = input_communicator,
		iterate = iterate,
		is_task_satisfied = is_task_satisfied,
		reset = reset,
		is_tester = true,
		init_circuit = init_circuit
	};

	MODEL_NAME :: "JBM S3232";
	SIZE :: 32;
	CIRCUIT_SIZE :: ivec2.{SIZE * 4 + 3, SIZE + 2};
	INPUTS_COUNT :: 4;
	MAX_INPUT_BUFFER_SIZE :: 4;

	using task : Task_JBMS3232;

	current_frame := 0;
	diff := 0;
	screen : [SIZE * SIZE]u8;
	q_xyc : [INPUTS_COUNT][3]SBDA(s16, MAX_INPUT_BUFFER_SIZE);
}


#scope_file
make_machine_jbms3232 :: (task_jbms3232 : Task_JBMS3232) -> Machine_JBMS3232 {
	return .{task = task_jbms3232};
}
init_circuit :: (circuit : *Circuit, _task : Task, _model_subid : int) {
	using machine := NewFill(make_machine_jbms3232(_task.tasks_jbms3232[_model_subid]));
	circuit.* = Circuit.{
		machine = machine,
		readonly = true,
		size = CIRCUIT_SIZE,
		pins = array_copy(Pin.[
			.{.{ 7, 0}, 0, true},
			.{.{ 8, 0}, 1, true},
			.{.{ 9, 0}, 2, true},
			.{.{12, 0}, 3, true},
			.{.{13, 0}, 4, true},
			.{.{14, 0}, 5, true},
			.{.{17, 0}, 6, true},
			.{.{18, 0}, 7, true},
			.{.{19, 0}, 8, true},
			.{.{22, 0}, 9, true},
			.{.{23, 0},10, true},
			.{.{24, 0},11, true},
			.{.{ 0, 3},12, true}
		])
	};
}
is_task_satisfied :: (machine : *General_Machine) -> bool {
	using cast(*Machine_JBMS3232)machine;
	return current_frame == frames.count;
}
compare_current_frame :: (using machine : *Machine_JBMS3232) {
	diff = 0;
	for i : 0..SIZE*SIZE-1 {
		diff += xx (screen[i] != frames[current_frame][i]);
	}
}
reset :: (machine : *General_Machine) {
	using machine_jbms3232 := cast(*Machine_JBMS3232)machine;
	_task := task;
	machine_jbms3232.* = .{};
	task = _task;
	compare_current_frame(machine_jbms3232);
}
iterate :: (machine : *General_Machine, sender_circuit_id : s16, recievers : [4][]Address) {
	assert(!recievers[0] && !recievers[1] && !recievers[2] && !recievers[3]);
	using machine_jbms3232 := cast(*Machine_JBMS3232)machine;

	for i : 0..INPUTS_COUNT-1 {
		for q : q_xyc[i] {
			if !q.count continue i;
		}
		x := pop_front(*q_xyc[i][0]);
		y := pop_front(*q_xyc[i][1]);
		c := pop_front(*q_xyc[i][2]) & 0b111;
		if x >= 0 && x < SIZE && y >= 0 && y < SIZE {
			I := x + y * SIZE;
			if current_frame < frames.count {
				old_pixel := screen[I];
				target_pixel := frames[current_frame][I];

				diff += (ifx c != target_pixel then 1) - (ifx old_pixel != target_pixel then 1);
				assert(diff >= 0);
			}
			// log("+pixel: [%,%] <- %\n", x, y, c);
			screen[I] = xx c;
		}
	}
}

DONE_FRAME :: u8.[
	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
	0,0,1,1,1,1,0,0,0,2,2,2,0,0,3,0,0,0,3,0,4,4,4,4,0,0,0,0,0,0,0,0,
	0,0,1,0,0,0,1,0,2,0,0,0,2,0,3,3,0,0,3,0,4,0,0,0,0,0,0,0,0,0,0,0,
	0,0,1,0,0,0,1,0,2,0,0,0,2,0,3,0,3,0,3,0,4,4,4,4,0,0,0,0,0,0,0,0,
	0,0,1,0,0,0,1,0,2,0,0,0,2,0,3,0,0,3,3,0,4,0,0,0,0,0,0,0,0,0,0,0,
	0,0,1,1,1,1,0,0,0,2,2,2,0,0,3,0,0,0,3,0,4,4,4,4,0,0,0,0,0,0,0,0,
	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
];
c_draw :: (canvas : *Canvas, machine : *General_Machine, left_top : ivec2) {
	using machine_jbms3232 := cast(*Machine_JBMS3232)machine;
	PALETTE :: Color.[.BLACK, .BRIGHT_RED, .BRIGHT_GREEN, .BRIGHT_YELLOW, .BRIGHT_BLUE, .BRIGHT_MAGENTA, .BRIGHT_CYAN, .BRIGHT_WHITE];
	PALETTE_CHARS :: #run map(PALETTE, (c) => make_char(#char" ", background = c));

	target_screen := ifx current_frame < frames.count then frames[current_frame] else DONE_FRAME;
	// target_screen := DONE_FRAME;
	for y : 0..SIZE-1 {
		for x : 0..SIZE*2-1 {
			c_putchar(canvas, PALETTE_CHARS[target_screen[y * SIZE + x / 2]], left_top + .{xx x, xx y});
		}
	}
	for y : 0..SIZE-1 {
		for x : 0..SIZE*2-1 {
			c_putchar(canvas, PALETTE_CHARS[screen[y * SIZE + x / 2]], left_top + .{xx (x + SIZE * 2 + 1), xx y});
		}
	}
	for y : 0..SIZE-1 {
		c_putchar(canvas, .{code = #char"|", mode = MODE_DEFAULT}, left_top + .{xx (SIZE * 2), xx y});
	}
}

input_communicator :: (machine : *General_Machine, socket_id : s16, sender_occid : s16, only_ask : bool, value : s16) -> bool {
	using machine_jbms3232 := cast(*Machine_JBMS3232)machine;
	if only_ask {
		assert(socket_id >= 0 && socket_id <= INPUTS_COUNT * 3);
		assert(current_frame <= frames.count);
		if current_frame == frames.count return false;
		if socket_id < INPUTS_COUNT * 3 {
			return q_xyc[socket_id / 3][socket_id % 3].count < MAX_INPUT_BUFFER_SIZE;
		} else {
			return true;
		}
	} else {
		// log("input: pin #% <- %\n", socket_id, value);
		if socket_id < INPUTS_COUNT * 3 {
			array_add(*q_xyc[socket_id / 3][socket_id % 3], value);
		} else {
			if current_frame < frames.count && diff == 0 {
				current_frame += 1;
				if current_frame < frames.count {
					compare_current_frame(machine_jbms3232);
				}
			}			
		}
		return false;
	}
}
