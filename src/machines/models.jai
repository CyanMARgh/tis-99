gen_circuit :: (breadboard : Breadboard, _corner : ivec2, _model_id : int, _model_subid : int) -> Circuit, bool #must {
	using result : Circuit;

	sic := model_subids_count(breadboard.task);
	if _model_id < 0 || _model_subid >= MACHINE_TYPE_COUNT return .{}, false;
	if _model_subid < 0 || _model_subid >= sic[_model_id] return .{}, false;

	CIRCUIT_INITIALIZERS_LIST[_model_id](*result, breadboard.task, _model_subid);

	model_id = _model_id;
	model_subid = _model_subid;
	corner = _corner;
	assert(complete_vt(result.machine));
	return result, true;
}
CIRCUIT_INITIALIZERS_LIST :: #run map(MACHINE_TYPES_LIST, T => ifx 1 {
	tis := cast(*Type_Info_Struct)T;
	mem := cast(*General_Machine)alloc(tis.runtime_size);
	tis.initializer(mem);
	mem.vt().init_circuit;
});

is_task_completed :: (using breadboard : Breadboard) -> bool {
	//=====
	oks_all : [MACHINE_TYPE_COUNT][]bool = .[
		NewArray(task.tasks_io441.count, bool,, temp),
		.[],
		.[],
		NewArray(task.tasks_io102.count, bool,, temp),
		NewArray(task.tasks_io013.count, bool,, temp),
		NewArray(task.tasks_twics.count, bool,, temp),
		NewArray(task.tasks_twocs.count, bool,, temp),
		.[],
		.[],
		NewArray(task.tasks_jbms3232.count, bool,, temp),
		NewArray(task.tasks_spider.count, bool,, temp),
	];
	
	for circuits {
		if it.machine.vt().is_tester {
			if is_task_satisfied(it.machine) {
				oks_all[it.machine.type][it.model_subid] = true;
			}			
		}
	}
	return and(map(oks_all, and));
}

model_subids_count :: (using task : Task) -> []int #expand {
	//====
	result : [MACHINE_TYPE_COUNT]int = .[
		tasks_io441.count,
		xx unlocked.tis3,
		xx unlocked.sm255,
		tasks_io102.count,
		tasks_io013.count,
		tasks_twics.count,
		tasks_twocs.count,
		xx unlocked.q5,
		xx unlocked.jbms32,
		tasks_jbms3232.count,
		tasks_spider.count
	];

	return result;
}
total_submodel_count :: (using task : Task) -> int {
	S := 0;
	sic := model_subids_count(task);
	for sic {
		S += it;
	}
	return S;
}

model_and_submodel_by_line :: (using task : Task, line_id : int) -> model:int, submodel:int, ok:bool {
	model, submodel := 0, line_id;
	try :: (N : int) #expand {
		if `submodel >= N {
			`submodel -= N;
			`model += 1;
		} else {
			`return `model, `submodel, true;
		}
	}

	sic := model_subids_count(task);
	for sic {
		try(it);
	}
	return 0, 0, false;
}
model_name_line :: (using task : Task, line_id : int) -> model:string, ok:bool {
	model, submodel := 0, line_id;
	try :: (N : int) #expand {
		if `submodel >= N {
			`submodel -= N;
			`model += 1;
		} else {
			base_name := MODEL_NAMES[model];
			assert(N > 0);
			`return ifx N == 1 then base_name else tprint("% [%]", base_name, submodel), true;
		}
	}
	sic := model_subids_count(task);
	for sic {
		try(it);
	}
	return "", false;
}

#insert -> string {
	result : String_Builder;
	append(*result, "MODEL_NAMES :: string.[");
	for 0..MACHINE_TYPE_COUNT-1 {
		print_to_builder(*result, "MACHINE_TYPES_LIST[%].{}.MODEL_NAME,", it);
	}
	append(*result, "];");
	return builder_to_string(*result);
}