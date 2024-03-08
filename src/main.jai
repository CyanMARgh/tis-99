using,except(make_char, make_graphics_mode) KS_Curses :: #import "kscurses"(ENABLE_SIGINT = false);
#import "Basic"()(MEMORY_DEBUGGER = DEBUG);
#if DEBUG {
	#import "Debug"(USE_GRAPHICS = false);
}
#import "Command_Line";
#import "File";
#import "File_Utilities";
#import "Extra_Containers";
#import "String";
#import "Hash_Table";
#import "Hash";
#import "Random";
#import "Math";
#import "Sort";
#import "Hash";

#load "utils.jai";
#load "block_editor.jai";
#load "machines/general.jai";
#load "help.jai";
#load "wiremap.jai";
#load "serialize.jai";
#load "config.jai";
#load "breadboard.jai";
#load "task.jai";
#load "player.jai";
#load "compress.jai";
#load "saves.jai";

Game :: struct {
	state : enum u8 {
		MAIN_MENU;
		EDIT_SOLUTION;
	};
	frame_mod_1m := 0;

	LEVEL_NAME_MAX_LENGTH :: 20;
	player_info : Player_Info;

	main_menu : struct {
		main_menu_state : enum u8 {
			SELECT_LEVEL;
			SELECT_SOLUTION;
			INPUT_NAME;
		}

		cursor_level : int;
		columns := 1;

		SAVES_VISIBLE :: 5;
		SOLUTION_STATE_COLORS :: Color.[.BRIGHT_RED, .WHITE, .BRIGHT_YELLOW, .BRIGHT_GREEN];

		solutions_list_offset := 0;
		cursor_solution : int;

		name_input : SBDA(u8, MAX_FILE_NAME_SIZE);
	};

	target_solution_info : *Solution_Info;
	target_level_info : *Level_Info;
	edit_solution : struct {
		save_file_name := "";

		breadboard : Breadboard;
		view_offset : ivec2;
	};

	help : struct {
		page_id := -1;
		offset := 0;
	};
}
valid_file_name :: (name : string) -> bool {
	if !name return false;
	for cast([]u8)trim(name) {
		if it >= #char"a" && it <= #char"z" continue;
		if it >= #char"A" && it <= #char"Z" continue;
		if it == #char"_" continue;
		if it >= #char"0" || it <= #char"9" continue;
		return false;
	}
	return true;
}
switch_to_start_menu :: (using game : *Game) {
	using main_menu;
	// shown = 0;
	cursor_level = 0;
	state = .MAIN_MENU;
	main_menu_state = .SELECT_LEVEL;
}

init :: (using game : *Game) {
	load_player_info(game);
	switch_to_start_menu(game);
	// player_info = load_and_fix_player_info();
}
deinit :: (using game : *Game) {
	deinit(*player_info);

	// deinit(*create_solution.prop_editor);
	// for create_solution.aviable_tasks {
	// 	free(it);
	// }
	// array_free(create_solution.aviable_tasks);
	// free(create_solution.error);
	// array_free(create_solution.particles);

	free(edit_solution.save_file_name);
	deinit(*edit_solution.breadboard);
}
shows_help :: (using game : Game) -> bool { return help.page_id != -1; }

fix_offset :: (using game : *Game) {
	tsize := terminal_state.size;

	if state == {
	case .MAIN_MENU;
		using main_menu;
		if cursor_solution - solutions_list_offset >= SAVES_VISIBLE {
			solutions_list_offset = cursor_solution - SAVES_VISIBLE + 1;
		} else if cursor_solution - solutions_list_offset < 0 {
			solutions_list_offset = cursor_solution;
		}
	case .EDIT_SOLUTION;
		using,except(state) edit_solution;

		GAP :: 1;
		GAP_BOTTOM :: 3;

		if breadboard.size.x <= tsize.x - GAP * 2 {
			view_offset.x = -GAP - ((tsize.x - 2 * GAP - breadboard.size.x) / 2);
		} else if view_offset.x < -GAP {
			view_offset.x = -GAP;
		} else if view_offset.x > breadboard.size.x + GAP - tsize.x {
			view_offset.x = breadboard.size.x + GAP - tsize.x;
		}

		if breadboard.size.y <= tsize.y - GAP - GAP_BOTTOM {
			view_offset.y = -GAP - ((tsize.y - (GAP + GAP_BOTTOM) - breadboard.size.y) / 2);
		} else if view_offset.y < -GAP {
			view_offset.y = -GAP;
		} else if view_offset.y > breadboard.size.y + GAP - tsize.y {
			view_offset.y = breadboard.size.y + GAP_BOTTOM - tsize.y;
		}

		{
			must_see, has_zone := zone_to_show(breadboard);
			wh := must_see.size;
			lt := must_see.corner;
			rb := lt + wh;
			if has_zone {
				view_offset.y = clamp(view_offset.y, rb.y - tsize.y + GAP_BOTTOM, lt.y - GAP);
				view_offset.x = clamp(view_offset.x, rb.x - tsize.x + GAP, lt.x - GAP);
			}			
		}

		using breadboard.show_task_info;
		Clamp(*offset, 0, max(0, lines.count - terminal_state.size.y));
	}
	if shows_help(game) {
		Clamp(*help.offset, 0, max(0, MANUAL[help.page_id].count - terminal_state.size.y + 1));	
	}
}

