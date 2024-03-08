DEFAULT_PLAYER :: "default_player";

tasks_directory :: "tasks";
saves_directory :: (player_name : string) -> string {
	return tprint("%/saves", player_name);
}
saves_directory_for_task :: (player_name : string, task : string) -> string {
	return tprint("%/%", saves_directory(player_name), task);
}
task_file :: (task : string) -> string {
	return tprint("%/%.task", tasks_directory, task);
}
solution_file :: (player_name : string, task : string, solution_name : string) -> string {
	return tprint("%/%.sav", saves_directory_for_task(player_name, task), solution_name);
}
player_info_file :: (player_name : string) -> string {
	return tprint("%/main.player", player_name);
}


save_current_solution :: (using game : Game) {
	make_directory_if_it_does_not_exist(saves_directory_for_task(DEFAULT_PLAYER, target_level_info.name), recursive = true);
	save_to_file(
		solution_file(DEFAULT_PLAYER, target_level_info.name, target_solution_info.name),
	edit_solution.breadboard);
}
open_empty_solution :: (using game : *Game) {
	W, H :: 800, 400;
	safe_replace(*edit_solution.breadboard, .{});
	error := init(*edit_solution.breadboard, ivec2.{W, H}, target_level_info.name);
	if error {
		log("error: %\n", error);
	} else {
		//TODO cleanup
		safe_replace(*edit_solution.save_file_name, copy_string(target_solution_info.name));
		state = .EDIT_SOLUTION;
	}
}
try_load_target_solution :: (using game : *Game) -> bool {
	make_directory_if_it_does_not_exist(saves_directory_for_task(DEFAULT_PLAYER, target_level_info.name), recursive = true);
	solution_file_path := solution_file(DEFAULT_PLAYER, target_level_info.name, target_solution_info.name);
	safe_replace(*edit_solution.breadboard, .{});
	if load_from_file(*edit_solution.breadboard, solution_file_path) {
		safe_replace(*edit_solution.save_file_name, copy_string(target_solution_info.name));
		edit_solution.breadboard.untouched_after_finish = target_solution_info.state == .SOLVED;

		edit_solution.breadboard.task.unlocked = player_info.unlocked;

		state = .EDIT_SOLUTION;
		return true;
	}
	return false;
}

load_and_fix_player_info :: () -> Player_Info {
	make_directory_if_it_does_not_exist(tasks_directory);
	tasks_files_list := files_from_directory(tasks_directory, "task",, temp);
	player_info : Player_Info;
	{
		err : string;
		player_info, err = load_player_info(player_info_file(DEFAULT_PLAYER));
		if err log("can't load player info: %\n", err);
	}

	for tasks_files_list add_level_if_it_does_not_exists(*player_info, it);
	sort_levels_by_name(*player_info);

	make_directory_if_it_does_not_exist(saves_directory(DEFAULT_PLAYER));	
	for *level : player_info.levels {
		saves_directory_for_this_level := saves_directory_for_task(DEFAULT_PLAYER, level.name);
		make_directory_if_it_does_not_exist(saves_directory_for_this_level, recursive = true);

		solution_files_list := files_from_directory(saves_directory_for_this_level, "sav",, temp);
		for solution_files_list {
			if it.count > MAX_FILE_NAME_SIZE continue;
			add_solution_if_it_does_not_exists(level, it);
		}
		sort_solutions_by_name(level);
	}
	refresh_hidden_levels(*player_info);
	return player_info;
}
load_player_info :: (using game : *Game) {
	safe_replace(*player_info, load_and_fix_player_info());
	// safe_replace(*start_menu.level_files, directory_content_with_extension("saves", "sav"));
}
save_player_info :: (using game : Game) {
	write_entire_file(player_info_file(DEFAULT_PLAYER), to_string(game.player_info,, temp));
}