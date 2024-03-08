reset_tick_state :: () {
	editor_tick_state = 0;
}
next_tick_state :: () {
	editor_tick_state = (editor_tick_state + 1) % 1000;
}

Block_Editor :: struct {
	size : ivec2; 
	buffer : []u8;
	cursor : struct {
		using pos : ivec2;
		saved_x : s32;
	};
	select_zone_y : s32 = -1;
}
make_block_editor :: (_size : ivec2) -> Block_Editor {
	return .{size = _size, buffer = NewArray(_size.x * _size.y, u8)};
}
deinit :: (using editor : *Block_Editor) {
	array_free(buffer);
}
at :: inline (using editor : Block_Editor, x : int, y : int) -> u8 {
	assert(x >= 0 && x < size.x);
	assert(y >= 0 && y < size.y);
	return buffer[y * size.x + x];
}
at :: inline (using editor : Block_Editor, pos : ivec2) -> u8 {
	assert(pos.x >= 0 && pos.x < size.x);
	assert(pos.y >= 0 && pos.y < size.y);
	return buffer[pos.y * size.x + pos.x];
}
set :: (using editor : Block_Editor, pos : ivec2, value : u8) {
	assert(pos.x >= 0 && pos.x < size.x);
	assert(pos.y >= 0 && pos.y < size.y);
	buffer[pos.y * size.x + pos.x] = value;
}
get_row_view :: (using editor : Block_Editor, row : int) -> []u8, length:int {
	assert(row >= 0 && row < size.y);
	view := array_view(buffer, row * size.x, size.x);
	for view {
		if !it return view, it_index;
	}
	return view, size.x;
}
trimmed_line :: (using editor : Block_Editor, row : int) -> string {
	s, l := get_row_view(editor, row);
	s.count = l;
	return trim(xx s);
}
get_lines :: (using editor : Block_Editor, allocator := temp) -> []string {
	result := NewArray(size.y, string,, allocator = allocator);
	for * result {
		view, l := get_row_view(editor, it_index);
		view.count = l;
		it.* = xx view;
	}
	return result;
}

c_draw :: (canvas : *Canvas, using editor : Block_Editor, left_top : ivec2, simulation_mode := false, highlighted_line := -1, charset := box_style_passive) {
	if size == .{0, 0} return;
	c_box(canvas, .{corner = left_top, size = size + .{3, 2}}, charset);

	is_highlighted :: (y : int) -> bool #expand {
		if simulation_mode {
			return y == highlighted_line;
		} else {
			if select_zone_y == -1 return false;
			mi := min(cursor.y, select_zone_y);
			ma := max(cursor.y, select_zone_y);
			return mi <= y && y <= ma;
		}
	}

	for y : 0..size.y-1 {
		_line, l := get_row_view(editor, y);
		line := string.{l, _line.data};
		hl := is_highlighted(y);
		if hl then line = tprint("% ", line);
		c_printl_ascii(
			canvas,
			left_top + .{1, xx (y + 1)},
			ifx !line then MODE_EDITOR_EMPTY else
			ifx is_highlighted(y) then MODE_EDITOR_INVERTED else MODE_EDITOR_DEFAULT,			
			ifx !line then "~" else line
		);
	}
}


draw_cursor :: (builder : *String_Builder, using editor : Block_Editor, left_top : ivec2) {
	b_cursor_set_visibility(builder, true);
	b_move_cursor(builder, left_top + cursor.pos + .{1, 1});
}