draw_help :: (canvas : *Canvas, page_id : int, offset : int) {
	help := MANUAL[page_id];
	for y : 0..min(help.count - offset, canvas.size.y)-1 {
		c_printl_ascii(canvas, .{0, xx y}, MODE_DEFAULT, help[y + offset]);
	}

	c_print_ascii(canvas, .{0, canvas.size.y-1}, MODE_DEFAULT_INVERTED, tprint("[%/%]", page_id + 1, MANUAL.count));	
}

draw_main_menu :: (canvas : *Canvas, using game : Game) {
	using main_menu;

	// Clamp(*solutions_list_offset, cursor_solution, max(0, cursor_solution - SAVES_VISIBLE + 1));
	WGAP, y0 :: 5, 8;
	c_print_ascii(canvas, .{xx ((canvas.size.x - TITLE_WIDTH) / 2), xx (y0 - 7)}, MODE_START_MENU_TITLE, TITLE);

	W := canvas.size.x;
	columns = (W - 2 * WGAP) / (MAX_FILE_NAME_SIZE + 1);
	columns = min(columns, player_info.levels.count + 1);
	if columns <= 0 return;
	free_space :=  W - 2 * WGAP - columns * MAX_FILE_NAME_SIZE;

	
	visible_levels_ids := visible_list(player_info);

	for visible_levels_ids {
		level_info := *player_info.levels[it];
		level_name := level_info.name;
		level_color := SOLUTION_STATE_COLORS[cast(int)level_info.state];

		mode := ifx it_index == cursor_level  
			make_graphics_mode(foreground = .BLACK, background = level_color)
		else
			make_graphics_mode(background = .BLACK, foreground = level_color);

		row, column := it_index / columns, it_index % columns;
		y := y0 + (row + 1) * 2;
		dx_free := 0;
		if column {
			dx_free = free_space * column / (columns - 1);
		}
		// x := WGAP + (canvas.zone.width - 2 * WGAP - MAX_FILE_NAME_SIZE) * column / columns;
		x := WGAP + column * MAX_FILE_NAME_SIZE + dx_free;
		c_print_ascii(canvas, .{xx x, xx y}, mode, pad(level_name, MAX_FILE_NAME_SIZE));
	}
	if main_menu_state == .SELECT_SOLUTION || main_menu_state == .INPUT_NAME {
		SELECT_SOLUTION_BOX :: ivec2.{MAX_FILE_NAME_SIZE + 3, SAVES_VISIBLE + 4};
		corner := (canvas.size - SELECT_SOLUTION_BOX) / 2;
		c_box(canvas, .{corner = corner, size = SELECT_SOLUTION_BOX}, box_style_passive);

		for x : 0..MAX_FILE_NAME_SIZE {
			c_putchar(canvas, .{code = #char"-", mode = MODE_DEFAULT}, corner + .{xx (1 + x), SAVES_VISIBLE + 1});
		}
		if cursor_solution != 0 {
			solution := *target_level_info.solutions[cursor_solution - 1];
			if solution.state < .SOLVED_BUT_EDITED {
				c_printl_ascii(
					canvas,
					corner + .{1, SAVES_VISIBLE + 4},
					make_graphics_mode(background = .BLACK, foreground = SOLUTION_STATE_COLORS[cast(int)solution.state]),
					to_string(solution.state)
				);
			} else {
				c_print_ascii(canvas, corner + .{1, SAVES_VISIBLE + 4}, make_graphics_mode(background = .BLACK, foreground = SOLUTION_STATE_COLORS[cast(int)solution.state]),
					"%\ncost: % u.\niterations: %", 
					ifx solution.state == .SOLVED then "solved" else  "solved, but edited",
					solution.cost, solution.time
				);
			}
		}

		solutions := target_level_info.solutions;
		c_print_ascii(canvas, corner + .{9, SAVES_VISIBLE + 1}, MODE_TEXT_DESCRIPTION, "%-%/%", solutions_list_offset, min(solutions.count, solutions_list_offset + SAVES_VISIBLE - 1), solutions.count);
		for i : solutions_list_offset..min(solutions.count, solutions_list_offset + SAVES_VISIBLE - 1) {
			dy := i - solutions_list_offset;
			under_cursor := i == cursor_solution && main_menu_state != .INPUT_NAME;	
			level_color := SOLUTION_STATE_COLORS[ifx i then solutions[i - 1].state else 1];

			mode := ifx under_cursor
				make_graphics_mode(foreground = .BLACK, background = level_color)
			else
				make_graphics_mode(background = .BLACK, foreground = level_color);

			line := ifx i == 0 then "[+]" else solutions[i - 1].name;
			c_print_ascii(canvas, corner + .{1, xx(1 + dy)}, mode, line);
		}
		if main_menu_state == .INPUT_NAME {
			c_print_ascii(canvas, corner + .{1, SAVES_VISIBLE + 2}, MODE_REGISTER, to_string(name_input));
			c_putchar(canvas, .{code = #char" ", mode = MODE_EDITOR_CURSOR}, corner + .{xx (1 + name_input.count), SAVES_VISIBLE + 2});
		}
	}
}

get_mode_label :: (using game : Game) -> string, Graphics_Mode {
	if #complete state == {
	case .EDIT_SOLUTION;
		using edit_solution.breadboard;
		if state == {
		case .DEFAULT;
			return "default\n[C]ircuits [W]ires [A]ssembly [T]ask [R]emove [M]ove", MODE_LABEL_DEFAULT;
		case .SHOW_TASK;
			return "\ntask", MODE_LABEL_DEFAULT;
		case .CIRCUITS_EDIT;
			if #complete circuits_edit_info.circuits_edit_state == {
			case .FREE; return "circuits edit (free)\n[ENTER / R] - remove, [C/N] - new circuit, [M] - move, [CTRL+C]-copy", MODE_LABEL_DEFAULT;
			case .PLACE; return "circuits edit (place)\n[ENTER] - place, [C] - new circuit, [ESC] - cancel", MODE_LABEL_DEFAULT;
			case .SELECT; return "\ncircuits edit (select)", MODE_LABEL_DEFAULT;
			case .MOVE; return "\ncircuits edit (move)\n[ENTER] - place, [ESC] - cancel", MODE_LABEL_DEFAULT;
			}
			return "", MODE_LABEL_DEFAULT;
		// case .REMOVE_CIRCUIT;
		// 	return "\nremove circuit", MODE_DEFAULT;
		case .ADD_WIRE;
			return "add wires\n[R/G/Y/E] - color [ENTER] - lock", MODE_LABEL_DEFAULT;
		case .ASSEMBLY_EDIT;
			using assembly_edit_info;
			if state == {
			case .EDIT;
				return "assembly edit\n[ALT+RIGHT/LEFT] - focus [TAB] - simulate", MODE_LABEL_DEFAULT;
			case .SIMULATE;
				return tprint(
					"simulation, speed: %, ticks: %\n[SPACE] - pause [+-] - change speed [A]ssembly [R]estart [S]tep", 
					tprint(ifx paused then "[%]" else "%", simulation_speed),
					sim_time
				), ifx paused then MODE_LABEL_PAUSED else MODE_LABEL_DEFAULT;
			}
		}
	case .MAIN_MENU;
		using main_menu;
		if #complete main_menu_state == {
		case .SELECT_LEVEL;
			return "\nlevel selcetion", MODE_LABEL_DEFAULT;
		case .SELECT_SOLUTION;
			return "solution selection\n[N]ew", MODE_LABEL_DEFAULT;
		case .INPUT_NAME;
			return "\nsolution name input", MODE_LABEL_DEFAULT;
		}
	}
	return "", MODE_LABEL_DEFAULT;
}

draw :: (canvas : *Canvas, using game : Game) {
	if shows_help(game) {
		draw_help(canvas, help.page_id, help.offset);
	} else {
		right_bottom_label : string;
		if #complete state == {
		case .MAIN_MENU;
			draw_main_menu(canvas, game);
			if player_info.show_initial_hint {
				right_bottom_label = "press F1 or \"?\" to help";
			}
		case .EDIT_SOLUTION;
			using edit_solution;
			right_bottom_label = tprint("%1/%2%3, %4 u.", target_level_info.name, target_solution_info.name, ifx breadboard.untouched_after_finish then " " else "*", get_cost(breadboard));
			draw_inner(*breadboard, .{size = canvas.size, corner = view_offset});
			draw_to_canvas(canvas, breadboard, view_offset);
		}		
		{
			label, mode := get_mode_label(game);
			c_print_ascii(canvas, .{0, canvas.size.y - 2}, mode, label);		
		}
		c_print_ascii(canvas, canvas.size - .{xx right_bottom_label.count, 1}, MODE_LABEL_HINT, right_bottom_label);
	}
}

