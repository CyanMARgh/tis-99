Machine_Q5 :: struct {
	#as using _ := General_Machine.{label = LABEL_Q5, type = .Q5};
	vt=()=>VT.{
		c_draw = c_draw,
		input_communicator = input_communicator,
		iterate = iterate,
		reset = reset,
		destructor = destructor,
		compiler = prefill_q5,
		init_circuit = init_circuit
	};

	MODEL_NAME :: "Q5";
	MAX_COUNT :: 5;
	CIRCUIT_SIZE :: ivec2.{9, MAX_COUNT + 2};
	EDITOR_SIZE :: ivec2.{6, MAX_COUNT};

	prefilled_values : [..]s16;

	count : int;
	values : [MAX_COUNT]s16;
	target := 0;
}


#scope_file
make_machine_q5 :: () -> Machine_Q5 {
	return .{};
}
prefill_q5 :: (machine : *General_Machine, lines : []string) -> error:string {
	using machine_q5 := cast(*Machine_Q5)machine; 
	assert(lines.count <= 5);
	prefilled_values.count = 0;
	for lines {
		comm := parse_command(it);
		if comm.count > 1 {
			prefilled_values.count = 0;
			return tprint("invalid line: %", it);
		}
		if comm.count == 0 continue;
		val, ok := string_to_s16(comm[0]);
		if !ok {
			prefilled_values.count = 0;
			return tprint("can't parse int: %", val);
		}
		if prefilled_values.count >= 1 {
			prefilled_values.count = 0;
			return "can't predefine more than 1 number";
		}
		array_add(*prefilled_values, val);
	}
	return "";
}

init_circuit :: (circuit : *Circuit, _task : Task, _model_subid : int) {
	using machine := NewFill(make_machine_q5());

	circuit.* = .{
		machine = machine,
		editor = make_block_editor(EDITOR_SIZE),
		cost = 30,
		size = CIRCUIT_SIZE,
		draw_editor_during_simulation = false,
		pins = array_copy(Pin.[
			.{.{0, 2}, 0, true},
			.{.{CIRCUIT_SIZE.x - 1, 2}, 0, false},
			.{.{CIRCUIT_SIZE.x - 1, CIRCUIT_SIZE.y - 3}, 1, false},
		])
	};
}
reset :: (machine : *General_Machine) {
	using machine_q5 := cast(*Machine_Q5)machine;
	count = prefilled_values.count;
	for i : 0..count-1 {
		values[i] = prefilled_values[i];
	}
	target = 0;
}
destructor :: (machine : *General_Machine) {
	using machine_q5 := cast(*Machine_Q5)machine;
	array_free(prefilled_values);	
}
iterate :: (machine : *General_Machine, sender_circuit_id : s16, recievers : [4][]Address) {
	using machine_q5 := cast(*Machine_Q5)machine;
	if count == 0 return;

	if !recievers[0] && !recievers[1] {
		return;
	} else if recievers[0] && !recievers[1] {
		target = 0;
	} else if !recievers[0] && recievers[0] {
		target = 1;
	}

	if broadcast(recievers[target], values[0], sender_circuit_id, xx target) == {
	case .ERROR;
	case .WAIT;
	case .OK;
		for 0..count-2 {
			values[it] = values[it + 1];
		}
		count -= 1;
	}

	if recievers[0] && recievers[1] {
		target = 1 - target;
	}
}
c_draw :: (canvas : *Canvas, machine : *General_Machine, left_top : ivec2) {
	using machine_q5 := cast(*Machine_Q5)machine;
	for 0..count-1 {
		c_print_ascii(canvas, left_top + .{0, xx it}, MODE_DEFAULT, s16_to_str6(values[it]));
	}
}
input_communicator :: (machine : *General_Machine, socket_id : s16, sender_occid : s16, only_ask : bool, value : s16) -> bool {
	using cast(*Machine_Q5)machine;
	if only_ask {
		assert(socket_id == 0);
		return count < MAX_COUNT;
	} else {
		values[count] = value;
		count += 1;
		return false;
	}
}