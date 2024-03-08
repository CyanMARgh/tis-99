Pin :: struct {
	position : ivec2;
	socket : s16;
	type : bool; // true - IN, false - OUT 
}
Circuit :: struct {
  	using zone : Ibox2;
	pins : []Pin;
	target_circuits : [4][]Address;

	// TODO must be Machine_Type
	// |
	// |
	// V
	model_id, model_subid : int;
	cost : int;
	readonly := false;
	draw_editor_during_simulation := true;
	editor : Block_Editor;
	editor_offset  := ivec2.{0, 0};
	machine : *General_Machine;
	machine_offset := ivec2.{1, 1};
	label_offset := ivec2.{0, 0};
}
deinit :: (using circuit : *Circuit) {
	for * target_circuits {
		array_free(it.*);
	}
	deinit(*editor);
	array_free(pins);
	if machine {
		deinit(machine);
		free(machine);
	}
}

Breadboard :: struct {
	state : enum u8 {
		DEFAULT;
		SHOW_TASK;
		CIRCUITS_EDIT;
		ADD_WIRE;
		ASSEMBLY_EDIT;
	} = .DEFAULT;

	using,only(size) wiremap : Wiremap;
	task : Task;

	circuits : [..]Circuit;
	cursor_position : ivec2;
	canvas : Canvas;

	task_name := "";

	untouched_after_finish := false;
	circuits_edit_info : struct {
		circuits_edit_state : enum u8 {
			FREE;
			PLACE;
			SELECT;
			MOVE;
		};

		new_circuit : Circuit;
		saved_position : ivec2;
		saved_index : int;
		selected := 0;
	};
	using add_wire_info : struct {
		wire_brush : Wire;
		disable_wire_edit := false;		
	};
	assembly_edit_info : struct {
		error_message := "";
		error_source := 0;

		paused := false;
		simulation_speed := 4;

		target := 0;
		sim_time := 0;
		state : enum u8 {
			EDIT;
			SIMULATE;
			SHOW_RESULT;
		};
	};
	show_task_info : struct {
		lines : []string;
		offset : int;
	}
}
get_cost :: (using breadboard : Breadboard) -> int {
	total := 0;
	for circuits {
		total += it.cost;
	}
	total += wiremap.cost;
	return total;
}
Result_Info :: struct {
	cost := 420;
	lines := 69;
	instrctions := 100500;
	sim_time := 1_000_000;	
}

init :: (using breadboard : *Breadboard, _size : ivec2, _task_name : string) -> error:string {
	error : string;

	task_path := task_file(_task_name);
	task, error = load_task(task_path);
	if error {
		log("failed to load task file (%): %\n", task_path, error);
		return error;
	}
	safe_replace(*task_name, copy_string(_task_name));
	init(*wiremap, _size);
	resize(*canvas, size);
	return "";
}
deinit :: (using breadboard : *Breadboard) {
	deinit(*canvas);
	deinit(*wiremap);
	free(task_name);
	deinit(*task);

	{
		using circuits_edit_info;
		deinit(*new_circuit);
	}

	for circuits {
		deinit(*it);
	}
	array_free(circuits);

	safe_replace(*show_task_info.lines, .[]);
	free(assembly_edit_info.error_message);
}

draw_assembly_edit_mode :: (using breadboard : *Breadboard, c : Circuit, is_selected : bool) {
	charset := ifx is_selected then box_style_active else box_style_passive;
	c_box(*canvas, c.zone, charset);
	c.machine.vt().c_draw(*canvas, c.machine, c.corner + c.machine_offset);
	if assembly_edit_info.state == .SIMULATE {
		if c.draw_editor_during_simulation {
			c_draw(*canvas, c.editor, c.corner, true, current_line(c.machine), charset = charset);
		}
	} else {
		c_draw(*canvas, c.editor, c.corner, false, -1, charset = charset);
	}
}