directory_content_with_extension :: (path : string, ext : string) -> []string {
	found_files := files_from_directory(path, ext);
	return quick_sort(found_files, compare);
}

process_key_main_menu :: (using game : *Game, key : Key) -> bool {
	using main_menu;
	if #complete main_menu_state == {
	case .SELECT_LEVEL;
		row, column := cursor_level / columns, cursor_level % columns;
		visible_levels_ids := visible_list(player_info);

		if key == {
		case .LEFT;
			if column > 0 {
				column -= 1;
			} else {
				column = columns - 1;
				row -= 1;
			}
		case .RIGHT;
			if column < columns - 1 {
				column += 1;
			} else {
				column = 0;
				row += 1;
			}
		case .DOWN;
			row += 1;
		case .UP;
			row = max(0, row - 1);
		case .ENTER;
			if visible_levels_ids.count <= 0 return false;
			target_level_info = *player_info.levels[visible_levels_ids[cursor_level]];
			main_menu_state = .SELECT_SOLUTION;
			cursor_solution = 0;
		case;
			return false;
		}
		new_cursor := columns * row + column;
		if new_cursor < visible_levels_ids.count && new_cursor >= 0 {
			cursor_level = new_cursor;
		}
		return true;
	case .SELECT_SOLUTION;
		assert(!!target_level_info);
		if key == {
		case .UP;
			cursor_solution = max(0, cursor_solution - 1);
		case .DOWN;
			cursor_solution = min(target_level_info.solutions.count, cursor_solution + 1);
		case .ESCAPE;
			main_menu_state = .SELECT_LEVEL;
		case .ENTER;
			if cursor_solution == 0 {
				main_menu_state = .INPUT_NAME;
				name_input.count = 0;
			} else {
				target_solution_info = *target_level_info.solutions[cursor_solution - 1];

				ok := try_load_target_solution(game);
				if !ok {
					open_empty_solution(game);
				}
			}
		case #char"n";
			main_menu_state = .INPUT_NAME;
			name_input.count = 0;
		case .BACKSPACE; #through;
		case #char"r";
			if cursor_solution > 0 {
				file_path_to_delete := solution_file(DEFAULT_PLAYER, target_level_info.name, target_level_info.solutions[cursor_solution - 1].name);
				file_delete(file_path_to_delete);
				deinit(*target_level_info.solutions[cursor_solution - 1]);
				array_ordered_remove_by_index(*target_level_info.solutions, cursor_solution - 1);
				cursor_solution = min(cursor_solution, target_level_info.solutions.count);
				refresh(target_level_info);
				refresh_hidden_levels(*player_info);
				save_player_info(game);
			}
		case;
			return false;
		}
		return true;
	case .INPUT_NAME;
		assert(!!target_level_info);
		if #char"A" <= key && key <= #char"Z"
		|| #char"a" <= key && key <= #char"z"
		|| #char"0" <= key && key <= #char"9"
		|| key == #char"_" then {
			if name_input.count < MAX_FILE_NAME_SIZE {
				array_add(*name_input, xx key);
			}
		} else if key == {
		case .BACKSPACE;
			name_input.count = max(0, name_input.count - 1);
		case .ESCAPE;
			main_menu_state = .SELECT_SOLUTION;
		case .ENTER;
			solution_name := to_string(name_input);
			if !valid_file_name(solution_name) return false;
			for target_level_info.solutions {
				if it.name == solution_name {
					log("solution with this (%) name already exists!\n", solution_name);
					return true;
				}
			}
			new_solution_info := Solution_Info.{name = copy_string(solution_name)};
			array_add(*target_level_info.solutions, new_solution_info);
			sort_solutions_by_name(target_level_info);
			main_menu_state = .SELECT_SOLUTION;

			{
				id := -1;
				for * target_level_info.solutions {
					if it.name == solution_name {
						target_solution_info = it;
						open_empty_solution(game);
					}
				}
			}

		case;
			return false;
		}
		return true;
	}
	return false;
}

