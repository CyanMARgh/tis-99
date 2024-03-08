Machine_JBMS32 :: struct {
	#as using _ := General_Machine.{label = LABEL_JBMS32, type = .JBMS32};
	vt=()=>VT.{
		c_draw = c_draw,
		input_communicator = input_communicator,
		iterate = iterate,
		reset = reset,
		init_circuit = init_circuit
	};

	MODEL_NAME :: "JBM S32";
	SIZE :: 32;
	CIRCUIT_SIZE :: ivec2.{SIZE * 2 + 2, SIZE + 2};
	INPUTS_COUNT :: 4;
	MAX_INPUT_BUFFER_SIZE :: 4;
	screen : [SIZE * SIZE]u8;

	q_xyc : [INPUTS_COUNT][3]SBDA(s16, MAX_INPUT_BUFFER_SIZE);
}

#scope_file
init_circuit :: (circuit : *Circuit, _task : Task, _model_subid : int) {
	using machine := NewFill(Machine_JBMS32.{});
	circuit.* = .{
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
			.{.{24, 0},11, true}
		])
	};
}

reset :: (machine : *General_Machine) {
	using machine_jbms32 := cast(*Machine_JBMS32)machine;
	machine_jbms32.* = .{};
}

iterate :: (machine : *General_Machine, sender_circuit_id : s16, recievers : [4][]Address) {
	assert(!recievers[0] && !recievers[1] && !recievers[2] && !recievers[3]);
	using cast(*Machine_JBMS32)machine;

	for i : 0..INPUTS_COUNT-1 {
		for q : q_xyc[i] {
			if !q.count continue i;
		}
		x := pop_front(*q_xyc[i][0]);
		y := pop_front(*q_xyc[i][1]);
		c := pop_front(*q_xyc[i][2]);
		if x >= 0 && x < SIZE && y >= 0 && y < SIZE {
			screen[x + y * SIZE] = xx (c & 0b111);
		}
	}
}
c_draw :: (canvas : *Canvas, machine : *General_Machine, left_top : ivec2) {
	using machine_jbms32 := cast(*Machine_JBMS32)machine;
	PALETTE :: Color.[.BLACK, .BRIGHT_RED, .BRIGHT_GREEN, .BRIGHT_YELLOW, .BRIGHT_BLUE, .BRIGHT_MAGENTA, .BRIGHT_CYAN, .BRIGHT_WHITE];
	PALETTE_CHARS :: #run map(PALETTE, (c) => make_char(#char" ", background = c));

	for y : 0..SIZE-1 {
		for x : 0..SIZE*2-1 {
			c_putchar(canvas, PALETTE_CHARS[screen[y * SIZE + x / 2]], left_top + .{xx x, xx y});
		}
	}
}

input_communicator :: (machine : *General_Machine, socket_id : s16, sender_occid : s16, only_ask : bool, value : s16) -> bool {
	using cast(*Machine_JBMS32)machine;
	if only_ask {
		assert(socket_id >= 0 && socket_id < INPUTS_COUNT * 3);
		return q_xyc[socket_id / 3][socket_id % 3].count < MAX_INPUT_BUFFER_SIZE;
	} else {
		array_add(*q_xyc[socket_id / 3][socket_id % 3], value);
		return false;
	}
}
