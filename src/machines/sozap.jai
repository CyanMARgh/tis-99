Machine_SOZAP :: struct {
	#as using _ := General_Machine.{type = .SOZAP};
	label = LABEL_SO;

	regs : [REGS_COUNT]s16 = .[0, 0, 0, 0, 1, -1, 0, 0];
	finished : bool;
	exit_code : s16;

	program : []Instruction;
	pc_to_line : []int;

	// features : enum_flags u16 {

	// };

	#place regs;
	src, pc, acc, inp, lck, occ, buf, sp : s16; 
}

deinit :: (using machine : *Machine_SOZAP) {
	array_free(pc_to_line);
}

compile_v2 :: (machine : *Machine_SOZAP, source_lines : []string) -> error:string {
	// Line :: []string;
	// Macro :: struct {
	// 	position : int;
	// 	arguments : []string;
	// 	lines : []Line;
	// }

	// macro_set : Table(string, Macro);
	// macro_set.allocator = temp;
	// inside_macro := false;
	// current_macro : Macro;

	error :: (fmt : string, args : ..Any) #expand {
		`return tprint(fmt, ..args);
	}
	lerror :: (fmt : string, args : ..Any) #expand {
		`return tprint("[%]%", `line_id + 1, tprint(fmt, ..args));
	}

	regname_to_id :: (str : string) -> s16 #expand {
		for REG_NAMES {
			if it == str return xx it_index;
		}
		lerror("unknown register name: %", str);
		return 0;
	}

	constant :: (str : string) -> s16 #expand {
		//TODO 
		//const RIGHT 0
		//label X
		val, ok := string_to_s16(str);
		if !ok lerror("failed to parse constant: %", str);
		return val;
	}
	req :: (count : int) #expand {
		if `args.count != count lerror("wrong number of arguments: needed %, got %", count, `args.count);
	}

	program : [..]Instruction; program.allocator = temp;
	pc_to_line : [..]int; pc_to_line.allocator = temp;
	labels : Table(string, s16);

	cleaned_lines := map(source_lines, raw_line);

	for line, line_id : cleaned_lines {
		if line.count == 0 continue;
		args := Line.{line.count - 1, line.data};

		ins : Instruction;
		if line[0] == {
		case "load"; req(1);
			ins.opcode = .LOAD;
			ins.arg = regname_to_id(args[0]);
		case "to"; req(1);
			ins.opcode = .TO;
		// 
		case "label"; req(1);
		//=================
		//validate label name & search if it does not a dublicate
		// table_add(*labels, args[])


		case;
			lerror("invalid instrction or macro: %", );
		}

		if program.count >= S16_MAX - 1 {
			error("program is too big");
		}
	}

}

#scope_file
REGS_COUNT :: 8;
REG_NAMES :: string.["src", "pc", "acc", "inp", "lck", "occ", "buf", "sp"];

Opcode :: enum u16 { LOAD; TO; EXIT; SET; COMM; ADD; XOR; SHIFT; AND; }
Instruction :: struct {
	opcode : Opcode;
	arg : s16;
	#place opcode;
	bytes : [2]u16;
}

// exit codes
// 0 - OK
// 1 - general error
// 2 - invalid pc
// 3 - invalid opcode
// 4 - invalid command argument
// 5 - unsupported feature
// 6 - communication error

iterate :: (using machine_sozap : *Machine_SOZAP, sender_occid : s16, recievers : [4][]Address) {
	exit :: (code : s16) #expand {
		finished = true;
		exit_code = code;
		`return;
	}

	if finished return;
	if pc < 0 || pc >= program.count exit(2);

	send :: () #expand {
		if `src < 0 || `src >= 4 exit(6);
		if broadcast(`recievers[src], acc, sender_occid) == {
		case .ERROR;
			exit(6);
		case .OK;
		case .WAIT;
			pc = pc0;
		}
	}
	recv :: () #expand {
		if !lck pc = pc0;		
	}
	target_register :: () -> *s16 #expand {
		if arg < 0 || arg >= REGS_COUNT exit(4);
		return *regs[arg];
	}

	using I := program[pc];
	pc0 := pc;
	pc = (pc + 1) % program.count;

	if #complete I.opcode == {
	case .LOAD;
		src = target_register().*;
	case .TO;
		if arg < 0 || arg >= REGS_COUNT exit(4);
		target_register().* = src;
	case .SET;
		src = arg;
	case .COMM;
		if arg == {
		case 0; // pop
			exit(5);
		case 1; // push
			exit(5);
		case 2; send();
		case 3; recv();
		}
	case .ADD;
		acc += target_register().*;
	case .SHIFT;
		v := target_register().*;
		S :: size_of(s16);
		if v >= S {
			acc = 0;
		} else if v >= 0 {
			acc <<= v;
		} else v > -S {
			acc = acc >>,logical -v;
		} else {
			acc = 0;
		}
	case .AND;
		acc &= target_register().*;
	case 
	case;
		exit(3);
	}
}
