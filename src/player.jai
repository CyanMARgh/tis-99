Solution_Info :: struct {
	name : string;
	state : Solution_State = .UNSOLVED;
	cost := -1;
	time := -1;
}
Level_Info :: struct {
	name : string;
	state : Solution_State = .UNSOLVED;
	solutions : [..]Solution_Info;
	hidden := true;
}
is_level_unlocked :: (requirements : []string, player : Player_Info) -> bool {
	for r : requirements {
		ok := false;
		found := false;
		for player.levels {
			if it.name == r {
				ok = it.state >= .SOLVED_BUT_EDITED;
				found = true;
				break;
			}
		}
		if !found log("unknown requirement: %\n", r);
		if !ok return false;
	}
	return true;
}
refresh :: (using info : *Level_Info) {
	state = .UNSOLVED;

	for solutions state = max(state, it.state);
}

Solution_State :: enum u8 {
	BROKEN_FILE       :: 0;
	UNSOLVED          :: 1;
	SOLVED_BUT_EDITED :: 2;
	SOLVED            :: 3;
}

parse_solution_type :: (_str : string) -> Solution_State, bool {
	str := to_lower_copy_new(_str,, temp);
	if str == {
	case "broken_file";
		return .BROKEN_FILE, true;
	case "unsolved";
		return .UNSOLVED, true;
	case "solved_but_edited";
		return .SOLVED_BUT_EDITED, true;
	case "solved";
		return .SOLVED, true;
	}
	return .BROKEN_FILE, false;
}
to_string :: (ss : Solution_State) -> string {
	return to_lower_copy_new(tprint("%", ss),, temp);
}

UNLOCKED_SET_TEMPLATE :: #string STR
	@unlocked
		%
		%
		%
		%
	@end
STR

Unlocked_Set :: struct {
	tis3 := true;
	q5 := false;
	sm255 := false;
	jbms32 := false;
};
UNLOCKED_SET_UNLOCK_ALL :: Unlocked_Set.{true, true, true, true};

Player_Info :: struct {
	show_initial_hint := true;
	levels : [..]Level_Info;
	unlocked : Unlocked_Set;
}

add_level_if_it_does_not_exists :: (using player_info : *Player_Info, level_name : string) {
	for levels {
		if it.name == level_name return;
	}
	array_add(*levels, .{name = copy_string(level_name)});
}

sort_levels_by_name :: (using player_info : *Player_Info) {
	quick_sort(levels, (l1, l2) => compare(l1.name, l2.name));
}
add_solution_if_it_does_not_exists :: (using level_info : *Level_Info, solution_name : string) {
	for solutions {
		if it.name == solution_name return;
	}
	array_add(*solutions, .{name = copy_string(solution_name)});
}
sort_solutions_by_name :: (using solution_info : *Level_Info) {
	quick_sort(solutions, (s1, s2) => compare(s1.name, s2.name));
}

deinit :: (using solution_info : *Solution_Info) {
	free(name);
}
deinit :: (using level_info : *Level_Info) {
	for * solutions deinit(it);
	array_free(solutions);
	free(name);
}
deinit :: (using player_info : *Player_Info) {
	for * levels deinit(it);
	array_free(levels);
}

SOLUTION_INFO_TEMPLATE :: #string STR
	@save
		@name  %
		@state %
		@cost  %
		@time  %
	@end
STR;
LEVEL_INFO_TEMPLATE :: #string STR
@level
	@name  %
	@state %
STR;
PLAYER_INFO_TEMPLATE :: #string STR
@show_initial_hint %

STR;

print_to_builder :: (builder : *String_Builder, using info : Solution_Info) {
	print_to_builder(builder, SOLUTION_INFO_TEMPLATE, name, state, cost, time);
}
print_to_builder :: (builder : *String_Builder, using info : Level_Info) {
	print_to_builder(builder, LEVEL_INFO_TEMPLATE, name, state);
	for solutions print_to_builder(builder, it);
	append(builder, "@end\n");
}
print_to_builder :: (builder : *String_Builder, using info : Player_Info) {
	print_to_builder(builder, PLAYER_INFO_TEMPLATE, 
		show_initial_hint
	);
	for levels print_to_builder(builder, it);
}
to_string :: (player_info : Player_Info) -> string {
	builder : String_Builder;
	print_to_builder(*builder, player_info);
	return builder_to_string(*builder);
}

parsing_error :: (fmt : string, args : ..Any) #expand {
	deinit(*`result);
	message := tprint(fmt, ..args);
	make_safe_for_print(message);
	`return .{}, message;
}

