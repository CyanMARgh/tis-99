Machine_TIS3 :: struct {
	#as using _ := General_Machine.{label = LABEL_TIS3, type = .TIS3 };
	vt=()=>VT.{
		c_draw = c_draw,
		input_communicator = input_communicator,
		iterate = iterate,
		destructor = destructor,
		reset = reset,
		compiler = compile_v1,
		current_line = current_line,
		init_circuit = init_circuit
	};

	MODEL_NAME :: "TIS-3";
	PROG_ROWS, PROG_WIDTH, STATE_WIDTH :: 17, 20, 12;	
	SIZE_X, SIZE_Y :: (1 + PROG_WIDTH + 2) + (STATE_WIDTH + 1), (1 + PROG_ROWS + 1);
	CIRCUIT_SIZE :: ivec2.{SIZE_X, SIZE_Y};
	EDITOR_SIZE :: ivec2.{PROG_WIDTH, PROG_ROWS};

	program : []Instruction;
	line_ids : []int;

	using state : struct {
		regs : [REG_COUNT]s16 = .[0, 0, -1, 1, 0];
		pc : int;
		mode : enum u8 {RUNNING; HALTED; ERROR;} = .RUNNING;
	};
}

#scope_file
init_circuit :: (circuit : *Circuit, _task : Task, _model_subid : int) {
	using machine := New(Machine_TIS3);

	circuit.* = .{
		editor = make_block_editor(EDITOR_SIZE),
		size = CIRCUIT_SIZE,
		machine = machine,
		machine_offset = .{xx(PROG_WIDTH + 2), 0},
		cost = 50,
		pins = array_copy(Pin.[
			.{.{ 0,  1}, 0, true },
			.{.{SIZE_X - 1,  SIZE_Y / 2}, 0, false},
			.{.{SIZE_X / 2, SIZE_Y - 1}, 1, false},
			.{.{ 0,  SIZE_Y / 2}, 2, false},
			.{.{SIZE_X / 2,  0}, 3, false},
		])
	};
}

