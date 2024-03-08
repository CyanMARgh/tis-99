Machine_SM255 :: struct {
	#as using _ := General_Machine.{label = LABEL_SM255, type = .SM255};
	vt=()=>VT.{
		c_draw = c_draw,
		input_communicator = input_communicator,
		iterate = iterate,
		reset = reset,
		init_circuit = init_circuit
	};

	MODEL_NAME :: "S.M. 255";
	SIZE_Y :: 1 + 32 + 1;
	SIZE_X :: 1 + 8 * 7;
	CIRCUIT_SIZE :: ivec2.{SIZE_X, SIZE_Y};
	EDITOR_SIZE :: ivec2.{0, 0};

	values : [256]s16;
	#place values; _ : [255]s16;
	sp : s16;
}


#scope_file
init_circuit :: (circuit : *Circuit, _task : Task, _model_subid : int) {
	using machine := New(Machine_SM255);

	center :s32= SIZE_X / 2;
	circuit.* = .{
		editor = make_block_editor(EDITOR_SIZE),
		machine = machine,
		readonly = true,
		cost = 60,
		size = CIRCUIT_SIZE,
		pins = array_copy(Pin.[
			.{.{6,                   0}, 0, true },
			.{.{center - 2, SIZE_Y - 1}, 0, false},
			.{.{center - 1, SIZE_Y - 1}, 1, false},
			.{.{center + 0, SIZE_Y - 1}, 2, false},
			.{.{center + 1, SIZE_Y - 1}, 3, false},
		])
	};
}
valid :: (using machine_sm255 : Machine_SM255) -> bool {
	return sp <= 255 && sp >= 0;
}

reset :: (machine : *General_Machine) {
	using machine_sm255 := cast(*Machine_SM255)machine;
	machine_sm255.* = .{};
}
iterate :: (machine : *General_Machine, sender_circuit_id : s16, recievers : [4][]Address) {
	using machine_sm255 := cast(*Machine_SM255)machine;
	if sp < 0 || sp > 255 return;
	for i : 0..3 {
		if sp <= 0 break;
		if broadcast(recievers[i], values[sp - 1], sender_circuit_id, xx i) == {
		case .ERROR;
		case .WAIT;
		case .OK;
			sp -= 1;
		}
	}
}
c_draw :: (canvas : *Canvas, machine : *General_Machine, left_top : ivec2) {
	using machine_sm255 := cast(*Machine_SM255)machine;

	print_cell :: (i : int, mode : Graphics_Mode) #expand {
		offset := ivec2.{xx((i / 32) * 7), xx(i % 32)};
		corner := left_top + offset;
		line := pad(6, tprint("%", values[i]));
		c_print_ascii(canvas, corner, mode, line);
		// log("line(%), at % + %, %\n", i, left_top, offset, line);
	}
	// assert(false);
	for 0..min(sp, 255)-1 {
		print_cell(it, MODE_DEFAULT);
	}
	print_cell(255, ifx valid(machine_sm255) then MODE_OK else MODE_ERROR);
}
input_communicator :: (machine : *General_Machine, socket_id : s16, sender_occid : s16, only_ask : bool, value : s16) -> bool {
	using cast(*Machine_SM255)machine;
	if only_ask {
		assert(socket_id == 0);
		return true;
	} else {
		if sp < 255 {
			values[sp] = value;
			sp += 1;
		} else if sp == 255 {
			sp = 256;
		}
		return false;
	}
}