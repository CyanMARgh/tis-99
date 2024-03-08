#load "tis3.jai";
#load "io441.jai";
#load "sm255.jai";
#load "io102.jai";
#load "io013.jai";
#load "twics.jai";
#load "twocs.jai";
#load "q5.jai";
#load "jbms32.jai";
#load "jbms3232.jai";
#load "spider.jai";
// #load "sozap.jai";

#load "labels.jai";
#load "models.jai";

Machine_Type :: enum s8 {
	NONE	:: -1;
	IO441	::  0;
	TIS3	::  1;
	SM255	::  2;
	IO102	::  3;
	IO013	::  4;
	TWICS	::  5;
	TWOCS	::  6;
	Q5    	::  7;
	JBMS32	::  8;
	JBMS3232::  9;
	SPIDER  :: 10;
}
MACHINE_TYPES_LIST :: Type.[
	Machine_IO441, 
	Machine_TIS3,
	Machine_SM255,
	Machine_IO102,
	Machine_IO013,
	Machine_TWICS,
	Machine_TWOCS,
	Machine_Q5,
	Machine_JBMS32,
	Machine_JBMS3232,
	Machine_SPIDER
];

MACHINE_TYPE_COUNT :: MACHINE_TYPES_LIST.count;

General_Machine :: struct {
	VT :: struct {		
		c_draw : (canvas : *Canvas, machine : *General_Machine, corner : ivec2)->() = null;
		init_circuit : (circuit : *Circuit, _task : Task, _model_subid : int)->() = null;
		input_communicator := (machine : *General_Machine, input_socket : s16, sender_occid : s16, only_ask : bool, value : s16) -> bool  { assert(false); return false; };
		iterate : (using machine : *General_Machine, sender_occid : s16, recievers : [4][]Address)->() = null;
		destructor := (machine : *General_Machine) {};
		is_task_satisfied := (machine : *General_Machine) -> bool {assert(false); return false;};
		reset := (machine : *General_Machine) {}
		compiler := (machine : *General_Machine, lines : []string)->string{return "";}
		current_line := (machine : *General_Machine) -> int { return -1; }
		is_tester := false;
	}
	vt := () => VT.{};

	label : string;
	type : Machine_Type;
}
complete_vt :: (m : *General_Machine) -> bool {
	using m.vt();
	return 
		c_draw != null &&
		input_communicator != null &&
		iterate != null &&
		destructor != null &&
		is_task_completed != null &&
		reset != null
	;
}
Address :: struct {
	machine : *General_Machine;
	socket_id : s16;
}

is_task_satisfied_default :: (machine : *General_Machine, $T : Type) -> bool {
	return (cast(*T)machine).state == .HALT;
}

can_recieve :: (using target : Address, sender_occid : s16) -> bool {
	return machine.vt().input_communicator(machine, socket_id, sender_occid, true, 0);
}
handle_input :: (using address : Address, value : s16, sender_occid : s16) {
	assert(can_recieve(address, sender_occid));
	machine.vt().input_communicator(machine, address.socket_id, sender_occid, false, value);
}
broadcast :: (addresses : []Address, value : s16, sender_circuit_id : s16, sender_pin_id : s16) -> enum u8 {ERROR; OK; WAIT;} {
	sender_occid := sender_circuit_id | (sender_pin_id << 8);
	if !addresses return .ERROR;
	for addresses {
		if !can_recieve(it, sender_occid) return .WAIT;
	}
	for addresses {
		handle_input(it, value, sender_occid);
	}
	return .OK;
}

iterate :: (using general_machine : *General_Machine, sender_occid : s16, recievers : [4][]Address) {
	general_machine.vt().iterate(general_machine, sender_occid, recievers);
}
deinit :: (machine : *General_Machine) {
	machine.vt().destructor(machine);
}

is_task_satisfied :: (machine : *General_Machine) -> bool {
	return machine.vt().is_task_satisfied(machine);
}

reset :: (machine : *General_Machine) {
	machine.vt().reset(machine);
}

current_line :: (machine : *General_Machine) -> int {
	return machine.vt().current_line(machine);
}