compile_v1 :: (machine : *General_Machine, source_lines : []string) -> error:string {
	machine_tis3 := cast(*Machine_TIS3)machine;
	is_reserved_name :: (name : string) -> bool {
		return array_find(REG_NAMES, name) || array_find(INSTRUCTION_NAMES, name);
	}
	is_valid_name :: (name : string) -> bool {
		is_name_begin :: (c : u8) -> bool {
			return
				(c >= #char"a" && c <= #char"z") ||
				(c >= #char"A" && c <= #char"Z") ||
				c == #char"_"
			;
		}
		is_name_part :: (c : u8) -> bool {
			return is_name_begin(c) || (c >= #char"0" && c <= #char"9");
		}
		if name.count < 1 return false;
		if !is_name_begin(name[0]) return false;
		for i : 1..name.count-1 {
			if !is_name_part(name[i]) return false;
		}
		return true;
	}

	current_command_id := 0;
	Labels_Map :: Table(string, int);
	labels_map : Labels_Map;
	labels_map.allocator = temp;

	instructions : [..]Instruction;
	line_ids : [..]int;

	labels_pass :: (labels_map : *Labels_Map, current_command_id : *int, line : string, line_id : int) -> error:string {
		tokens := parse_command(line);
		if tokens.count >= 2 && tokens[1] == ":" {
			label := tokens[0];
			if !is_valid_name(label) return tprint("%: invalid label name: %", line_id + 1, label);
			if is_reserved_name(label) return tprint("%: reserved label name: %", line_id + 1, label);
			valptr, new := find_or_add(labels_map, label);
			if !new return tprint("%: label duplicate: %", line_id + 1, label);
			valptr.* = current_command_id.*;
			tokens.count -= 2; tokens.data += 2;
		}		
		if tokens.count != 0 {
			current_command_id.* += 1;
		}
		return "";
	}

	commands_pass :: (line_ids : *[..]int, instructions : *[..]Instruction, labels_map : *Labels_Map, current_command_id : *int, line : string, line_id : int) -> error:string {
		tokens := parse_command(line);
		if tokens.count >= 2 && tokens[1] == ":" {
			tokens.count -= 2; tokens.data += 2;
		}

		if tokens.count == 0 return "";
		//TODO add constants
		current_command_id.* += 1;

		regid :: (str : string) -> s16 #expand {
			for REG_NAMES {
				if str == it return xx it_index;
			}
			`return tprint("%: invalid register name: %", `line_id + 1, str);
		}

		value_or_regid :: (str : string) -> is_regid:bool, s16 #expand {
			for REG_NAMES {
				if str == it return true, xx it_index;
			}
			val, ok := string_to_s16(str);
			if !ok `return tprint("%: failed to parse value/register: %", `line_id + 1, str);
			return false, val;
		}
		value :: (str : string) -> s16 #expand {
			val, ok := string_to_s16(str);
			if !ok `return tprint("%: failed to parse value: %", `line_id + 1, str);
			return val;
		}

		instruction_id_by_label :: (label : string) -> s16 #expand {
			id, ok := table_find(labels_map, label);
			if !ok `return tprint("%: failed to find label: %", `line_id + 1, label);
			return xx id;
		}

		opname := tokens[0];
		args := tokens;
		args.count -= 1; args.data += 1;
		need :: (count : int) #expand {
			if args.count != count {
				`return tprint("%: wrong number of arguments: needed %, got %", `line_id + 1, count, args.count);
			}
		}

		ins : Instruction;
		if opname == {
			case "nop"; need(0);
				ins.opcode = .NOP;
			case "inc"; need(1);
				ins.opcode = .INC;
				ins.arg1 = regid(args[0]);
			case "dec"; need(1);
				ins.opcode = .DEC;
				ins.arg1 = regid(args[0]);
			case "halt"; need(0);
				ins.opcode = .HALT;
			case "error"; need(0);
				ins.opcode = .ERROR;
			case "add"; need(2);
				ins.arg1 = regid(args[0]);
				is_regid, regid_or_val := value_or_regid(args[1]);
				ins.arg2 = regid_or_val;
				ins.opcode = ifx is_regid then .ADD_R else .ADD_V;
			case "sub"; need(2);
				ins.arg1 = regid(args[0]);
				is_regid, regid_or_val := value_or_regid(args[1]);
				ins.arg2 = regid_or_val;
				ins.opcode = ifx is_regid then .SUB_R else .SUB_V;
			case "mov"; need(2);
				ins.arg1 = regid(args[0]);
				is_regid, regid_or_val := value_or_regid(args[1]);
				ins.arg2 = regid_or_val;
				ins.opcode = ifx is_regid then .MOV_R else .MOV_V;
			case "jmp"; need(1);
				ins.opcode = .JMP;
				ins.arg1 = instruction_id_by_label(args[0]);
			case "jz"; need(1);
				ins.opcode = .JZ;
				ins.arg1 = instruction_id_by_label(args[0]);
			case "jnz"; need(1);
				ins.opcode = .JNZ;
				ins.arg1 = instruction_id_by_label(args[0]);
			case "jlz"; need(1);
				ins.opcode = .JLZ;
				ins.arg1 = instruction_id_by_label(args[0]);
			case "jgz"; need(1);
				ins.opcode = .JGZ;
				ins.arg1 = instruction_id_by_label(args[0]);
			case "send"; need(2);
				ins.arg1 = value(args[0]);
				is_regid, regid_or_val := value_or_regid(args[1]);
				ins.arg2 = regid_or_val;
				ins.opcode = ifx is_regid then .SEND_R else .SEND_V;
			case "recv"; need(0);
				ins.opcode = .RECV;
			case;
				return tprint("%: unknown instruction: %", line_id, opname);
		}

		array_add(instructions, ins);
		array_add(line_ids, line_id);

		return "";
	}

	for line, line_id : source_lines {
		error := labels_pass(*labels_map, *current_command_id, line, line_id);
		if error {
			array_free(instructions);
			array_free(line_ids);
			return error;
		}
	}

	for line, line_id : source_lines {
		error := commands_pass(*line_ids, *instructions, *labels_map, *current_command_id, line, line_id);
		if error {
			array_free(instructions);
			array_free(line_ids);
			return error;
		}
	}

	safe_replace(*machine_tis3.program, instructions);
	safe_replace(*machine_tis3.line_ids, line_ids);
	return "";
}

