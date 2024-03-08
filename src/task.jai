Task_IO441 :: struct {
	request_columns : [..][]s16;
	response_columns : [..][]s16;	
}
deinit :: (using task : *Task_IO441) {
	for request_columns array_free(it);
	array_free(request_columns);
	for response_columns array_free(it);
	array_free(response_columns);
}
Task_IO102 :: struct {
	request_column : []s16;
}
deinit :: (using task : *Task_IO102) {
	array_free(request_column);
}
Task_IO013 :: struct {
	response_column : []s16;
}
deinit :: (using task : *Task_IO013) {
	array_free(response_column);
}
Task_TWICS :: struct {
	source_lines : []string;
}
deinit :: (using task : *Task_TWICS) {
	for source_lines free(it);
	array_free(source_lines);
}
Task_TWOCS :: struct {
	result_lines : []string;
}
deinit :: (using task : *Task_TWOCS) {
	for result_lines free(it);
	array_free(result_lines);
}
Task_JBMS3232 :: struct {
	frames : [][32 * 32]u8;
}
deinit :: (using task : *Task_JBMS3232) {
	array_free(frames);
}
Task_SPIDER :: struct {}
deinit :: (task_spider : *Task_SPIDER) { }

Task :: struct {
	tasks_io441 : [..]Task_IO441;
	tasks_io102 : [..]Task_IO102;
	tasks_io013 : [..]Task_IO013;
	tasks_twics : [..]Task_TWICS;
	tasks_twocs : [..]Task_TWOCS;
	tasks_jbms3232 : [..]Task_JBMS3232;
	tasks_spider : [..]Task_SPIDER;

	description : string;
	requirements : []string;
	unlocks : []string;

	unlocked := UNLOCKED_SET_UNLOCK_ALL;
}
deinit :: (using task : Task) {
	for * tasks_io441 deinit(it);
	array_free(tasks_io441);
	for * tasks_io102 deinit(it);
	array_free(tasks_io102);
	for * tasks_io013 deinit(it);
	array_free(tasks_io013);
	for * tasks_twics deinit(it);
	array_free(tasks_twics);
	for * tasks_twocs deinit(it);
	array_free(tasks_twocs);
	for * tasks_jbms3232 deinit(it);
	array_free(tasks_jbms3232);
	for * tasks_spider deinit(it);
	array_free(tasks_spider);

	free(description);
	for requirements free(it);
	array_free(requirements);
	for unlocks free(it);
	array_free(unlocks);
}

chop :: (source : *[]string) -> string, ok:bool {
	if source.count <= 0 return "", false;
	result := source.*[0];
	source.count -= 1;
	source.data  += 1;
	return result, true;
}

parse_names_list :: (source : *[]string) -> []string, err:string {
	result : [..]string;
	error :: (fmt : string, args : ..Any) #expand {
		for result free(it);
		array_free(result);
		`return .[], tprint(fmt, ..args);
	}
	while 1 {
		line, ok := chop(source);
		if !ok break;
		while 1 {
			token, ok := parse_token(*line, ";", " \t");
			if !ok || token == ";" break;
			if token == "@end" {
				return result, "";
			}
			array_add(*result, copy_string(token));
		}
	}
	error("reached file end");	
}

parse_sequence :: (source : *[]string) -> []s16, str:string {
	result : [..]s16;
	error :: (fmt : string, args : ..Any) #expand {
		array_free(result);
		`return .[], tprint(fmt, ..args);
	}
	while 1 {
		line, ok := chop(source);
		if !ok break;
		while 1 {
			token, ok := parse_token(*line, ";", " \t");
			if !ok || token == ";" break;
			if token == "@end" {
				return result, "";
			}
			val, ok2 := string_to_s16(token);
			if !ok2 error("can't parse s16: %", token);
			array_add(*result, val);
		}
	}
	error("reached file end");
}
parse_task_io102 :: (source : *[]string) -> Task_IO102, err:string {
	column, err := parse_sequence(source);
	if err return .{}, tprint("can't parse sequence: %", err);
	return .{column}, "";
}
parse_task_io013 :: (source : *[]string) -> Task_IO013, err:string {
	column, err := parse_sequence(source);
	if err return .{}, tprint("can't parse sequence: %", err);
	return .{column}, "";
}