//TODO 
c_draw_cursor :: (canvas : *Canvas, using editor : Block_Editor, left_top : ivec2) {
	if editor_tick_state % 50 < 25 {
		c_putchar(canvas, .{at_or_eol(editor, cursor.pos, #char" "), MODE_EDITOR_CURSOR}, left_top + cursor.pos + .{1, 1});
	}
}

Direction :: enum u8 {
	LEFT; RIGHT; DOWN; UP;
}

at_or_eol :: (using editor : Block_Editor, pos : ivec2, eol := #char"\n") -> u8 {
	char := ifx pos.x >= size.x then 0 else at(editor, pos);
	return xx ifx char else xx eol;
}

one_left :: (using editor : Block_Editor) -> bool, ivec2 {
	if cursor.x > 0 {
		return true, .{cursor.x - 1, cursor.y};
	} else if cursor.y {
		_, l := get_row_view(editor, cursor.y - 1);
		return true, .{xx l, cursor.y - 1};
	} else {
		return false, cursor.pos;
	}
}
one_right :: (using editor :*Block_Editor) -> bool, ivec2 {
	_, l := get_row_view(editor, cursor.y);
	if cursor.x < l {
		return true, .{cursor.x + 1, cursor.y};
	} else if cursor.y < size.y - 1 {
		return true, .{0, cursor.y + 1};
	}
	return false, cursor.pos;
}
one_up :: (using editor : Block_Editor) -> bool, ivec2 {
	if cursor.y {
		_, l := get_row_view(editor, cursor.y - 1);
		return true, .{min(cursor.saved_x, xx l), cursor.y - 1};
	} else if cursor.x > 0 {
		return true, .{0, 0};
	} else {
		return false, cursor.pos;
	}
}
one_down :: (using editor : Block_Editor) -> bool, ivec2 {	
	if cursor.y < size.y-1 {
		_, l := get_row_view(editor, cursor.y + 1);
		return true, .{min(cursor.saved_x, xx l), cursor.y + 1};
	} else {
		_, l := get_row_view(editor, cursor.y);
		return cursor.x < l, .{xx l, cursor.y};
	}
}

Char_Category :: enum u8 {
	SPACE;
	NUMBER;
	LETTER;
	SPECIAL;
	EOL;
}
catof :: (char : u8) -> Char_Category {
	if (char >= #char"a" && char <= #char"z")
       || (char >= #char"A" && char <= #char"Z") {
       	return .LETTER;
	}
	if char >= #char"0" && char <= #char"9" {
		return .NUMBER;
	}
	if char == #char" " {
		return .SPACE;
	}
	if char == #char"\n" {
		return .EOL;
	}
	return .SPECIAL;
}

move :: (using editor : *Block_Editor, direction : Direction) -> bool {
	ok := true;
	if direction == {
	case .LEFT;
		ok, cursor.pos = one_left(editor);
		cursor.saved_x = cursor.x;
	case .RIGHT;
		ok, cursor.pos = one_right(editor);
		cursor.saved_x = cursor.x;
	case .UP;
		ok, cursor.pos = one_up(editor);
	case .DOWN;
		ok, cursor.pos = one_down(editor);
	}
	return ok;
}
ctrl_move :: (using editor : *Block_Editor, direction : Direction) -> bool {
	if direction == {
	case .UP; assert(false);
	case .DOWN; assert(false);
	case .LEFT;
		at_least_once := false;
		cat := Char_Category.SPACE;

		while 1 {
			mooved, new_pos := one_left(editor);
			at_least_once |= mooved;
			if !mooved break;
			newcharcat := catof(at_or_eol(editor, new_pos));
			if cat != .SPACE && newcharcat != cat {
				break;
			}
			cat = newcharcat;
			cursor.pos = new_pos;
		}

		cursor.saved_x = cursor.x;
		return at_least_once;
	case .RIGHT; 
		at_least_once := false;
		cat := Char_Category.SPACE;

		while 1 {
			mooved, new_pos := one_right(editor);
			at_least_once |= mooved;
			if !mooved break;
			newcharcat := catof(at_or_eol(editor, cursor.pos));
			if cat != .SPACE && newcharcat != cat {
				break;
			}
			cat = newcharcat;
			cursor.pos = new_pos;
		}

		cursor.saved_x = cursor.x;
		return at_least_once;
	}
	return false;
}

newline :: (using editor : *Block_Editor) -> ok:bool {
	if cursor.y == size.y - 1 return false;
	for get_row_view(editor, size.y - 1) {
		if it && it != #char" " {
			return false;
		}
	}

	memcpy(
		buffer.data + (cursor.y + 2) * size.x,
		buffer.data + (cursor.y + 1) * size.x,
		(size.y - cursor.y - 2) * size.x
	);// move rest down

	row_view := get_row_view(editor, cursor.y);
	right_part := row_view;
	right_part.count -= cursor.x;
	right_part.data += cursor.x;
	assert(right_part.count >= 0);

	memcpy(
		buffer.data + (cursor.y + 1) * size.x,
		right_part.data,
		right_part.count
	); //place right part on released line
	memset(
		right_part.data,
		#char"\0",
		size.x - cursor.x
	); // fill mooved part with zeroes
	memset(
		buffer.data + (cursor.y + 1) * size.x + right_part.count,
		#char"\0",
		size.x - right_part.count
	); // cleanup rest of released line

	cursor.x = 0;
	cursor.y += 1;
	cursor.saved_x = cursor.x;
	return true;
}
validate_buffer :: (using editor : Block_Editor) -> bool #must {
	if size == .{0, 0} return true;
	if cursor.x < 0 || cursor.y < 0 || cursor.x > size.x || cursor.y >= size.y {
		log("cursor out of bounds: % / %\n", cursor, size);
		return false;
	}
	_, l := get_row_view(editor, cursor.y);
	if cursor.x > l {
		log("cursor out of place(too short line)\n");
		return false;
	}

	for y : 0..cursor.y-1 {
		view := get_row_view(editor, y);
		has_zero_before := false;
		for view {
			has_zero_before |= !it;
			if it && has_zero_before {
				log("[INVALID_LINE] %: %\n", y, it_index);
				return false;
			}
		}
	}

	return true;
}

