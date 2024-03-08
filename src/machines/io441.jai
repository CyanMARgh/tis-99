Machine_IO441 :: struct {
	#as using _ := General_Machine.{label = LABEL_IO441, type = .IO441};
	vt=()=>VT.{
		c_draw = c_draw,
		input_communicator = input_communicator,
		iterate = iterate,
		destructor = destructor,
		is_task_satisfied = #bake_arguments is_task_satisfied_default(T = Machine_IO441),
		reset = reset,
		is_tester = true,
		init_circuit = init_circuit
	};
	VISIBLE_ROWS_MAX :: 40;
	MODEL_NAME :: "io441";
	SIZE_Y :: 1 + 2 + VISIBLE_ROWS_MAX + 1;

	using task : Task_IO441;

	request_pointers : []int;
	response_pointers : []int;

	error_at := -1;
	state : enum u8 {
		RUNNING;
		ERROR;
		HALT;
	};
}


#scope_file
make_machine_io441 :: (task_io441 : Task_IO441) -> Machine_IO441 {
	using result := Machine_IO441.{task = task_io441};
	request_pointers = NewArray(request_columns.count, int);
	response_pointers = NewArray(response_columns.count, int);
	return result;
}
init_circuit :: (circuit : *Circuit, _task : Task, _model_subid : int) {
	using machine_io441 := make_machine_io441(_task.tasks_io441[_model_subid]);
	SIZE_X := cast(s32)(2 + (7 * request_columns.count - 1) + 1 + (7 * response_columns.count - 1) + 2);
	SIZE_X = max(SIZE_X, 12);

	circuit.* = .{
		machine = NewFill(machine_io441),
		readonly = true,
		size = .{SIZE_X, SIZE_Y},
		pins = array_copy(Pin.[
			.{.{SIZE_X - 1,       1}, 0, false },
			.{.{SIZE_X - 1,       3}, 1, false },
			.{.{SIZE_X - 1,       5}, 2, false },
			.{.{SIZE_X - 1,       7}, 3, false },
			.{.{SIZE_X - 1,SIZE_Y-8}, 0, true  },
			.{.{SIZE_X - 1,SIZE_Y-6}, 1, true  },
			.{.{SIZE_X - 1,SIZE_Y-4}, 2, true  },
			.{.{SIZE_X - 1,SIZE_Y-2}, 3, true  }
		])
	};
}
is_complete :: (using mt : Machine_IO441) -> bool {
	for response_columns {
		if response_pointers[it_index] != it.count return false;
	}
	return true;
}

reset :: (machine : *General_Machine) {
	using machine_io441 := cast(*Machine_IO441)machine;
	state = .RUNNING;
	for * request_pointers it.* = 0;
	for * response_pointers it.* = 0;
	error_at = -1;
}
destructor :: (machine : *General_Machine) {
	using cast(*Machine_IO441)machine;
	array_free(request_pointers);
	array_free(response_pointers);
}
iterate :: (machine : *General_Machine, sender_circuit_id : s16, recievers : [4][]Address) {
	using machine_io441 := cast(*Machine_IO441)machine;

	for column, i : request_columns {
		if request_pointers[i] >= column.count continue;
		value := column[request_pointers[i]];
		if broadcast(recievers[i], value, sender_circuit_id, xx i) == {
		case .ERROR;
			state = .ERROR;
		case .WAIT;
		case .OK;
			request_pointers[i] += 1;
		}
	}
	if is_complete(machine_io441) state = .HALT;
}
c_draw :: (canvas : *Canvas, machine : *General_Machine, left_top : ivec2) {
	using machine_io441 := cast(*Machine_IO441)machine;
	is_empty_row :: (using machine_io441 : Machine_IO441, yrel : int) -> bool #expand {
		for request_columns {
			y := `view_offsets_requests[it_index] + yrel; 
			if it && it.count > y return false;
		}
		for response_columns {
			y := `view_offsets_responses[it_index] + yrel; 
			if it && it.count > y return false;
		}
		return true;
	}

	view_offsets_requests := NewArray(request_columns.count, int,, temp);
	view_offsets_responses := NewArray(response_columns.count, int,, temp);

	for *o, i : view_offsets_requests {
		o.* = VISIBLE_ROWS_MAX * min((request_columns[i].count - 1) / VISIBLE_ROWS_MAX, request_pointers[i] / VISIBLE_ROWS_MAX);
	}
	for *o, i : view_offsets_responses {
		o.* = VISIBLE_ROWS_MAX * min((response_columns[i].count - 1) / VISIBLE_ROWS_MAX, response_pointers[i] / VISIBLE_ROWS_MAX);
	}

	print_cell :: (column : []s16, result_mode : bool) #expand {
		corner := left_top + .{xx `offset, xx (`yrel + 2)};
		mode := MODE_DEFAULT;
		line := " ---- ";

		if column && column.count > `y {
			mode = 
				ifx `y > `p then 
					MODE_DEFAULT
				else ifx `y == `p then
					ifx result_mode && state == .ERROR && error_at == `it_index then
						 MODE_ERROR 
					else
						MODE_WAIT
				else 
					MODE_OK;
			line = pad(6, tprint("%", column[`y]));
		}
		c_print_ascii(canvas, corner, mode, line);
		`offset += 7;
	}

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

	for yrel : 0..Machine_IO441.VISIBLE_ROWS_MAX-1 {
		if is_empty_row(machine_io441, yrel) break;
		offset := 1;
		for tdi : request_columns {
			y := view_offsets_requests[it_index] + yrel; 
			p := request_pointers[it_index];
			print_cell(tdi, false);
		}
		c_print_ascii(canvas, left_top + .{xx (offset - 1), xx (yrel + 2)}, MODE_DEFAULT, "|");
		for rdi : response_columns {
			y := view_offsets_responses[it_index] + yrel; 
			p := response_pointers[it_index];
			print_cell(rdi, true);
		}
	}
}

input_communicator :: (machine : *General_Machine, socket_id : s16, sender_occid : s16, only_ask : bool, value : s16) -> bool {
	using cast(*Machine_IO441)machine;
	if only_ask {
		if state != .RUNNING return false;
		assert(socket_id >= 0 && socket_id < 4);
		return
			socket_id < response_pointers.count &&
			response_pointers[socket_id] < response_columns[socket_id].count;
	} else {
		if response_columns[socket_id][response_pointers[socket_id]] == value {
			response_pointers[socket_id] += 1;
		} else {
			state = .ERROR;
			error_at = socket_id;
		}
		return false;
	}
}