parse_frame_line :: (_line : string) -> []u8, err:string {
	char_to_code :: (char : u8) -> u8, ok:bool {
		if char == {
		case #char"0"; #through;
		case #char"."; #through;
		case #char"_";
			return 0, true;
		case #char"1"; #through;
		case #char"R"; #through;
		case #char"r";
			return 1, true;
		case #char"2"; #through;
		case #char"G"; #through;
		case #char"g";
			return 2, true;
		case #char"3"; #through;
		case #char"Y"; #through;
		case #char"y";
			return 3, true;
		case #char"4"; #through;
		case #char"B"; #through;
		case #char"b";
			return 4, true;
		case #char"5"; #through;
		case #char"M"; #through;
		case #char"m";
			return 5, true;
		case #char"6"; #through;
		case #char"C"; #through;
		case #char"c";
			return 6, true;
		case #char"7"; #through;
		case #char"#"; #through;
		case #char"W"; #through;
		case #char"w";
			return 7, true;
		}
		return 0, false;
	}

	line := cast([]u8)trim(_line);
	result := NewArray(line.count, u8,, temp);
	for i : 0..line.count-1 {
		code, ok := char_to_code(line[i]);
		if !ok return .[], tprint("invalid character: %, line: %", line[i], _line);
		result[i] = code;
	}
	return result, "";
}
parse_frame :: (source : *[]string, width : int, height : int) -> []u8, err:string {
	frame_lines : [..][]u8;
	frame_lines.allocator = temp;

	while 1 {
		line, ok := chop(source);
		if !ok break;
		if trim(line) == "@end" {
			if height == frame_lines.count {
				return join_arrays(..frame_lines,, temp), "";
			} else {
				return .[], tprint("invalid frame height: % (must be %)", frame_lines.count, height);
			}
		}
		frame_line, err := parse_frame_line(line);
		if err {
			return .[], tprint("can't parse frame line: %", err);
		}
		if frame_line.count != width {
			return .[], tprint("invalid frame width: % (must be %), line = %", line.count, width, line);
		}
		array_add(*frame_lines, frame_line);
	}
	return .[], "reached file end";
}

