ctrl :: (char : string) -> Key {
	return xx(utf8(char) - #char"a" + 1);
}

CTRL_Q :: #run ctrl("q");
CTRL_S :: #run ctrl("s");

F1 :: 5263131;
F2 :: 5328667;
F3 :: 5394203;
F4 :: 5459739;

memcpy_array :: (target : *[]$T, source : []T) -> bool {
	if target.count != source.count return false;
	memcpy(target.data, source.data, source.count * size_of(T));
	return true;
}

safe_move :: (target : *$T, source : *T) {
	safe_move(target, source.*);
	default : T;
	source.* = default;
}
safe_replace :: (target : *$T, source : T)
#modify {
	ti := cast(*Type_Info)T;
	return ti.type != .STRING && ti.type != .ARRAY;
}
{
	deinit(target);
	target.* = source;
}
safe_replace :: (target : *string, source : string) {
	free(target.*);
	target.* = source;
}

safe_replace :: (target : *[]$T, source : []T) #modify { return T != string; } {
	array_free(target.*);
	target.* = source;
}
safe_replace :: (target : *[]string, source : []string) {
	for target.* free(it);
	array_free(target.*);
	target.* = source;
}

make_char :: inline (code : u32, foreground := Color.BRIGHT_WHITE, background := Color.BLACK, bold := false, dim := false, italic := false, underline := false, blinking := false, inverse := false, strikethrough := false, fcol256 :u8= 0, bcol256 :u8= 0) -> Char {
	return KS_Curses.make_char(code, foreground, background, bold, dim, italic, underline, blinking, inverse, strikethrough, fcol256, bcol256);
}

make_graphics_mode :: inline (foreground := Color.BRIGHT_WHITE, background := Color.BLACK, bold := false, dim := false, italic := false, underline := false, blinking := false, inverse := false, strikethrough := false, fcol256 :u8= 0, bcol256 :u8= 0) -> Graphics_Mode {
	return KS_Curses.make_graphics_mode(foreground, background, bold, dim, italic, underline, blinking, inverse, strikethrough, fcol256, bcol256);
}

map :: (array: [] $T, f: (T) -> $R) -> [] R {
	result: [..] R;
	result.allocator = temp;
	for array array_add(*result, f(it));
	return result;
}
filter :: (array : []$T, cond : (T) -> bool) -> []T {
	result : [..]T;
	for array if cond(it) array_add(*result, it);
	return result;
}

pad :: (length : int, str : string, pad_char : u8 = #char" ") -> string {
	assert(length >= str.count, "line = %", str);
	data := alloc(length,, allocator = temp);
	memcpy(data + length - str.count, str.data, str.count);
	memset(data, pad_char, length - str.count);

	result : string = ---;
	result.count = length;
	result.data = data;
	return result;
}
pad :: (str : string, length : int, pad_char : u8 = #char" ") -> string {
	assert(length >= str.count);
	data := alloc(length,, allocator = temp);
	memcpy(data, str.data, str.count);
	memset(data + str.count, pad_char, length - str.count);

	result : string = ---;
	result.count = length;
	result.data = data;
	return result;
}

c_draw_canvas_view :: (target : *Canvas, source : Canvas, offset : ivec2, view : Ibox2) {
	for dx : 0..view.width-1 {
		for dy : 0..view.height-1 {
			dxy := ivec2.{xx dx, xx dy};
			src_pos := view.corner + dxy;
			dst_pos := offset + dxy;
			// log("% <- %\n", dst_pos, src_pos);
			// at(source, src_pos);
			c_putchar(target, at(source, src_pos), dst_pos);
		}
	}
}
draw_rect :: (canvas : *Canvas, zone : Ibox2, filler : Char) {
	for y : 0..zone.height-1 {
		for x : 0..zone.width-1 {
			c_putchar(canvas, filler, zone.corner + .{xx x, xx y});
		}
	}
}
NewFill :: (obj : $T) -> *T {
	ptr := New(T, initialized = false);
	ptr.* = obj;
	return ptr;
}