process_key :: (using game : *Game, key : Key) -> bool {
	if shows_help(game) {
		if key == {
		case .UP;
			help.offset -= 1;
			return true;
		case .CTRL_UP;
			help.offset -= 10;
			return true;
		case .DOWN;
			help.offset += 1;
			return true;
		case .CTRL_DOWN;
			help.offset += 10;
			return true;
		case .RIGHT;
			if help.page_id < MANUAL.count - 1 {
				help.page_id += 1;
				help.offset = 0;
			}
			return true;
		case .LEFT;
			if help.page_id > 0 {
				help.page_id -= 1;
				help.offset = 0;
			}
			return true;		
		case .ESCAPE; #through;
		case #char"?"; #through;
		case F1; #through;
		case #char"q";
			help.page_id = -1;
			return true;
		}
		return false;
	}
	if #complete state == {
	case .MAIN_MENU;
		if process_key_main_menu(game, key) return true;
	case .EDIT_SOLUTION;
		using edit_solution;
		if process_key_breadboard(game, key, target_solution_info, target_level_info) return true;
		if key == {
		case CTRL_S;
			save_current_solution(game);
			return true;
		case .ESCAPE; #through;
		case #char"q";
			target_solution_info.state = min(target_solution_info.state, 
				ifx breadboard.untouched_after_finish then .SOLVED else .SOLVED_BUT_EDITED
			);
			refresh(target_level_info);
			save_current_solution(game);
			switch_to_start_menu(game);
			refresh_hidden_levels(*player_info);
			return true;
		}
	}
	if key == F1 || key == #char"?" {
		player_info.show_initial_hint = false;
		help.offset = 0;
		help.page_id = get_help(game);
	}

	return false;
}