clear_selected_lines :: (using editor : *Block_Editor) {
	assert(select_zone_y != -1);
	mi := min(select_zone_y, cursor.y);
	ma := max(select_zone_y, cursor.y);
	// log("mi / ma: % / %\n", mi, ma);
	
	bl := get_row_view(editor, mi);
	memcpy(
		buffer.data + size.x * mi,
		buffer.data + size.x * (ma + 1),
		size.x * (size.y - ma - 1)
	);
	memset(
		buffer.data + size.x * (size.y - (ma - mi + 1)),
		#char"\0",
		size.x * (ma - mi + 1)
	);
	cursor = .{.{0, mi}, 0};
	select_zone_y = -1;
}

add_char :: (using editor : *Block_Editor, character : u8) -> ok:bool {
	row_view, zero_pos := get_row_view(editor, cursor.y);
	if zero_pos == size.x return false;
	tail_size := zero_pos - cursor.x;

	memcpy(
		row_view.data + cursor.x + 1,
		row_view.data + cursor.x,
		tail_size
	);
	row_view[cursor.x] = character;
	cursor.x += 1;
	cursor.saved_x = cursor.x;
	return true;
}
clear_line :: (using editor : *Block_Editor, row : int) {
	memset(buffer.data + size.x * row, #char"\0", size.x);
}

delete_char :: (using editor : *Block_Editor) -> ok:bool, char:u8 {
	row_view, l := get_row_view(editor, cursor.y);
	if cursor.x < l {
		c := row_view[cursor.x];
		memcpy(row_view.data + cursor.x, row_view.data + cursor.x + 1, size.x - cursor.x - 1);
		row_view[size.x - 1] = #char"\0";
		return true, c;
	} else if cursor.y < size.y - 1 {
		assert(cursor.x == l);
		next_row_view, ln := get_row_view(editor, cursor.y + 1);
		if l + ln > size.x return false, 0;
		memcpy(
			row_view.data + l,
			next_row_view.data,
			ln
		);
		memcpy(
			next_row_view.data,
			next_row_view.data + size.x,
			size.x * (size.y - cursor.y - 2)
		);
		clear_line(editor, size.y - 1);
		return true, #char"\n";
	} else {
		return false, 0;
	}
}

erase_char :: (using editor : *Block_Editor) -> ok:bool, erased:u8 {
	row_view, l := get_row_view(editor, cursor.y);
	if cursor.x {
		memcpy(row_view.data + cursor.x - 1, row_view.data + cursor.x, size.x - cursor.x);
		c := row_view[cursor.x - 1];
		row_view[size.x - 1] = #char"\0";
		cursor.x -= 1;
		cursor.saved_x = cursor.x;
		return true, c;
	} else if cursor.y {
		prev_row_view, lp := get_row_view(editor, cursor.y - 1);
		if lp + l > size.x return false, 0;
		memcpy(
			prev_row_view.data + lp,
			row_view.data,
			l
		);
		memcpy(
			row_view.data,
			row_view.data + size.x,
			size.x * (size.y - cursor.y - 1)
		);
		clear_line(editor, size.y - 1);
		cursor.y -= 1;
		cursor.x = xx (lp);
		cursor.saved_x = cursor.x;
		return true, #char"\n";
	} else {
		return false, 0;
	}
}
ctrl_erase_char :: (using editor : *Block_Editor) -> bool {
	at_least_once := false;
	cat := Char_Category.SPACE;

	while 1 {
		ok, left_char_pos := one_left(editor);
		if !ok break;

		char := at(editor, left_char_pos);
		newcharcat := catof(char);
		if cat != .SPACE && newcharcat != cat {
			break;
		}
		erase_char(editor);
		at_least_once = true;

		cat = newcharcat;
	}

	return at_least_once;
}

process_key_editor :: (using editor : *Block_Editor, key : Key) -> processed:bool, changed:bool {
	processed := false;
	changed := false;
	if key >= #char " " && key <= #char "~" {
		processed = add_char(editor, xx key);
		changed = processed;
	} else if key == {
	case 13;
		if select_zone_y != -1 {
			clear_selected_lines(editor);
		}
		processed = newline(editor);
		changed = processed;
	case .BACKSPACE;
		if select_zone_y != -1 {
			clear_selected_lines(editor);
			processed, changed = true;
		} else {
			processed = erase_char(editor);
			changed = processed;
		}
	case .CTRL_BACKSPACE;
		if select_zone_y != -1 {
			clear_selected_lines(editor);
			processed, changed = true;
		} else {
			processed = ctrl_erase_char(editor);
			changed = processed;
		}
	case .DELETE;
		if select_zone_y != -1 {
			clear_selected_lines(editor);
			processed, changed = true;
		} else {
			processed = delete_char(editor);
			changed = processed;
		}
	case .RIGHT;
		processed = move(editor, .RIGHT);
		select_zone_y = -1;
	case .LEFT;
		processed = move(editor, .LEFT);
		select_zone_y = -1;
	case .CTRL_UP; #through;
	case .UP;
		processed = move(editor, .UP);
		select_zone_y = -1;
	case .CTRL_DOWN; #through;
	case .DOWN;
		processed = move(editor, .DOWN);
		select_zone_y = -1;
	case .CTRL_LEFT;
		processed = ctrl_move(editor, .LEFT);
		select_zone_y = -1;
	case .CTRL_RIGHT;
		processed = ctrl_move(editor, .RIGHT);
		select_zone_y = -1;

	case .SHIFT_UP;
		if select_zone_y == -1 then select_zone_y = cursor.y;
		move(editor, .UP);
	case .SHIFT_DOWN;
		if select_zone_y == -1 then select_zone_y = cursor.y;
		move(editor, .DOWN);
	case .SHIFT_RIGHT;
		if select_zone_y == -1 then select_zone_y = cursor.y;
		move(editor, .RIGHT);
	case .SHIFT_LEFT;
		if select_zone_y == -1 then select_zone_y = cursor.y;
		move(editor, .LEFT);
	case .CTRL_C;
		if select_zone_y == -1 {
			copy_lines(editor, cursor.y, cursor.y);
		} else {
			copy_lines(editor, min(select_zone_y, cursor.y), max(select_zone_y, cursor.y));
		}
		processed = true;
	case .CTRL_V;
		try_paste_lines(editor);
		processed, changed = true;
		processed = true;
	case .CTRL_A;
		select_all(editor);
		processed = true;
	case .CTRL_X;
		if select_zone_y == -1 {
			select_zone_y = cursor.y;
		}
		copy_lines(editor, min(select_zone_y, cursor.y), max(select_zone_y, cursor.y));
		clear_selected_lines(editor);
		processed, changed = true;
	case .CTRL_SHIFT_UP;
		if select_zone_y == -1 {
			select_zone_y = cursor.y;
		}
		mi, ma := min(select_zone_y, cursor.y), max(select_zone_y, cursor.y);
		if mi > 0 {
			swp := alloc(size.x,, temp);
			memcpy(
				swp, 
				buffer.data + (mi - 1) * size.x,
				size.x
			);
			memcpy(
				buffer.data + (mi - 1) * size.x,
				buffer.data + mi * size.x,
				size.x * (ma - mi + 1)
			);
			memcpy(
				buffer.data + ma * size.x,
				swp, 
				size.x
			);
			cursor.y -= 1;
			select_zone_y -= 1;
			processed, changed = true;
		}
	case .CTRL_SHIFT_DOWN;
		if select_zone_y == -1 {
			select_zone_y = cursor.y;
		}
		mi, ma := min(select_zone_y, cursor.y), max(select_zone_y, cursor.y);
		if ma < size.y - 1 {
			swp := alloc(size.x,, temp);
			memcpy(
				swp, 
				buffer.data + (ma + 1) * size.x,
				size.x
			);
			memcpy(
				buffer.data + (mi + 1) * size.x,
				buffer.data + mi * size.x,
				size.x * (ma - mi + 1)
			);
			memcpy(
				buffer.data + mi * size.x,
				swp, 
				size.x
			);
			cursor.y += 1;
			select_zone_y += 1;
			processed, changed = true;
		}		
	}
	if processed reset_tick_state();
	return processed, changed;
}

