#import "Compiler";
#import "Basic";
#import "Process";
Iprof :: #import "Iprof";

DEBUG :: true;
IPROF :: false;
PACK :: true;
LOG_KEYS :: true;
EXECUTABLE_NAME :: "tis99"; 
IMPORT_EXTRA_PATH :: "..";

// TODO:
// REPORT load_task(name,, temp)

// manpage color formatting
// "are you sure?" window for deletion of non-empty circuits / solutions
// error popup at left-bottom with timeout

// Task_1234   ->  Machine_1234.Task
// tis-3,sm255,q5,jbms32   are also tester circuits in some sense
// i: change circuit id

// CIRCUITS:
// (beshtau) multithread circuit
// (2dfy) hardware rasterizer
// text output debug screen
// (tis-4) with advanced recv    (do we need?)
// single-arg processor 
//       + extra for increasing speed
// appolo-like memory storage
// random generator circuit
// "zip" circuit (Q6)

// DONE
// level unlocking:
//      solution unlocks new circuit
// message leveles
//     "Require" solved levels x, y, z...
// move camera in simulation (S - step)
// "Spider" circuit
//		1. raw text
//		2. xor-ed text
//		3. 10 random characters
//      4. caesar encoded text
//      5. parsed integer key 
// Copy circuit
// fix #-ffff maybe
// Q5 ordered distribution
// multiple player savefiles
// make functions solution_file_path(player_name, level_name, solution_name) & task_file_path
// autosave 1 per N seconds & save at ctrl+q
// big file names test
// Draw circuit only if intersects 
// .sav compression
// level/solution[*] on bottom  <- DO AND TEST THIS FIRST
// show initial_popup only on first screen
// player info file
// colored levels/saves
// write current cost
// screen(out) circuit
// ctrl+shift+up/down
// table of contents
// show solutions cost in menu
// solutions scroll
// three-four solution modes
// add initial state to Q5 for correct restart
// delete key in editor
// ctrl + <-/-> in editor
// copy&paste line (global buffer)
// help ascii table
// "split text" task
// .MOVE substate
// draw cost at bottom
// split io to multiple
// text generator, text dispay
// move all modes to config
// colorfull bottom-left label
// move focus/view during simulation
// a: try to focus to circuit under cursor
// change wires color
// remove corner from canvas & make screen/raw canvases
// "select circtuit" popup

#run {
	assert(OS == .LINUX);
	set_build_options_dc(.{do_output=false});
	build();

	build_name := "tis99_build";
	#if PACK {
		run_command("rm", "-f", tprint("%.zip", build_name));
		run_command("ln", "-s", ".", "tis99_build");
		run_command("zip", "-r",
			tprint("%.zip", build_name), 
			tprint("%/tasks/", build_name),
			tprint("%/tis99", build_name),
			capture_and_return_output = true
		);
		run_command("rm", "-f", build_name);		
	}
}

build :: () {
	w := compiler_create_workspace();
	if !w {
		print("Workspace createion failed!\n");
		return;
	}
	using target_options := get_build_options(w);
	
	text_output_flags = 0;

	#if DEBUG {
	} else {
		llvm_options.bitcode_optimization_setting = .O3;
		stack_trace = false;
		array_bounds_check = .OFF;
		cast_bounds_check = .OFF;
		// math_bounds_check = .OFF;
		null_pointer_check = .OFF;
		dead_code_elimination = .ALL;
		backtrace_on_crash = .OFF;
	}
	import_path = .[import_path[1], IMPORT_EXTRA_PATH];
	output_executable_name = EXECUTABLE_NAME;

	set_build_options(target_options, w);
	#if IPROF {
		iprof_flags : Intercept_Flags;
		iprof := Iprof.get_plugin();
		defer Iprof.finish(iprof);
		Iprof.before_intercept(iprof, *iprof_flags);
		iprof.workspace = w;
	}
	compiler_begin_intercept(w);
	#if IPROF {
		Iprof.add_source(iprof);
	}
	add_build_file(tprint("%1/src/main.jai", #filepath), w);
	add_build_string(tprint("DEBUG :: %;\n", DEBUG), w);
	add_build_string(tprint("LOG_KEYS :: %;\n", LOG_KEYS), w);

	while 1 {
		message := compiler_wait_for_message();
		#if IPROF {
			Iprof.message(iprof, message);
		}
		if message.kind == {
			case .COMPLETE;
			break;
		}
	}
	compiler_end_intercept(w);
}