join_arrays :: (arrs : ..[]$T) -> []T {
	result : [..]T;
	for arr : arrs {
		for arr {
			array_add(*result, it);
		}
	}
	return result;
}

files_from_directory :: (root : string, ext := "") -> []string {
	files : [..]string; files.allocator = temp;
	visit_files(
		root,
		false,
		*files,
		(info : *File_Visit_Info, files_list : *[..]string) {
			array_add(files_list, copy_string(info.short_name));
		},
		true,
		false,
		false
	);
	if ext {
		suff := tprint(".%", ext);
		for * files {
			if !ends_with(it.*, ext) {
				remove it;
			} else {
				it.count -= suff.count;
			}
		}
	}

	return files;
}
dirs_from_directory :: (root : string) -> []string {
	dirs : [..]string;
	visit_files(
		root,
		false,
		*dirs,
		(info : *File_Visit_Info, dirs_list : *[..]string) {
			array_add(dirs_list, copy_string(info.short_name));
		},
		false,
		true,
		false
	);
	return dirs;
}
shuffle_in_place :: (src : []$T) {
	for 1..src.count*2 {
		i := random_get() % cast(u64)src.count;
		j := random_get() % cast(u64)src.count;
		src[i], src[j] = src[j], src[i];
	}
}

random_permutation :: (size : int, allocator := context.allocator) -> []int {
	result := NewArray(size, int,, allocator);
	for * result it.* = it_index;
	shuffle_in_place(result);
	return result;
}

parse_command :: (line : string) -> []string {
	tokens : [..]string;
	tokens.allocator = temp;
	while 1 {
		l, ok := parse_token(*line, ":;=()", spaces = " \t\r\n\0");
		if !ok || l == ";" break;
		array_add(*tokens, to_lower_copy_new(l,, temp));
	}
	return tokens;
}
limit_by_width :: (str : string, w : int) -> string {
	result : [..]u8;
	x := 0;
	for cast([]u8)str {
		if it == #char"\n" {
			x = 0;
		}
		array_add(*result, it);
		x += 1;
		if x == w {
			array_add(*result, #char"\n");
			x = 0;
		}
	}
	return xx result;
}

char_as_string :: (c : u32) -> string #expand {
	return .{count = 4, data = xx * c};
}

string_to_s16 :: (str : string) -> s16, bool {
	assert(str.count > 0);
	val : int;
	ok : bool;
	rem : string;
	if str[0] == #char"#" {
		rem1 := string.{str.count - 1, str.data + 1};
		if rem1.count < 0 || rem1.count > 4 return 0, false;
		if rem1[0] == #char"-" return 0, false;
		val, ok, rem = string_to_int(rem1, base = 16);				
	} else {
		val, ok, rem = string_to_int(str);				
	}
	if !ok || rem return 0, false;
	mask :: 0xFFFF_FFFF_FFFF_0000;
	masked := val & mask;
	if masked != mask && masked != 0 {
		return 0, false;
	}
	return cast,trunc(s16) val, true;
}

s16_to_str6 :: (x : s16) -> string {
	return pad(6, tprint("%", x));
}

make_safe_for_print :: (str : string) {
	for * cast([]s8)str {
		it.* = min(max(it.*, xx #char" "), #char"~");
	}
}

to_string :: inline (arr : SBDA($u8, $N)) -> string #expand {
	return .{data = arr.buf.data, count = arr.count};
}

Const_Arr :: struct(arr : [$N]$T) {
}
const_arr :: ($arr : [$N]$T) -> Const_Arr(arr) {
	return .{};
}

for_expansion :: (ca : Const_Arr($arr), $body : Code, flags : For_Flags) #expand {
	`it, `it_index :: 0;
	TEMPLATE :: #string STR
		{
			it_index :: %;
			it :: ca.arr[it_index];
			#insert,scope() body;
		}
	STR;
	#insert -> string {
		result : String_Builder;
		for 0..arr.count-1 {
			print_to_builder(*result, TEMPLATE, it);
		}
		return builder_to_string(*result);
	};
}

and :: (arr : []bool) -> bool {
	for arr if !it return false;
	return true;
}