parse_solution_info :: (tokens : *[]string) -> Solution_Info, error:string {
	using result : Solution_Info;
	while 1 {
		token, ok := chop(tokens);
		if !ok break;
		if token == {
		case "@end";
			if !name parsing_error("no name specified");
			return result, "";
		case "@name";
			_name, ok := chop(tokens);
			if !ok break;
			if !valid_file_name(_name) parsing_error("invalid name");
			safe_replace(*name, copy_string(_name));
		case "@state";
			valtok, ok := chop(tokens);
			if !ok break;
			val, ok2 := parse_solution_type(valtok);
			if !ok2 {
				parsing_error("invalid bool: %", valtok);
			} else {
				state = val;
			}
		case "@cost";
			valtok, ok := chop(tokens);
			if !ok break;
			val, ok2 := string_to_int(valtok);
			if !ok2 parsing_error("invalid int: %", valtok);
			cost = val;
		case "@time";
			valtok, ok := chop(tokens);
			if !ok break;
			val, ok2 := string_to_int(valtok);
			if !ok2 parsing_error("invalid int: %", valtok);
			time = val;
		case;
			parsing_error("invalid token: %", token);
		}
	}
	parsing_error("reached file end");
}
parse_level_info :: (tokens : *[]string) -> Level_Info, error:string {
	using result : Level_Info;
	// defer log("li: %\n", result);
	while 1 {
		token, ok := chop(tokens);
		if !ok break;
		if token == {
		case "@end";
			if !name parsing_error("no name specified");
			return result, "";
		case "@state";
			valtok, ok := chop(tokens);
			if !ok break;
			val, ok2 := parse_solution_type(valtok);
			if !ok2 {
				parsing_error("invalid bool: %", valtok);
			} else {
				state = val;
			}
		case "@name";
			_name, ok := chop(tokens);
			if !ok break;
			if !valid_file_name(_name) parsing_error("invalid name");
			safe_replace(*name, copy_string(_name));			
		case "@save";
			solution_info, err := parse_solution_info(tokens);
			if err parsing_error("can't parse solution info: %", err);
			array_add(*solutions, solution_info);
		case;
			parsing_error("invalid token: %", token);
		}
	}
	parsing_error("reached file end");
}
parse_player_info :: (tokens : *[]string) -> Player_Info, error:string {
	using result : Player_Info;
	chop_bool :: (tokens : *[]string) -> value:bool, err:string {
		valtok, ok := chop(tokens);
		if !ok return false, "no token for bool";
		if valtok == "true" {
			return true, "";
		} else if valtok == "false" {
			return false, "";
		} else {
			return false, tprint("invalid token: %", valtok);
		}		
	}

	while 1 {
		token, ok := chop(tokens);
		if !ok break;
		err : string;
		if token == {
		case "@show_initial_hint";
			show_initial_hint, err = chop_bool(tokens);
			if err parsing_error("can't parse bool: %", err);
		case "@level";
			level_info:, err = parse_level_info(tokens);
			if err parsing_error("can't parse level info: %", err);
			array_add(*levels, level_info);
		case;
			parsing_error("invalid token: %", token);
		}
	}
	return result, "";
}

prepare_tokens :: (source : string) -> []string {
	result : [..]string;
	for l : split(source, "\n",, temp) {
		while 1 {
			token, ok := parse_token(*l, ";", " \t");
			if !ok break;
			if token == ";" break;
			array_add(*result, token);
		}
	}
	return result;
}

refresh_hidden_levels :: (player : *Player_Info) {
	for *lvl : player.levels {
		name := task_file(lvl.name);
		task, err := load_task(name);
		if err {
			log("failed to load task: %\n", err);
			break;
		}
		defer deinit(*task);
		if is_level_unlocked(task.requirements, player) {
			lvl.hidden = false;
		}

		if lvl.state >= .SOLVED_BUT_EDITED {
			for task.unlocks {
				if it == "q5" player.unlocked.q5 = true;
				if it == "sm255" player.unlocked.sm255 = true;
				if it == "jbms32" player.unlocked.jbms32 = true;
			}			
		}
	}
}
visible_list :: (info : Player_Info) -> []int {
	result : [..]int; result.allocator = temp;
	for info.levels {
		if !it.hidden array_add(*result, it_index);
	}
	return result;
}

load_player_info :: (path : string) -> Player_Info, error:string {
	source, ok := read_entire_file(path);
	defer free(source);
	if !ok return .{},  tprint("can't open file: %", path);
	tokens := prepare_tokens(source,, temp);
	// print("tokens: %\n", tokens);
	player_info, err := parse_player_info(*tokens);
	if err return .{}, tprint("can't parse player info: %", err);
	// log("pi: %\n", player_info);

	for * player_info.levels refresh(it); 
	return player_info, "";
}