current_line :: (machine : *General_Machine) -> int {
	using cast(*Machine_TIS3)machine;
	return ifx mode == .RUNNING && pc >= 0 && pc < line_ids.count then line_ids[pc] else -1;
}
reset :: (machine : *General_Machine) {
	(cast(*Machine_TIS3)machine).state = .{};
}
destructor :: (machine : *General_Machine) {
	using cast(*Machine_TIS3)machine;
	array_free(program);
	array_free(line_ids);
}
iterate :: (machine : *General_Machine, sender_occid : s16, recievers : [4][]Address) {
	using machine_tis3 := cast(*Machine_TIS3)machine;

	if mode != .RUNNING || program.count == 0 return;
	if pc < 0 || pc >= program.count {
		mode = .ERROR;
		return;
	}

	I := program[pc];
	pc0 := pc;
	pc = (pc + 1) % program.count;

	check_reg :: (id : s16) {
		assert(id >= 0 && id < REG_COUNT, "arg1 = %", id);
	}

	send :: (value : s16) #expand {
		if `arg1 < 0 || `arg1 > 3 {
			`mode = .ERROR;
			return;
		}
		if broadcast(`recievers[arg1], value, sender_occid, `arg1) == {
			case .ERROR;
			`mode = .ERROR;
			case .OK;
			case .WAIT;
			pc = pc0;
		}
	}

	using I;
	if #complete opcode == {
		case .NOP;
		case .INC;
			check_reg(arg1);
			regs[arg1] += 1;
		case .DEC;
			check_reg(arg1);
			regs[arg1] -= 1;
		case .HALT; 
			mode = .HALTED;
		case .ERROR;
			mode = .ERROR;
		case .ADD_R;
			check_reg(arg1);
			check_reg(arg2);
			regs[arg1] = regs[arg1] + regs[arg2];
		case .ADD_V;
			check_reg(arg1);
			regs[arg1] = regs[arg1] + arg2;
		case .SUB_R;
			check_reg(arg1);
			check_reg(arg2);
			regs[arg1] = regs[arg1] - regs[arg2];
		case .SUB_V;
			check_reg(arg1);
			regs[arg1] = regs[arg1] - arg2;
		case .MOV_R;
			check_reg(arg1);
			check_reg(arg2);
			regs[arg1] = regs[arg2];
		case .MOV_V;
			check_reg(arg1);
			regs[arg1] = arg2;
		case .JMP;
			pc = arg1;

		case  .JZ;
			if regs[IF_FLAG_REGISTER] == 0 then pc = arg1;
		case  .JNZ;
			if regs[IF_FLAG_REGISTER] != 0 then pc = arg1;
		case  .JGZ;
			if regs[IF_FLAG_REGISTER]  > 0 then pc = arg1;
		case  .JLZ;
			if regs[IF_FLAG_REGISTER]  < 0 then pc = arg1;

		case .SEND_V;
			send(arg2);
		case .SEND_R;
			send(regs[arg2]);
		case .RECV;
			if !regs[SEND_LOCK_REGISTER] pc = pc0;
	}
	if pc == program.count then pc = 0;
}

Opcode :: enum u16 {
	NOP;
	INC; DEC;
	HALT; ERROR;
	ADD_R; ADD_V;
	SUB_R; SUB_V;
	MOV_R; MOV_V;
	JMP;
	JZ; JNZ; JGZ; JLZ;
	SEND_R; SEND_V;
	RECV;
};
Instruction :: struct {
	opcode : Opcode;
	arg1, arg2 : s16;
	#place opcode;
	bytes : [4]u16;
}

INSTRUCTION_NAMES :: string.["nop", "halt", "add", "sub", "mov", "inc", "jmp", "jz", "jnz", "jgz", "jlz", "send", "recv"];
// REG_NAMES :: string.["acc", "buf", "occ", "lck", "inp"];
REG_NAMES :: string.["a", "b", "c", "d", "e"];
REG_COUNT :: REG_NAMES.count;

IF_FLAG_REGISTER :: 0;
//---
SEND_OCCUPANT_REGISTER :: 2;
SEND_LOCK_REGISTER :: 3;
SEND_INPUT_REGISTER :: 4;

c_draw :: (canvas : *Canvas, machine : *General_Machine, left_top : ivec2) {
	using machine_tis3 := cast(*Machine_TIS3)machine;

	y := 1;
	print_line :: (str : string, mode := MODE_REGISTER) #expand {
		c_print_ascii(canvas, left_top + .{1, xx y}, mode, str);
		y += 1;
	}
	for regs {
		print_line(tprint("%  = %", REG_NAMES[it_index], pad(7, tprint("%", it))));
	}
	print_line(tprint("PC = %", pad(7, tprint("%", pc))));
	print_line(
		tprint("%", mode),
		ifx mode == .RUNNING then MODE_WAIT
		else ifx mode == .ERROR then MODE_ERROR else MODE_OK
	);
}

input_communicator :: (machine : *General_Machine, socket_id : s16, sender_occid : s16, only_ask : bool, value : s16) -> bool {
	using cast(*Machine_TIS3)machine;
	if only_ask {
		assert(socket_id == 0);
		occ := regs[SEND_OCCUPANT_REGISTER];
		lck := regs[SEND_LOCK_REGISTER];

		return !lck && (occ == -1 || occ == sender_occid);
	} else {
		regs[SEND_OCCUPANT_REGISTER] = sender_occid;
		regs[SEND_LOCK_REGISTER] = 1;
		regs[SEND_INPUT_REGISTER] = value;

		return false;
	}
}
