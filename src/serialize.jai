save_to_file :: (filepath : string, obj : $T) {
	buf : [..]u8; buf.allocator = temp;
	add_to_sbuf(*buf, FORMAT_VERSION);
	add_to_sbuf(*buf, obj);
	write_entire_file(filepath, cast(string)deflate_sequences(buf,, temp));
}
load_from_file :: (obj : *$T, filepath : string) -> ok:bool {
	buf_raw, ok := read_entire_file(filepath,, temp);
	if !ok return false;
	buf, ok2 := inflate_sequences(xx buf_raw,, temp);
	if !ok2 return false;
	format_version : u64;
	if !read_from_sbuf(*format_version, *buf) || format_version != FORMAT_VERSION return false;
	return read_from_sbuf(obj, *buf) && buf.count == 0;
}

copy_circuit :: (src : Circuit, breadboard : Breadboard) -> Circuit {
	info := get_info(src);
	dst : Circuit;
	ok := restore(*dst, info, breadboard);
	assert(ok);
	return dst;
}

#scope_file

Circuit_Info :: struct {
	editor_content : []u8;
	corner : ivec2;
	model_id : int;
	model_subid : int;
}
deinit :: (using ci : *Circuit_Info) {
	array_free(editor_content);
}
get_info :: (using circuit : Circuit) -> Circuit_Info {
	return .{
		editor.buffer,
		corner,
		model_id,
		model_subid
	};
}
restore :: (circuit : *Circuit, circuit_info : Circuit_Info, breadboard : Breadboard) -> bool {
	ok1 : bool;
	circuit.*, ok1 = gen_circuit(breadboard, circuit_info.corner, circuit_info.model_id, circuit_info.model_subid);
	if !ok1 return false;
	ok2 := memcpy_array(*circuit.editor.buffer, circuit_info.editor_content);
	if !ok2 deinit(circuit);
	return ok2;
}

add_to_sbuf :: (buffer : *[..]u8, using obj : Circuit_Info) {
	add_to_sbuf(buffer, editor_content);
	add_to_sbuf(buffer, corner);
	add_to_sbuf(buffer, model_id);
	add_to_sbuf(buffer, model_subid);
}
read_from_sbuf :: (using obj : *Circuit_Info, buffer : *[]u8) -> bool {
	return
		read_from_sbuf(*editor_content, buffer) &&
		read_from_sbuf(*corner, buffer) &&
		read_from_sbuf(*model_id, buffer) && 
		read_from_sbuf(*model_subid, buffer)
	;
}

add_to_sbuf :: (buffer : *[..]u8, using obj : Wiremap) {
	add_to_sbuf(buffer, size);
	add_to_sbuf(buffer, wires);
}
read_from_sbuf :: (using obj : *Wiremap, buffer : *[]u8) -> bool {
	if read_from_sbuf(*size, buffer)
	&& read_from_sbuf(*wires, buffer) {
		fix_cost(obj);
		return true;
	}
	return false;
}

add_to_sbuf :: (buffer : *[..]u8, using obj : Breadboard) {
	add_to_sbuf(buffer, task_name);

	add_to_sbuf(buffer, wiremap);
	add_to_sbuf(buffer, circuits.count);
	for circuits {
		add_to_sbuf(buffer, get_info(it));
	}
}
read_from_sbuf :: (using breadboard : *Breadboard, buffer : *[]u8) -> bool {
	breadboard.* = .{};
	fail :: (fmt : string, args : ..Any) #expand {
		log(fmt, ..args);
		safe_replace(breadboard, .{});
		`return false;
	}
	if !(read_from_sbuf(*task_name, buffer)) {
		fail("FAIL -2\n");
	}
	error : string;
	task, error = load_task(task_file(task_name));
	if error {
		log("failed to load task: %; %\n", task_name, error);
		fail("FAIL -1\n");
	}

	if !read_from_sbuf(*wiremap, buffer) fail("FAIL 0\n");
	circuits_count : int;
	if !read_from_sbuf(*circuits_count, buffer) fail("FAIL 1\n");

	for 1..circuits_count {
		info : Circuit_Info; defer deinit(*info);
		ok := read_from_sbuf(*info, buffer);
		if !ok fail("FAIL 2\n");
		circuit : Circuit;
		if !restore(*circuit, info, breadboard) fail("FAIL 3\n");
		array_add(*circuits, circuit);
	}
	resize(*canvas, size);
	// log("OK\n");
	return true;
}

add_to_sbuf :: (buffer : *[..]u8, using obj : ivec2) {
	add_to_sbuf(buffer, x);
	add_to_sbuf(buffer, y);
}
read_from_sbuf :: (using obj : *ivec2, buffer : *[]u8) -> bool {
	return
		read_from_sbuf(*x, buffer) &&
		read_from_sbuf(*y, buffer);
}

plain_type :: (T : Type) -> bool {
	t := (cast(*Type_Info)T).type;
	return t == .INTEGER || t == .FLOAT || t == .BOOL || t == .VOID || t == .ENUM;	
}
add_to_sbuf :: inline (buffer : *[..]u8, obj : $T) 
#modify {return plain_type(T);} 
{
	array_add(buffer, ...{count = size_of(T), data = xx *obj});
}
read_from_sbuf :: (obj : *$T, buffer : *[]u8) -> ok:bool
#modify {return plain_type(T);} 
{
	S :: size_of(T);
	if buffer.count < S return false;
	memcpy(obj, buffer.data, S);
	buffer.count -= S;
	buffer.data += S;
	return true;
}

add_to_sbuf :: (buffer : *[..]u8, arr : [$N]$T) {
	for arr {
		add_to_sbuf(buffer, it);
	}
}
read_from_sbuf :: (arr : *[$N]$T, buffer : *[]u8) -> bool {
	for * arr.* {
		if !read_from_sbuf(it, buffer) return false;
	}
	return true;
}

add_to_sbuf :: (buffer : *[..]u8, arr : []$T) {
	add_to_sbuf(buffer, arr.count);
	#if #run plain_type(T) {
		for ([]u8).{count = size_of(T) * arr.count, data = xx arr.data} {
			array_add(buffer, it);
		}
	} else {
		for arr {
			add_to_sbuf(buffer, it);
		}		
	}
}
read_from_sbuf :: (arr : *[]$T, buffer : *[]u8) -> bool {
	if !read_from_sbuf(*arr.count, buffer) return false;
	if arr.count < 0 || arr.count >= SUS_LIMIT return false;
	S := arr.count * size_of(T);
	arr.data = alloc(S);
	if !arr.data {
		arr.count = 0;
		return false;
	}
	for * arr.* {
		if !read_from_sbuf(it, buffer) {
			free(arr.data);
			arr.* = .[];
			return false;
		}
	}

	return true;
}

add_to_sbuf :: (buffer : *[..]u8, str : string) {
	add_to_sbuf(buffer, cast([]u8)str);
}
read_from_sbuf :: (str : *string, buffer : *[]u8) -> bool {
	return read_from_sbuf(cast(*[]u8)str, buffer);
}
