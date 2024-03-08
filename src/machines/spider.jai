Machine_SPIDER :: struct {
	#as using _ := General_Machine.{label = LABEL_SPIDER_8, type = .SPIDER};
	vt=()=>VT.{
		c_draw = c_draw,
		input_communicator = input_communicator,
		iterate = iterate,
		is_task_satisfied = is_task_satisfied,
		reset = reset,
		is_tester = true,
		destructor = destructor,
		init_circuit = init_circuit,

	};

	MODEL_NAME :: "The \"Spider\"";
	LABEL_OFFSET :: ivec2.{10, 0};
	CIRCUIT_SIZE :: ivec2.{61, 34};

	state : enum s8 {
		RANDOM_KEY :: 9;
		RAW_KEY :: 7;
		XORED_KEY :: 5;
		CAESAR_KEY :: 3;
		PARSE_NUMBER :: 1;
		DONE :: 0;
		FAILED :: 10;
	} = .RANDOM_KEY;

	random_key_state : struct {
		key : [6]s16;
		cursor_response := 0;
	};
	raw_key_state : struct {
		variants :: string.["The first stage has been completed.", "first stage of verification : done.", "Finished first stage."];

		key : string;
		cursor_request := 0;
		cursor_response := 0;
	};
	xored_key_state : struct {
		variants :: string.["second stage (xor-ed key) has been completed.", "XOR-key stage done.", "Finished second stage."];
		key : string;
		cursor_request := 0;
		cursor_response := 0;
	};
	caesar_key_state : struct {
		variants :: string.["third stage (caesar-encrypted key) has been completed.", "third stage completed.", "third stage finished."];
		key : string;
		offset := 0;
		cursor_request := 0;
		cursor_response := 0;
	};
	parse_number_state : struct {
		key_str := "";
		cursor_request := 0;
		key := 0;
	}
}

#scope_file
restart_cracking :: (using machine : *Machine_SPIDER) {
	state = .RANDOM_KEY;
	{
		using random_key_state;
		cursor_response = 0;
	}
	{
		using raw_key_state;
		cursor_request = 0;
		cursor_response = 0;		
	}
	{
		using xored_key_state;
		cursor_request = 0;
		cursor_response = 0;		
	}
	{
		using caesar_key_state;
		cursor_request = 0;
		cursor_response = 0;		
	}
	{
		using parse_number_state;
		cursor_request = 0;
	}
}
destructor :: (machine : *General_Machine) {
	using cast(*Machine_SPIDER)machine;
	free(parse_number_state.key_str);
}

init_circuit :: (circuit : *Circuit, _task : Task, _model_subid : int) {
	using machine := NewFill(Machine_SPIDER.{});
	circuit.* = Circuit.{
		machine = machine,
		readonly = true,
		size = CIRCUIT_SIZE,
		pins = array_copy(Pin.[
			.{.{CIRCUIT_SIZE.x - 1, 1}, 0, true},
			.{.{CIRCUIT_SIZE.x - 1, 3}, 1, true},
			.{.{CIRCUIT_SIZE.x - 1, 5}, 2, true},
			.{.{CIRCUIT_SIZE.x - 1, 7}, 3, true},
			.{.{CIRCUIT_SIZE.x - 1, 9}, 4, true},
			.{.{CIRCUIT_SIZE.x - 1,11}, 5, true},
			.{.{CIRCUIT_SIZE.x - 1,13}, 6, true},
			.{.{CIRCUIT_SIZE.x - 1,15}, 7, true},
			.{.{CIRCUIT_SIZE.x - 1,17}, 8, true},
			.{.{CIRCUIT_SIZE.x - 1,19}, 0,false},
		]),
		label_offset = LABEL_OFFSET
	};
}
is_task_satisfied :: (machine : *General_Machine) -> bool {
	using cast(*Machine_SPIDER)machine;
	return state == .DONE;
}
reset :: (machine : *General_Machine) {
	using machine_spider := cast(*Machine_SPIDER)machine;

	restart_cracking(machine_spider);
	for * random_key_state.key {
		it.* = xx((random_get() % 20) + 1);
	}
	raw_key_state.key = raw_key_state.variants[random_get() % 3];
	xored_key_state.key = xored_key_state.variants[random_get() % 3];
	caesar_key_state.key = caesar_key_state.variants[random_get() % 3];

	caesar_key_state.offset = xx(random_get() % 5 + 1);
	parse_number_state.key = xx(1000 + random_get() % 9000);
	safe_replace(*parse_number_state.key_str, sprint("%", parse_number_state.key));
	// log("keys: %, offset: %, the last one: % / %\n", random_key_state.key, caesar_key_state.offset, parse_number_state.key_str, parse_number_state.key);
}
iterate :: (machine : *General_Machine, sender_circuit_id : s16, recievers : [4][]Address) {
	using machine_spider := cast(*Machine_SPIDER)machine;

	try_broadcast :: (value : s16) -> bool #expand {
		if broadcast(recievers[0], value, sender_circuit_id, 0) == {
		case .ERROR;
			state = .FAILED;
		case .OK;
			return true;
		case .WAIT;
		}
		return false;
	}

	if #complete state == {
	case .RANDOM_KEY;
		try_broadcast(1);
	case .RAW_KEY;
		using raw_key_state;
		if cursor_request <= cursor_response && cursor_request < key.count {
			if try_broadcast(key[cursor_request]) cursor_request += 1;
		}
	case .XORED_KEY;
		using xored_key_state;
		if cursor_request <= cursor_response && cursor_request < key.count {
			if try_broadcast(key[cursor_request] ^ 0xff) cursor_request += 1;
		}
	case .CAESAR_KEY;
		using caesar_key_state;
		if cursor_request <= cursor_response && cursor_request < key.count {
			if try_broadcast(xx(key[cursor_request] + offset)) cursor_request += 1;
		}
	case .PARSE_NUMBER;
		using parse_number_state;
		if cursor_request < key_str.count {
			if try_broadcast(key_str[cursor_request]) cursor_request += 1;
		}	
	case .DONE;
	case .FAILED;
		try_broadcast(0);
	}
}

