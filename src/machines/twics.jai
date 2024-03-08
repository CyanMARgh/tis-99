Machine_TWICS :: struct {
	#as using _ := General_Machine.{label = LABEL_TWICS, type = .TWICS};
	vt=()=>VT.{
		c_draw = c_draw,
		iterate = iterate,
		is_task_satisfied = #bake_arguments is_task_satisfied_default(T = Machine_TWICS),
		reset = reset,
		is_tester = true,
		init_circuit = init_circuit
	};

	MODEL_NAME :: "TWICS";
	MAX_LINE_SIZE    :: 60;
	VISIBLE_ROWS_MAX :: 18;
	SIZE_X :: 2 + MAX_LINE_SIZE + 2;
	SIZE_Y :: 3 + VISIBLE_ROWS_MAX + 1;
	CIRCUIT_SIZE :: ivec2.{SIZE_X, SIZE_Y};

	using task : Task_TWICS;
	current_line_id, current_character_id : int;
	state : enum u8 {
		RUNNING;
		ERROR;
		HALT;
	};
}

draw_highlighted_text :: (canvas : *Canvas, _corner : ivec2, width_limit : int, height_limit : int, lines : []string, current_line_id : int, current_character_id : int, error : bool) {
	offset := height_limit * (min(lines.count  - 1, current_line_id) / height_limit);
	rows_to_show := min(height_limit, lines.count - offset);

	for yrel : 0..rows_to_show-1 {
		line_id := offset + yrel;
		corner := _corner + .{0, xx yrel};
		if line_id < current_line_id {
			c_printl_ascii(canvas, corner, MODE_OK, lines[line_id]);
		} else if line_id == current_line_id {
			line := tprint("% ", lines[line_id], " ");
			L := string.{data = line.data, count = current_character_id};
			C := string.{data = line.data + current_character_id, count = 1};
			R := string.{data = line.data + current_character_id + 1, count = line.count - current_character_id - 1};

			c_printl_ascii(canvas, corner, MODE_OK, L);
			c_printl_ascii(canvas, corner + .{xx current_character_id, 0}, ifx error then MODE_ERROR else MODE_WAIT, C);
			c_printl_ascii(canvas, corner + .{xx (1 + current_character_id), 0}, MODE_DEFAULT, R);
		} else {
			c_printl_ascii(canvas, corner, MODE_DEFAULT, lines[line_id]);			
		}
	}
}

make_machine_twics :: (_task : Task_TWICS) -> Machine_TWICS {
	return .{task = _task};
}

is_complete :: (using mt : Machine_TWICS) -> bool {
	return current_line_id == source_lines.count;
}

char_by_coord :: (lines : []string, line_id : int, character_id : int) -> u8 {
	character : u8;
	if character_id == lines[line_id].count {
		character = #char"\n";
	} else {
		character = lines[line_id][character_id];
	}
	return character;	
}

next_coord :: (lines : []string, line_id : *int, character_id : *int) {
	character_id.* += 1;
	if character_id.* > lines[line_id.*].count {
		character_id.* = 0;
		line_id.* += 1;
	}
}

#scope_file
init_circuit :: (circuit : *Circuit, _task : Task, _model_subid : int) {
	using machine := NewFill(make_machine_twics(_task.tasks_twics[_model_subid]));

	circuit.* = .{
		machine = machine,
		readonly = true,
		size = CIRCUIT_SIZE,
		pins = array_copy(Pin.[
			.{.{7, SIZE_Y - 1}, 0, false},
		])
	};
}

reset :: (machine : *General_Machine) {
	using machine_twics := cast(*Machine_TWICS)machine;
	state = .RUNNING;
	current_line_id, current_character_id = 0;
}
iterate :: (machine : *General_Machine, sender_circuit_id : s16, recievers : [4][]Address) {
	using machine_twics := cast(*Machine_TWICS)machine;
	if is_complete(machine_twics) {
		state = .HALT;
		return;
	}

	character := char_by_coord(source_lines, current_line_id, current_character_id);

	if broadcast(recievers[0], xx character, sender_circuit_id, 0) == {
	case .ERROR;
		state = .ERROR;
	case .WAIT;
	case .OK;
		next_coord(source_lines, *current_line_id, *current_character_id);
	}
}

c_draw :: (canvas : *Canvas, machine : *General_Machine, left_top : ivec2) {
	using machine_twics := cast(*Machine_TWICS)machine;
	c_print_ascii(
		canvas,
		left_top + .{1, 0}, 
		ifx state == .RUNNING then 
			MODE_WAIT
		else ifx state == .ERROR then 
			MODE_ERROR 
		else 
			MODE_OK,
		tprint("%; line = %; char = %", 
			state,
			current_line_id,
			current_character_id
		)
	);
	draw_highlighted_text(canvas, left_top + .{1, 2}, MAX_LINE_SIZE, VISIBLE_ROWS_MAX, source_lines, current_line_id, current_character_id, state == .ERROR);
}
