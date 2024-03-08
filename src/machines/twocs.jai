Machine_TWOCS :: struct {
	#as using _ := General_Machine.{label = LABEL_TWOCS, type = .TWOCS};
	vt=()=>VT.{
		c_draw = c_draw,
		input_communicator = input_communicator,
		iterate = iterate,
		is_task_satisfied = #bake_arguments is_task_satisfied_default(T = Machine_TWOCS),
		reset = reset,
		is_tester = true,
		init_circuit = init_circuit
	};

	MODEL_NAME :: "TWOCS";
	EDITOR_SIZE :: ivec2.{0, 0};
	MAX_LINE_SIZE    :: 60;
	VISIBLE_ROWS_MAX :: 18;
	SIZE_X :: 2 + MAX_LINE_SIZE + 2;
	SIZE_Y :: 3 + VISIBLE_ROWS_MAX + 1;
	CIRCUIT_SIZE :: ivec2.{SIZE_X, SIZE_Y};

	using task : Task_TWOCS;

	current_line_id, current_character_id : int;
	last_input : s16;

	state : enum u8 {
		RUNNING;
		ERROR;
		HALT;
	};
}

make_machine_twocs :: (task_twocs : Task_TWOCS) -> Machine_TWOCS {
	return .{task = task_twocs};
}

is_complete :: (using mt : Machine_TWOCS) -> bool {
	return current_line_id == result_lines.count;
}

#scope_file
init_circuit :: (circuit : *Circuit, _task : Task, _model_subid : int) {
	using machine := NewFill(make_machine_twocs(_task.tasks_twocs[_model_subid]));
	circuit.* = .{
		machine = machine,
		readonly = true,
		size = CIRCUIT_SIZE,
		pins = array_copy(Pin.[
			.{.{7, 0}, 0, true},
		])
	};
}

reset :: (machine : *General_Machine) {
	using machine_twocs := cast(*Machine_TWOCS)machine;
	state = .RUNNING;
	current_line_id, current_character_id = 0;
	last_input = 0;
}

iterate :: (machine : *General_Machine, sender_circuit_id : s16, recievers : [4][]Address) {
	using machine_twocs := cast(*Machine_TWOCS)machine;
	if is_complete(machine_twocs) state = .HALT;
}
c_draw :: (canvas : *Canvas, machine : *General_Machine, left_top : ivec2) {
	using machine_twocs := cast(*Machine_TWOCS)machine;

	c_print_ascii(
		canvas,
		left_top + .{1, 0}, 
		ifx state == .RUNNING then 
			MODE_WAIT
		else ifx state == .ERROR then 
			MODE_ERROR 
		else 
			MODE_OK,
		pad(7, tprint("%", state))
	);
	if current_line_id > 0 || current_character_id > 0 {
		lis := s16_to_str6(last_input);
		ascii := last_input >= #char"!" && last_input <= #char"~";
		char_str := string.{count = 1, data = xx *last_input};
		c_print_ascii(
			canvas,
			left_top + .{9, 0}, 
			ifx state != .ERROR then MODE_OK else MODE_ERROR,
			ifx ascii
				tprint("last input = % / %", lis, char_str)
			else
				tprint("last input = %", lis)
		);

	}
	draw_highlighted_text(canvas, left_top + .{1, 2}, MAX_LINE_SIZE, VISIBLE_ROWS_MAX, result_lines, current_line_id, current_character_id, state == .ERROR);
}

input_communicator :: (machine : *General_Machine, socket_id : s16, sender_occid : s16, only_ask : bool, value : s16) -> bool {
	using cast(*Machine_TWOCS)machine;
	if only_ask {
		assert(socket_id == 0);
		return state == .RUNNING && current_line_id < result_lines.count;
	} else {
		character := char_by_coord(result_lines, current_line_id, current_character_id);
		if character == value {
			last_input = value;
			next_coord(result_lines, *current_line_id, *current_character_id);
		} else {
			state = .ERROR;
		}

		return false;
	}
}
