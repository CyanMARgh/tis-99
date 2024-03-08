Machine_IO102 :: struct {
	#as using _ := General_Machine.{label = LABEL_IO102, type = .IO102};
	vt=()=>VT.{
		c_draw = c_draw,
		iterate = iterate,
		is_task_satisfied = #bake_arguments is_task_satisfied_default(T = Machine_IO102),
		reset = reset,
		is_tester = true,
		init_circuit = init_circuit
	};

	MODEL_NAME :: "io102";
	VISIBLE_ROWS_MAX :: 40;
	request_column : []s16;
	request_pointer : int;

	state : enum u8 {
		RUNNING;
		ERROR;
		HALT;
	};
}

#scope_file
make_machine_io102 :: (task_io102 : Task_IO102) -> Machine_IO102 {
	return .{request_column = task_io102.request_column};
}
init_circuit :: (circuit : *Circuit, _task : Task, _model_subid : int) {
	using machine := NewFill(make_machine_io102(_task.tasks_io102[_model_subid]));

	SIZE_Y :: 1 + 2 + VISIBLE_ROWS_MAX + 1;		
	SIZE_X := cast(s32)(2 + 6 + 2);

	circuit.* = .{
		machine = machine,
		readonly = true,
		size = .{SIZE_X, SIZE_Y},
		pins = array_copy(Pin.[
			.{.{SIZE_X - 1, 7}, 0, false },
		])
	};
}

is_complete :: (using mt : Machine_IO102) -> bool {
	return request_pointer == request_column.count;
}
reset :: (machine : *General_Machine) {
	using machine_io102 := cast(*Machine_IO102)machine;
	state = .RUNNING;
	request_pointer = 0;
}
iterate :: (machine : *General_Machine, sender_circuit_id : s16, recievers : [4][]Address) {
	using machine_io102 := cast(*Machine_IO102)machine;
	if state != .RUNNING return;
	if request_pointer >= request_column.count return;
	value := request_column[request_pointer];
	if broadcast(recievers[0], value, sender_circuit_id, 0) == {
	case .ERROR;
		state = .ERROR;
	case .WAIT;
	case .OK;
		request_pointer += 1;
	}
	if is_complete(machine_io102) state = .HALT;
}
c_draw :: (canvas : *Canvas, machine : *General_Machine, left_top : ivec2) {
	using machine_io102 := cast(*Machine_IO102)machine;
	offset := VISIBLE_ROWS_MAX * min((request_column.count - 1) / VISIBLE_ROWS_MAX, request_pointer / VISIBLE_ROWS_MAX);

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

	rows_to_show := min(VISIBLE_ROWS_MAX, request_column.count - offset);

	for yrel : 0..rows_to_show-1 {
		row := offset + yrel;
		mode := 
			ifx row > request_pointer then 
				MODE_DEFAULT
			else ifx row == request_pointer then
				ifx state == .ERROR then
					 MODE_ERROR 
				else
					MODE_WAIT
			else 
				MODE_OK;
		c_print_ascii(canvas, left_top + .{1, xx (yrel + 2)}, mode,
			pad(6, tprint("%", request_column[row]))
		);
	}
}
