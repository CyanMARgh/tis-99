Machine_IO013 :: struct {
	#as using _ := General_Machine.{label = LABEL_IO013, type = .IO013};
	vt=()=>VT.{
		c_draw = c_draw,
		input_communicator = input_communicator,
		iterate = iterate,
		is_task_satisfied = #bake_arguments is_task_satisfied_default(T = Machine_IO013),
		reset = reset,
		is_tester = true,
		init_circuit = init_circuit
	};

	MODEL_NAME :: "io013";
	VISIBLE_ROWS_MAX :: 40;

	using task : Task_IO013;

	response_pointer : int;

	error_at := -1;
	state : enum u8 {
		RUNNING;
		ERROR;
		HALT;
	};
}

#scope_file
make_machine_io013 :: (task_io013 : Task_IO013) -> Machine_IO013 {
	return .{task = task_io013};
}
init_circuit :: (circuit : *Circuit, _task : Task, _model_subid : int) {
	using machine := NewFill(make_machine_io013(_task.tasks_io013[_model_subid]));

	SIZE_Y :: 1 + 2 + VISIBLE_ROWS_MAX + 1;		
	circuit.* = .{
		machine = machine,
		readonly = true,
		size = .{xx (2 + 6 + 2), SIZE_Y},
		pins = array_copy(Pin.[
			.{.{0, 7}, 0, true },
		])
	};
}

is_complete :: (using mt : Machine_IO013) -> bool {
	return response_pointer == response_column.count;
}
reset :: (machine : *General_Machine) {
	using machine_io013 := cast(*Machine_IO013)machine;
	state = .RUNNING;
	response_pointer = 0;
}
iterate :: (machine : *General_Machine, sender_circuit_id : s16, recievers : [4][]Address) {
	using machine_io013 := cast(*Machine_IO013)machine;
	if is_complete(machine_io013) state = .HALT;
}
c_draw :: (canvas : *Canvas, general_machine : *General_Machine, left_top : ivec2) {
	using cast(*Machine_IO013) general_machine;
	offset := VISIBLE_ROWS_MAX * min((response_column.count - 1) / VISIBLE_ROWS_MAX, response_pointer / VISIBLE_ROWS_MAX);

	c_print_ascii(
		canvas,
		left_top + .{1, 0}, 
		ifx state == .RUNNING then 
			MODE_WAIT
		else ifx state == .ERROR then 
			MODE_ERROR 
		else 
			MODE_OK,
		tprint("%", state)
	);

	rows_to_show := min(VISIBLE_ROWS_MAX, response_column.count - offset);

	for yrel : 0..rows_to_show-1 {
		row := offset + yrel;
		mode := 
			ifx row > response_pointer then 
				MODE_DEFAULT
			else ifx row == response_pointer then
				ifx state == .ERROR then
					 MODE_ERROR 
				else
					MODE_WAIT
			else 
				MODE_OK;
		c_print_ascii(canvas, left_top + .{1, xx (yrel + 2)}, mode,
			pad(6, tprint("%", response_column[row]))
		);
	}
}

input_communicator :: (machine : *General_Machine, socket_id : s16, sender_occid : s16, only_ask : bool, value : s16) -> bool {
	using cast(*Machine_IO013)machine;
	if only_ask {
		assert(socket_id == 0); //TODO check socket id higher in generic way (maybe)
		if state != .RUNNING return false;
		return response_pointer < response_column.count;
	} else {
		if response_column[response_pointer] == value {
			response_pointer += 1;
		} else {
			state = .ERROR;
		}
		return false;
	}
}