draw_inner :: (using breadboard : *Breadboard, refresh_zone : Ibox2) {
	color_at :: (pos : ivec2) -> Graphics_Mode #expand {
		return get_wire_char(wiremap, pos).mode;
	}

	DEFAULT_FILLER :: #run make_char(utf8(" "));
	BACKGROUND_FILLER :: #run make_char(#char" ");

	draw_circuit_base :: (c : Circuit, filler : Char) #expand {
		if !intersects(refresh_zone, c.zone) return;
		style := box_style_passive;
		style.c = filler.code;
		style.mode_border = filler.mode;
		style.mode_space = filler.mode;
		c_box(*canvas, c.zone, style);
		// _name := c.machine.name;
		// _name.count = min(_name.count, c.zone.width - 3);
		_label := limit_by_width(c.machine.label, c.zone.width,, temp);
		c_print_ascii(*canvas, c.zone.corner + c.label_offset + .{1, 1}, filler.mode, _label);
		// log("name = %\n", _name)
		cost_line := ifx c.cost then tprint("% u.", c.cost) else "free";
		c_print_ascii(*canvas, c.zone.corner + ivec2.{xx(c.zone.width - 2 - cost_line.count), c.zone.height - 2}, MODE_CIRCUIT_COST, cost_line);
	}
	draw_circuit_pins :: (c : Circuit) #expand {
		if !intersects(refresh_zone, c.zone) return;
		for pin : c.pins {
			p := c.zone.corner + pin.position;
			c_putchar(*canvas, .{code = xx ifx pin.type #char"%" else #char"&", mode = color_at(p)}, p);
		}
	}

	draw_circuits_base :: (filler : Char) #expand {
		for circuits draw_circuit_base(it, filler);
	}
	draw_circuits_pins :: () #expand {
		for circuits draw_circuit_pins(it);
	}

	draw_circuit :: (c : Circuit, filler : Char) #expand {
		draw_circuit_base(c, filler);
		draw_circuit_pins(c);
	}
	draw_ids :: () #expand {
		for circuits {
			c_print_ascii(*canvas, it.zone.corner + .{2, 0}, MODE_CIRCUIT_ID, "[%]", formatInt(it_index, base=16, minimum_digits=2));

			if it.machine.vt().is_tester {
				c_print_ascii(*canvas, it.zone.corner + .{1, it.zone.height - 1}, MODE_CIRCUIT_ID, "<%>", it.model_subid);
			}
		}
	}

	if state == .SHOW_TASK return;
	resize(*canvas, size);
	c_clear(*canvas, make_char(#char"."), partial = true, refresh_zone);

	if state == .ADD_WIRE {
		draw_circuits_base(BACKGROUND_FILLER);
	}
	if state == .ADD_WIRE {
		draw_ids();
	}
	draw(*canvas, wiremap, partial = true, refresh_zone);
	if state != .ADD_WIRE && state != .ASSEMBLY_EDIT draw_circuits_base(DEFAULT_FILLER);
	if state == .ASSEMBLY_EDIT {
		for c, i : circuits {
			draw_assembly_edit_mode(breadboard, c, i == assembly_edit_info.target);
		}
	}

	draw_circuits_pins();
	if state != .ADD_WIRE {
		draw_ids();
	}

	if #complete state == {
	case .DEFAULT;
		c_putchar(*canvas, make_char(#char"@", foreground = .BLACK, background = .BRIGHT_WHITE), cursor_position);

	case .CIRCUITS_EDIT;
		using circuits_edit_info;
		if circuits_edit_state == {
		case .MOVE; #through;
		case .PLACE;
			valid := can_place_circuit(breadboard);
			draw_circuit(new_circuit, make_char(#char"+", foreground = .BLACK, background = ifx valid then .GREEN else .RED));
		case .FREE;
			back_color := ifx can_remove_circuit(breadboard) then Color.BRIGHT_RED else .BRIGHT_BLUE;
			c_putchar(*canvas, make_char(#char"R", foreground = .BLACK, background = back_color), cursor_position);
		case .SELECT;
		}

	case .ADD_WIRE;
		c_putchar(*canvas, .{code = xx ifx disable_wire_edit then #char"w" else #char"W", mode = get_wire_color(wire_brush)}, cursor_position);

	// case .REMOVE_CIRCUIT;
	// 	c_putchar(*canvas, make_char(#char"R", background = ifx can_remove_circuit(breadboard) then .RED else .BLACK), cursor_position);

	case .ASSEMBLY_EDIT;
		using assembly_edit_info;
		if state == .EDIT && !circuits[target].readonly {
			c_draw_cursor(*canvas, circuits[target].editor, circuits[target].corner);
		}
		if error_message {
			z := circuits[error_source].zone;
			c_print_ascii(
				*canvas, 
				z.corner + .{0, z.height - 1}, 
				MODE_ERROR,
				limit_by_width(error_message, z.width,, temp)
			);
		}
	case .SHOW_TASK;
	}
}

simulate_one_tick :: (using breadboard : *Breadboard, target_solution_info : *Solution_Info, target_level_info : *Level_Info) {
	if !(state == .ASSEMBLY_EDIT && assembly_edit_info.state == .SIMULATE) return;
	// using assembly_edit_info;
	if is_task_completed(breadboard) {
		target_solution_info.cost = get_cost(breadboard);
		target_solution_info.time = assembly_edit_info.sim_time;
		target_solution_info.state = .SOLVED;
		refresh(target_level_info);

		assembly_edit_info.state = .SHOW_RESULT;
		untouched_after_finish = true;
	}
	for c, i : circuits {
		iterate(c.machine, xx i, c.target_circuits);
	}
	assembly_edit_info.sim_time += 1;
}
simulate :: (using breadboard : *Breadboard, frame_mod_1m : int, target_solution_info : *Solution_Info, target_level_info : *Level_Info) {
	if state == {
	case .ASSEMBLY_EDIT;
		using assembly_edit_info;
		if #complete state == {
		case .SIMULATE;
			SIMULATION_DELAY :: 64;
			if !paused {
				if simulation_speed > SIMULATION_DELAY {
					for 1..simulation_speed / SIMULATION_DELAY {
						simulate_one_tick(breadboard, target_solution_info, target_level_info);
					}
				} else {
					if (frame_mod_1m + 1) % (SIMULATION_DELAY / simulation_speed) == 0 {
						simulate_one_tick(breadboard, target_solution_info, target_level_info);
					}
				}
			}
		case .EDIT;
		case .SHOW_RESULT;
		}
	}
}

draw_to_canvas :: (target_canvas : *Canvas, using breadboard : Breadboard, view_offset : ivec2) {
	// log("draw_to_canvas begin, offset: %\n", view_offset);
	if state != .SHOW_TASK {
		{
			style := box_style_passive;
			style.c = 0;
			c_box(
				target_canvas,
				.{corner = -view_offset - .{1, 1}, size = breadboard.size + .{2, 2}},
				style
			);			
		}
		{
			MODE :: MODE_BORDER_NUMBERS;
			WFREQ, HFREQ :: BORDER_NUMBERS_WFREQ, BORDER_NUMBERS_HFREQ;
			for x : 1..breadboard.size.x/WFREQ {
				char := Char.{code = xx(#char"0" + x % 10), mode = MODE};
				c_putchar(target_canvas, char, ivec2.{-1 + x * WFREQ, -1} - view_offset);
				c_putchar(target_canvas, char, ivec2.{-1 + x * WFREQ, breadboard.size.y} - view_offset);
			}
			for y : 1..breadboard.size.y/HFREQ {
				char := Char.{code = xx(#char"0" + y % 10), mode = MODE};
				c_putchar(target_canvas, char, ivec2.{-1, -1 + y * HFREQ} - view_offset);
				c_putchar(target_canvas, char, ivec2.{breadboard.size.x, -1 + y * HFREQ} - view_offset);
			}
		}
		c_draw_canvas_view(target_canvas, canvas, .{}, .{size = target_canvas.size, corner = view_offset});
	}
	if #complete state == {
	case .DEFAULT;
	case .CIRCUITS_EDIT;
		using circuits_edit_info;
		if #complete circuits_edit_state == {
		case .FREE;
		case .PLACE;
		case .MOVE;
		case .SELECT;
			lines_count := total_submodel_count(task);

			popup_size := ivec2.{20, xx(lines_count + 2)};
			corner := (target_canvas.size - popup_size) / 2;
			popup_zone := Ibox2.{size = popup_size, corner = corner};
			c_box(target_canvas, popup_zone);

			for 0..lines_count-1 {
				model, submodel, ok := model_and_submodel_by_line(task, it);
				assert(ok); 

				mode := ifx it == selected then MODE_DEFAULT_INVERTED else MODE_DEFAULT;
				c_print_ascii(target_canvas, corner + .{1, xx(1 + it)}, mode, model_name_line(task, it));
			}
		}

	case .ADD_WIRE;
	case .ASSEMBLY_EDIT;
		using assembly_edit_info;
		if #complete state == {
		case .EDIT;
		case .SIMULATE;
		case .SHOW_RESULT;
			popup_size := ivec2.{xx(23 + MAX_FILE_NAME_SIZE), 7};
			corner := (target_canvas.size - popup_size) / 2;
			popup_zone := Ibox2.{size = popup_size, corner = corner};
			c_box(target_canvas, popup_zone);
			c_print_ascii(
				target_canvas,
				corner + .{1, 1}, 
				MODE_RESULT_TEXT,
				"Congratulations!\nyou finished level \"%\"\ntime = % iterations\ncost = % units\npress ESC or ENTER to return to edit",
				task_name, assembly_edit_info.sim_time, get_cost(breadboard)
			);
		}
	case .SHOW_TASK;
		using show_task_info;
		for y : 0..min(lines.count - offset, canvas.size.y)-1 {
			c_print_ascii(target_canvas, .{0, xx y}, MODE_DEFAULT, lines[y + offset]);
		}
	}
	// log("draw_to_canvas end\n");
}

can_place_circuit :: (using breadboard : Breadboard) -> bool {
	assert(state == .CIRCUITS_EDIT);
	using circuits_edit_info;
	assert(circuits_edit_state == .PLACE || circuits_edit_state == .MOVE);
	if !zone_inside_zone(new_circuit.zone, Ibox2.{size = size}) return false;
	if circuits.count >= 0x100 return false;
	for circuits {
		if intersects(it.zone, new_circuit.zone) return false;
	}
	return true;
}

try_place_circuit :: (using breadboard : *Breadboard, key : Key) -> processed:bool {
	assert(state == .CIRCUITS_EDIT);
	using circuits_edit_info;
	assert(circuits_edit_state == .PLACE);

	if key != .ENTER return false;
	if !can_place_circuit(breadboard) return false;
	array_add(*circuits,  copy_circuit(new_circuit, breadboard));

	// model, submodel, ok := model_and_submodel_by_line(task, selected);
	// assert(ok);
	// new_circuit=, ok2 := gen_circuit(breadboard, cursor_position, model, submodel);
	// assert(ok2);
	untouched_after_finish = false;

	return true;
}

can_remove_circuit :: (using breadboard : Breadboard) -> processed:bool {
	for circuits {
		if point_inside_zone(cursor_position, it.zone) return true;
	}
	return false;
}
try_remove_circuit :: (using breadboard : *Breadboard, key : Key) -> processed:bool {
	assert(state == .CIRCUITS_EDIT);
	using circuits_edit_info;
	assert(circuits_edit_state == .FREE);
	if key != .ENTER && key != #char"r" return false;

	for *c : circuits {
		if point_inside_zone(cursor_position, c.zone) {
			deinit(c);
			remove c;
			untouched_after_finish = false;
			return true;
		}
	}
	return false;
}
try_copy_circuit :: (using breadboard : *Breadboard, key : Key) -> processed:bool {
	if !is_cursor_visible(breadboard) return false;
	using circuits_edit_info;
	if key != .ENTER && key != .CTRL_C return false;

	for *c : circuits {
		if point_inside_zone(cursor_position, c.zone) {
			safe_replace(*new_circuit, copy_circuit(c, breadboard));
			cursor_position = new_circuit.corner;
			circuits_edit_state = .PLACE;
			state = .CIRCUITS_EDIT;
			return true;
		}
	}
	return false;
}
is_cursor_visible :: (using breadboard : Breadboard) -> bool {
	if #complete state == {
	case .DEFAULT; return true;
	case .SHOW_TASK; return false;
	case .ADD_WIRE; return true;
	case .CIRCUITS_EDIT;
		if #complete circuits_edit_info.circuits_edit_state == {
			case .FREE; return true;
			case .PLACE; return false;
			case .SELECT; return false;
			case .MOVE; return false;
		}
	case .ASSEMBLY_EDIT; return false;
	}
	return false;
}
try_begin_move_circuit :: (using breadboard : *Breadboard, key : Key) -> processed:bool {
	if !is_cursor_visible(breadboard) return false;
	if key != #char"m" return false;
	using circuits_edit_info;

	for *c : circuits {
		if point_inside_zone(cursor_position, c.zone) {
			safe_replace(*new_circuit, c.*);
			saved_position, cursor_position = new_circuit.corner;
			log("saved_position = %\n", saved_position);
			saved_index = it_index;
			state = .CIRCUITS_EDIT;
			circuits_edit_state = .MOVE;

			array_ordered_remove_by_index(*circuits, it_index);
			untouched_after_finish = false;
			return true;
		}
	}
	return false;
}

add_wire :: (using breadboard : *Breadboard) {
	assert(state == .ADD_WIRE);
	if !disable_wire_edit {
		w := at_ptr(*wiremap, cursor_position);
		if wire_brush != w.* {
			untouched_after_finish = false;
			wiremap.cost += (ifx wire_brush 1) - (ifx w.* 1);
			w.* = wire_brush;

			old_cost := wiremap.cost;
			fix_cost(*wiremap);
			assert(old_cost == wiremap.cost);
		}
	}
}

try_move_cursor_dir :: (using breadboard : *Breadboard, direction : Direction, after_move : (*Breadboard, mooved:bool)->()) -> processed:bool {
	prev_position := cursor_position;
	zts := zone_to_show(breadboard);

	if #complete direction == {
		case .LEFT; cursor_position.x = xx max(0, cursor_position.x - 1);
		case .UP; cursor_position.y = xx max(0, cursor_position.y - 1);

		case .RIGHT;
		cursor_position.x = xx min(size.x - zts.width, cursor_position.x + 1);
		
		case .DOWN;
		cursor_position.y = xx min(size.y - zts.height, cursor_position.y + 1);
	}

	// fix_offset();
	after_move(breadboard, cursor_position != prev_position);

	return true;
}
is_move_key :: (key : Key) -> bool {
	return
		key == .LEFT || key == .DOWN || key == .RIGHT || key == .UP ||
		key == .CTRL_LEFT || key == .CTRL_DOWN || key == .CTRL_RIGHT || key == .CTRL_UP ||
		key == .ALT_LEFT || key == .ALT_DOWN || key == .ALT_RIGHT || key == .ALT_UP ||
		key == .SHIFT_COMMA || key == .SHIFT_DOT
		;
}
CTRL_MOVE_FACTOR_Y :: 5;
CTRL_MOVE_FACTOR_X :: 10;

try_move_cursor :: (using breadboard : *Breadboard, key : Key, after_move := (breadboard:*Breadboard, mooved:bool){}) -> processed:bool {
		if key == {
		case .LEFT; try_move_cursor_dir(breadboard, .LEFT, after_move);
		case .RIGHT; try_move_cursor_dir(breadboard, .RIGHT, after_move);
		case .DOWN; try_move_cursor_dir(breadboard, .DOWN, after_move);
		case .UP; try_move_cursor_dir(breadboard, .UP, after_move);

		case .CTRL_LEFT; for 1..CTRL_MOVE_FACTOR_X try_move_cursor_dir(breadboard, .LEFT, after_move);
		case .CTRL_RIGHT; for 1..CTRL_MOVE_FACTOR_X try_move_cursor_dir(breadboard, .RIGHT, after_move);
		case .CTRL_DOWN; for 1..CTRL_MOVE_FACTOR_Y try_move_cursor_dir(breadboard, .DOWN, after_move);
		case .CTRL_UP; for 1..CTRL_MOVE_FACTOR_Y try_move_cursor_dir(breadboard, .UP, after_move);

		case;
		return false;
	}
	return true;
}

try_escape :: (using breadboard : *Breadboard, key : Key) -> processed:bool {
	escape :: (_key : Key) #expand {
		if (key == _key && _key) || key == #char"q" || key == .ESCAPE {
			state = .DEFAULT;
			`return true;
		}
	}
	if #complete state == {
		case .DEFAULT; return false;
		case .ADD_WIRE; escape(#char"w");
		case .CIRCUITS_EDIT; escape(0);
		case .ASSEMBLY_EDIT; escape(#char"a");
		case .SHOW_TASK; escape(#char"t");
	}

	return false;
}
try_switch_mode :: (using breadboard : *Breadboard, key : Key) -> processed:bool {
	if key == {
	case #char"w";
		state = .ADD_WIRE;
		disable_wire_edit = false;
		add_wire(breadboard);			

	case #char"c";
		state = .CIRCUITS_EDIT;
		using circuits_edit_info;
		circuits_edit_state = .SELECT;
		// selected = 0;
		// deinit(new_circuit.machine);
		// free(new_circuit.machine);
		// safe_replace(*new_circuit, gen_circuit(breadboard, cursor_position, 0));
		// only_move = false;
	case #char"r";
		state = .CIRCUITS_EDIT;
		using circuits_edit_info;
		circuits_edit_state = .FREE;

	case #char"a";
		if circuits {
			assemble(breadboard);
			state = .ASSEMBLY_EDIT;
			safe_replace(*assembly_edit_info.error_message, "");

			for circuits {
				if point_inside_zone(cursor_position, it.zone) {
					assembly_edit_info.target = it_index;
				}
			}
			Clamp(*assembly_edit_info.target, 0, circuits.count-1);
			assembly_edit_info.state = .EDIT;
			return true;
		} else {
			return false;
		}

	case #char"m";
		if try_begin_move_circuit(breadboard, key) return true;
		return false;
	case .CTRL_C;
		if try_copy_circuit(breadboard, key) return true;
		return false;

	case #char"t";
		state = .SHOW_TASK;
		using show_task_info;
		safe_replace(*lines, process_help(task.description));
	case;
		return false;
	}
	return true;
}

try_process_wire :: (using breadboard : *Breadboard, key : Key) -> processed:bool {
	begin :: (wire : Wire) #expand {
		disable_wire_edit = false;
		wire_brush = wire;
		add_wire(breadboard);		
	}

	if key == {
		case #char"r";
			begin(.RED);
		case #char"g";
			begin(.GREEN);
		case #char"y";
			begin(.YELLOW);
		case #char"e";
			begin(.NONE);

		case .ENTER;
			disable_wire_edit ^= true;
			add_wire(breadboard);
		case;
			return false;
	}
	return true;
}

assemble :: (using breadboard : *Breadboard) {
	pin_coords : [..]ivec2; pin_coords.allocator = temp;
	circuit_ids: [..]int;  circuit_ids.allocator = temp;
	socket_ids : [..]int;   socket_ids.allocator = temp;
	pin_types  : [..]bool;   pin_types.allocator = temp;

	for c, ci : circuits {
		for p : c.pins {
			array_add(*pin_coords, c.corner + p.position);
			array_add(*circuit_ids, ci);
			array_add(*socket_ids, p.socket);
			array_add(*pin_types, p.type);
		}
	}
	
	pin_groups := find_pin_groups(*wiremap, pin_coords);

	for pin_group : pin_groups {
		// targets_c : [..]int; targets_c.allocator = temp;
		targets_a : [..]Address; targets_a.allocator = temp;
		//TODO make multiple input sockets
		senders_c : [..]int; senders_c.allocator = temp;
		senders_s : [..]int; senders_s.allocator = temp;

		for pin_id : pin_group {
			if pin_types[pin_id] {
				array_add(*targets_a, 
					.{
						circuits[circuit_ids[pin_id]].machine,
						xx socket_ids[pin_id]
					}
				);
			} else {
				array_add(*senders_c, circuit_ids[pin_id]);
				array_add(*senders_s, socket_ids[pin_id]);
			}
		}

		for sender_c : senders_c {
			sender_s := senders_s[it_index];
			builder := String_Builder.{allocator = temp};

			safe_replace(
				*(circuits[sender_c].target_circuits[sender_s]),
				array_copy(targets_a)
			);

		}
	}
}
restart_simulation :: (using breadboard : *Breadboard) {
	assembly_edit_info.state = .SIMULATE;
	for * circuits reset(it.machine);
	assembly_edit_info.sim_time = 0;
}
process_move_offset :: (game : *Game, key : Key) -> bool {
	if key == {
	case .LEFT;
		game.edit_solution.view_offset.x -= 1;
	case .RIGHT;
		game.edit_solution.view_offset.x += 1;
	case .UP;
		game.edit_solution.view_offset.y -= 1;
	case .DOWN;
		game.edit_solution.view_offset.y += 1;
	case .CTRL_LEFT;
		game.edit_solution.view_offset.x -= CTRL_MOVE_FACTOR_X;
	case .CTRL_RIGHT;
		game.edit_solution.view_offset.x += CTRL_MOVE_FACTOR_X;
	case .CTRL_UP;
		game.edit_solution.view_offset.y -= CTRL_MOVE_FACTOR_Y;
	case .CTRL_DOWN;
		game.edit_solution.view_offset.y += CTRL_MOVE_FACTOR_Y;
	case;
		return false;		
	}
	return true;
}
process_key_assembly_edit :: (game : *Game, key : Key, target_solution_info : *Solution_Info, target_level_info : *Level_Info) -> processed:bool {
	 using breadboard := *game.edit_solution.breadboard;

	switch_focus :: () -> bool #expand {
		if key == {
		case .SHIFT_DOT; #through;
		case .ALT_RIGHT;
			assembly_edit_info.target = (assembly_edit_info.target + 1) % circuits.count;
			return true;
		case .SHIFT_COMMA; #through;
		case .ALT_LEFT;
			assembly_edit_info.target = (assembly_edit_info.target + circuits.count - 1) % circuits.count;
			return true;			
		}
		return false;
	}

	if #complete assembly_edit_info.state == {
	case .EDIT;
		if switch_focus() return true;
		if !circuits[assembly_edit_info.target].readonly {
			processed, changed := process_key_editor(*(circuits[assembly_edit_info.target].editor), key);
			if changed then untouched_after_finish = false;
			if processed return true;
		}
		if key == {
		case .TAB;
			error : string;
			for * circuits {
				error = it.machine.vt().compiler(it.machine, get_lines(it.editor));
				if error {
					assembly_edit_info.error_source = it_index;
					break;
				}
			}
			safe_replace(*assembly_edit_info.error_message, copy_string(error));
			if !error {
				restart_simulation(breadboard);
				assembly_edit_info.paused = false;
				assembly_edit_info.simulation_speed = 4;	
			}
			return true;
		}

	case .SIMULATE;
		using assembly_edit_info;
		if process_move_offset(game, key) return true;

		if key == {
		case #char"a"; #through;
		case .TAB;
			state = .EDIT;
			return true;
		case #char"+"; #through;
		case #char"=";
			simulation_speed = min(simulation_speed * 2, 1 << 20);
		case #char"-";
			simulation_speed = max(1, simulation_speed / 2);
		case #char" ";
			paused ^= true;
		case #char"r";
			restart_simulation(breadboard);
			return true;
		case #char"s";
			simulate_one_tick(breadboard, target_solution_info, target_level_info);
			return true;
		}
	case .SHOW_RESULT;
		if process_move_offset(game, key) return true;
		if key == {
		case .ESCAPE; #through;
		case .ENTER;
			assembly_edit_info.state = .EDIT;
			return true;
		}
		return false;
	}

	return false;
}

try_switch_template :: (using breadboard : *Breadboard, key : Key) -> bool {
	assert(state == .CIRCUITS_EDIT);
	using circuits_edit_info;
	assert(circuits_edit_state == .SELECT);

	if key == .ENTER {
		model, submodel, ok := model_and_submodel_by_line(task, selected);
		_new_circuit, ok2 := gen_circuit(breadboard, cursor_position, model, submodel);
		assert(ok2);
		safe_replace(*new_circuit, _new_circuit);
		circuits_edit_state = .PLACE;
		return true;
	}

	return false;
}

process_key_breadboard :: (game : *Game, key : Key, target_solution_info : *Solution_Info, target_level_info : *Level_Info) -> processed:bool {
	using breadboard := *game.edit_solution.breadboard;
	defer {
		ok := true;
		for circuits {
			oki := validate_buffer(it.editor);
			ok &= oki;
			if !oki {
				log("invalid circuit: %\n", it_index);
			}
		}
		assert(ok);
	}
	occ :: (arg : bool) #expand {
		if arg `return true;
	}
	if #complete state == {
	case .DEFAULT;
		occ(try_move_cursor(breadboard, key));

	case .CIRCUITS_EDIT;
		using circuits_edit_info;
		if #complete circuits_edit_state == {
		case .FREE;
			occ(try_move_cursor(breadboard, key, (using breadboard : *Breadboard, mooved : bool) {
				using circuits_edit_info;
				new_circuit.corner = cursor_position;
			}));
			occ(try_remove_circuit(breadboard, key));
			occ(try_copy_circuit(breadboard, key));
			if key == {
			case #char"n"; #through;
			case #char"c";
				circuits_edit_state = .SELECT;
				return true;
			}
		case .SELECT;
			if key == {
			case .UP;
				selected = max(0, selected - 1);
				return true;
			case .DOWN;
				selected = min(total_submodel_count(task) - 1, selected + 1);
				return true;
			case .ESCAPE;
				circuits_edit_state = .FREE;
				return true;
			}
			occ(try_switch_template(breadboard, key));
		case .PLACE;
			occ(try_move_cursor(breadboard, key, (using breadboard : *Breadboard, mooved : bool) {
				using circuits_edit_info;
				new_circuit.corner = cursor_position;
			}));
			occ(try_place_circuit(breadboard, key));
			if key == .ESCAPE {
				circuits_edit_state = .FREE;
				return true;
			}
		case .MOVE;
			occ(try_move_cursor(breadboard, key, (using breadboard : *Breadboard, mooved : bool) {
				using circuits_edit_info;
				new_circuit.corner = cursor_position;
			}));
			if key == .ENTER {
				// TODO maybe do try_end_move_circuit()
				if can_place_circuit(breadboard) {
					array_insert_at(*circuits, new_circuit, saved_index);
					new_circuit = .{};
					circuits_edit_state = .FREE; // place, keep index
					untouched_after_finish = false;
					return true;
				}
			}
			if key == .ESCAPE {
				new_circuit.corner = saved_position;
				array_insert_at(*circuits, new_circuit, saved_index);
				new_circuit = .{};
				circuits_edit_state = .FREE;
				return true;
			}			
		}
	case .ADD_WIRE;
		occ(try_move_cursor(breadboard, key, (b, m) => { add_wire(b); }));
		if try_process_wire(breadboard, key) return true;

	case .ASSEMBLY_EDIT;
		using assembly_edit_info;
		assert(circuits.count != 0);
		occ(process_key_assembly_edit(game, key, target_solution_info, target_level_info));
	case .SHOW_TASK;
		using show_task_info;
		if key == {
		case .UP;
			offset -= 1;
			return true;
		case .DOWN;
			offset += 1;
			return true;
		}
	}

	occ(try_escape(breadboard, key));
	occ(try_switch_mode(breadboard, key));

	return false;
}

zone_to_show :: (using breadboard : Breadboard) -> Ibox2, bool {
	if #complete state == {
	case .SHOW_TASK;
		return .{}, false;
	case .ADD_WIRE; #through;
	case .DEFAULT;
		return .{corner = cursor_position, size = .{1, 1}}, true;
		
	case .CIRCUITS_EDIT;
		using circuits_edit_info;
		if #complete circuits_edit_state == {
		case .FREE; 
			return .{corner = cursor_position, size = .{1, 1}}, true;
		case .SELECT;
			return .{}, false;
		case .MOVE; #through;
		case .PLACE;
			return new_circuit.zone, true;
		}
	case .ASSEMBLY_EDIT;
		if #complete assembly_edit_info.state == {
		case .EDIT;
			return circuits[assembly_edit_info.target].zone, true;
		case .SHOW_RESULT;
			return .{}, false;
		case .SIMULATE;
			return .{}, false;	
		}
	}
	assert(false);
	return .{}, false;
}