c_draw :: (canvas : *Canvas, machine : *General_Machine, left_top : ivec2) {
	using machine_spider := cast(*Machine_SPIDER)machine;

	if state == .FAILED {
		c_printl_ascii(canvas, left_top + LABEL_OFFSET, MODE_WAIT_INVERTED, LABEL_SPIDER_8);
	} else {
		c_printl_ascii(canvas, left_top + LABEL_OFFSET, MODE_ERROR_INVERTED, LABEL_SPIDER_8);
		one_substep_done := false;
		if #complete state == {
		case .RANDOM_KEY; one_substep_done = random_key_state.cursor_response > 0;
		case .RAW_KEY; one_substep_done = raw_key_state.cursor_response > 0;
		case .XORED_KEY; one_substep_done = xored_key_state.cursor_response > 0;
		case .CAESAR_KEY; one_substep_done = caesar_key_state.cursor_response > 0;
		case .PARSE_NUMBER;
		case .DONE;
		case .FAILED;
		}

		c_printl_ascii(canvas, left_top + LABEL_OFFSET, MODE_OK_INVERTED, LABELS_SPIDER[
			cast(int)state - cast(int)one_substep_done
		]);
	}


	// c_print_ascii(*canvas, it.zone.corner + .{2, 0}, MODE_CIRCUIT_ID, "[%]", formatInt(it_index, base=16, minimum_digits=2));
}

input_communicator :: (machine : *General_Machine, socket_id : s16, sender_occid : s16, only_ask : bool, value : s16) -> bool {
	using machine_spider := cast(*Machine_SPIDER)machine;
	if only_ask {
		assert(socket_id >= 0 && socket_id <= 8);
		if socket_id == 8 {
			return true;
		}
		if #complete state == {
		case .RANDOM_KEY;
			return socket_id == 2;
		case .RAW_KEY;
			return true;
		case .XORED_KEY;
			return true;
		case .CAESAR_KEY;
			return true;
		case .DONE;
			return false;
		case .FAILED;
			return false;
		case .PARSE_NUMBER;
			return socket_id == 0;
		}
	} else {
		if socket_id == 8 {
			restart_cracking(machine_spider);
			return false;
		}
		if #complete state == {
		case .RANDOM_KEY;
			using random_key_state;
			if value == key[cursor_response] {
				cursor_response += 1;
				if cursor_response == key.count {
					state = .RAW_KEY;
				}
			} else {
				state = .FAILED;
			}
		case .RAW_KEY;
			using raw_key_state;
			c := key[cursor_response];
			if c & 7 == socket_id && c == value {
				cursor_response += 1;
				if cursor_response == key.count {
					state = .XORED_KEY;
				}
			} else {
				state = .FAILED;
			}
		case .XORED_KEY;
			using xored_key_state;
			c := key[cursor_response];
			if c & 7 == socket_id && c == value {
				cursor_response += 1;
				if cursor_response == key.count {
					state = .CAESAR_KEY;
				}
			} else {
				state = .FAILED;
			}
		case .CAESAR_KEY;
			using caesar_key_state;
			c := key[cursor_response];
			if c & 7 == socket_id && c == value {
				cursor_response += 1;
				if cursor_response == key.count {
					state = .PARSE_NUMBER;
				}
			} else {
				state = .FAILED;
			}
		case .PARSE_NUMBER;
			using parse_number_state;
			if value == key {
				state = .DONE;
			} else {
				state = .FAILED;
			}
		case .DONE;
		case .FAILED;
		}
		return false;
	}
}