draw_matrix_stuff :: (canvas : *Canvas, positions : []ivec2) {
	char_by_coord :: (p : ivec2) -> u8 {
		return xx (get_hash(p.values) % (#char"~" - #char"!" + 1) + #char"!");
	}

	for p0 : positions {
		for mode : MATRIX_PALETTE {
			p := p0 - ivec2.{0, xx it_index};
			c_putchar(canvas, .{code = char_by_coord(p), mode = mode}, p);
		}
	}
}

simulate :: (using game : *Game) {
	frame_mod_1m = (frame_mod_1m + 1) % 1_000_000;

	if #complete state == {
	case .MAIN_MENU;
	case .EDIT_SOLUTION;
		assert(!!target_level_info && !!target_solution_info);
		using edit_solution;
		simulate(*breadboard, frame_mod_1m, target_solution_info, target_level_info);

		if frame_mod_1m % 3000 == 0 {
			save_current_solution(game);

			target_solution_info.cost = get_cost(breadboard);
			target_solution_info.time = breadboard.assembly_edit_info.sim_time;
			target_solution_info.state = min(
				target_solution_info.state,
				ifx breadboard.untouched_after_finish then .SOLVED else .SOLVED_BUT_EDITED
			);
			refresh(target_level_info);
			save_player_info(game);

			log("%\n", target_solution_info.*);
		}
	}
}

main :: () {
	#if DEBUG {
		crash_handler = (trace : []string) {
			file, ok := file_open("crash_log.txt",for_writing=true, keep_existing_content=true);
			if !ok return;

			file_write(
				*file, 
				tprint("[%] crash trace:\n", calendar_to_string(to_calendar(current_time_consensus())))
			);
			for trace {
				file_write(*file, tprint("%\n", it));
			}
			file_close(*file);	
		};
		enable_signal_handler();
		defer report_memory_leaks();		
	}

	defer deinit_copy_buffer();
	random_seed(current_time_monotonic().low);

	draw :: () #expand {
		using terminal_state;
		resize(*main_canvas, terminal_state.size);
		c_clear(*main_canvas, make_char(#char" "));

		draw(*main_canvas, game);
		ks_draw_canvas(*main_canvas);
	}
	use_ks_curses();
	game : Game;
	init(*game); defer deinit(*game);
	main_canvas : Screen_Canvas;
	defer deinit(*main_canvas);

	log("==== begin: % =====\n", calendar_to_string(to_calendar(current_time_consensus())));

	use_events(tick_duration_ms = 20);
	stop_main := false;
	while !stop_main {
		for e : Process_Events {
			if e.type == {
			case .KEY;
				#if LOG_KEYS {
					log("%\n", e.key);
				}

				if process_key(*game, e.key) continue;
				if e.key == {
				// case #run ctrl("q"); #through;
				case #char"q"; #through;
				case .ESCAPE;
					save_player_info(game);
					stop_main = true;
				}
			case .WINCH;

			case .TICK;
				next_tick_state();
				simulate(*game);
			}
		}
		fix_offset(*game);
		draw();
		reset_temporary_storage();
	}	
}