select_all :: (using editor : *Block_Editor) {
	cursor.pos = .{0, 0};
	select_zone_y = size.y - 1;
}

copy_lines :: (editor : Block_Editor, mi : int, ma : int) {
	max_length := 0;
	lines : [..]string;
	for mi..ma {
		_line, l := get_row_view(editor, it);
		array_add(*lines, copy_string(.{l, _line.data}));
		max_length = max(max_length, l);
	}
	// log("% %\n", lines, max_length);
	safe_replace(*copy_buffer.lines, lines);
	copy_buffer.max_length = max_length;
}
free_lines :: (using editor : Block_Editor) -> int {
	for < y : size.y-1..0 {
		for x : 0..size.x-1 {
			c := at(editor, x, y);
			if !c break;
			if c != #char" " return size.y - 1 - y;
		}
	}
	return size.y;
}
try_paste_lines :: (using editor : *Block_Editor) {
	if copy_buffer.max_length > size.x return;
	if free_lines(editor) < copy_buffer.lines.count return;

	memcpy(
		buffer.data + size.x * (cursor.y + copy_buffer.lines.count),
		buffer.data + size.x * cursor.y,
		size.x * (size.y - cursor.y - copy_buffer.lines.count)
	);
	memset(
		buffer.data + size.x * cursor.y,
		#char"\0",
		size.x * copy_buffer.lines.count		
	);
	for l, y : copy_buffer.lines {
		assert(l.count <= size.x);
		memcpy(
			buffer.data + size.x * (cursor.y + y),
			l.data,
			l.count
		);
	}

	for 1..copy_buffer.lines.count {
		move(editor, .DOWN);
	}
}

deinit_copy_buffer :: () {
	for copy_buffer.lines free(it);
	array_free(copy_buffer.lines);
}
#scope_file
editor_tick_state := 0;

copy_buffer : struct {
	max_length : int;
	lines : []string;
}