parse_task_jbms3232 :: (source : *[]string) -> Task_JBMS3232, err:string {
	SIZE :: 32;
	frames : [..][SIZE * SIZE]u8;
	frames.allocator = temp;

	while 1 {
		line, ok := chop(source);
		trimmed_line := trim(line, "\t ");
		if trimmed_line == {
		case "@end";
			return .{frames = array_copy(frames)}, "";
		case "@frame";
			d_frame, err := parse_frame(source, SIZE, SIZE);
			if err {
				return .{}, tprint("can't parse frame: %", err);
			}
			frame : [SIZE * SIZE]u8;
			memcpy(frame.data, d_frame.data, SIZE * SIZE);
			array_add(*frames, frame);
		case;
			return .{}, tprint("unexpected line: %", trimmed_line);
		}
	}
	return .{}, "reached file end";
}
parse_task_io441 :: (source : *[]string) -> Task_IO441, err:string {
	using result : Task_IO441;
	error :: (fmt : string, args : ..Any) #expand {
		deinit(*result);
		`return .{}, tprint(fmt, ..args);
	}
	while 1 {
		line, ok := chop(source);
		if !ok break;
		while 1 {
			token, ok := parse_token(*line, ";", " \t");
			if !ok || token == ";" break;
			if token == {
			case "@in";
				column, err := parse_sequence(source);
				if err error("can't parse IN: %", err);
				array_add(*request_columns, column);
				break;
			case "@out";
				column, err := parse_sequence(source);
				if err error("can't parse IN: %", err);
				array_add(*response_columns, column);
				break;
			case "@end";
				if request_columns.count > 4 || response_columns.count > 4 error("too many columns");
				return result, "";
			case;
				error("unknown token: %", token);
			}
		}
	}
	error("reached file end");
}
parse_info :: (source : *[]string) -> string, err:string {
	description : [..]string; description.allocator = temp;
	error :: (fmt : string, args : ..Any) #expand {
		`return "", tprint(fmt, ..args);
	}
	while 1 {
		line, ok := chop(source);
		{
			_line := line;
			token, ok := parse_token(*_line, ";", " \t");
			if token == "@end" {
				return join(..description, separator="\n"), "";
			}
		}
		if(line.count > 80) {
			error("too long line in info");
		}
		array_add(*description, line);
	}
	error("reached file end");
}
parse_lines_sequence :: (source : *[]string, limit : int) -> []string, err:string {
	result : [..]string;
	error :: (fmt : string, args : ..Any) #expand {
		for result free(it);
		array_free(result);
		`return .[], tprint(fmt, ..args);
	}
	while 1 {
		line, ok := chop(source);
		_line := line;
		token, ok2 := parse_token(*_line, ";", " \t");
		if token == "@end" {
			return result, "";
		}
		if limit > 0 && line.count > limit {
			error("too big line: %", line.count);
		}
		for cast([]u8) line {
			if it < #char" " || it > #char"~" {
				error("invalid character code: %", it);
			}
		}
		array_add(*result, copy_string(line));
	}
	error("reached file end");
}

parse_task_twics :: (source : *[]string) -> Task_TWICS, err:string {
	lines, err := parse_lines_sequence(source,  Machine_TWICS.MAX_LINE_SIZE);
	return .{lines}, err;
}
parse_task_twocs :: (source : *[]string) -> Task_TWOCS, err:string {
	lines, err := parse_lines_sequence(source, Machine_TWOCS.MAX_LINE_SIZE);
	return .{lines}, err;
}

parse_task :: (source : *[]string) -> Task, err:string {
	using result : Task;
	error :: (fmt : string, args : ..Any) #expand {
		deinit(*result);
		`return .{}, tprint(fmt, ..args);
	}

	while 1 {
		line, ok := chop(source);
		if !ok break;
		trimmed := trim(line);
		if !trimmed || trimmed[0] == #char";" continue;

		if trimmed == "@info" {
			info, err := parse_info(source);
			if err error("can't parse info: %", err);
			safe_replace(*description, info);
		} else if trimmed == "@req" {
			req, err := parse_names_list(source);
			if err error("can't parse requirements: %", err);
			safe_replace(*requirements, req);
		} else if trimmed == "@unlocks" {
			unl, err := parse_names_list(source);
			if err error("can't parse unlocks list: %", err);
			safe_replace(*unlocks, unl);
		} else if trimmed == {
		case "@io441";
			task_io441, err := parse_task_io441(source);
			if err error("can't parse io441: %", err);
			array_add(*tasks_io441, task_io441);
		case "@spider";
			array_add(*tasks_spider, .{});
		case "@io102";
			task_io102, err := parse_task_io102(source);
			if err error("can't parse io102: %", err);
			array_add(*tasks_io102, task_io102);
		case "@io013";
			task_io013, err := parse_task_io013(source);
			if err error("can't parse io013: %", err);
			array_add(*tasks_io013, task_io013);
		case "@twics";
			task_twics, err := parse_task_twics(source);
			if err error("can't parse twics: %", err);
			array_add(*tasks_twics, task_twics);
		case "@twocs";
			task_twocs, err := parse_task_twocs(source);
			if err error("can't parse twocs: %", err);
			array_add(*tasks_twocs, task_twocs);
		case "@jbms3232";
			task_jbms3232, err := parse_task_jbms3232(source);
			if err error("can't parse jbms3232: %", err);
			array_add(*tasks_jbms3232, task_jbms3232);
		case;
			error("invalid line: %", trimmed);
		}
	}
	return result, "";
}

load_task :: (path : string) -> Task, error:string {
	source, ok := read_entire_file(path);
	defer free(source);
	if !ok return .{}, tprint("can't open file: %", path);

	lines := split(source, cast(u8)#char"\n",, temp);

	result, err := parse_task(*lines);
	if err return .{}, tprint("can't parse task: %", err);
	// log("%\n", result);
	return result, "";
}
