Wire :: enum_flags u8 {
	NONE  :: 0x0;
	GREEN :: 0x1;
	RED   :: 0x2;
	YELLOW:: 0x3;
	ANY   :: 0x3;
	VISITED :: 0x4;
}
Wiremap :: struct {
	size : ivec2;
	wires : []Wire;
	cost := 0;
}
init :: (wiremap : *Wiremap, size : ivec2) {
	assert(size.x >= 0 && size.y >= 0);
	wiremap.size = size;
	wiremap.wires = NewArray(size.x * size.y, Wire);
}
deinit :: (wiremap : *Wiremap) {
	array_free(wiremap.wires);
}

connection_style :: #run u32.[
	utf8("+"), utf8("+"),
	utf8("+"), utf8("╚"),
	utf8("+"), utf8("║"),
	utf8("╔"), utf8("╠"),
	utf8("+"), utf8("╝"),
	utf8("═"), utf8("╩"),
	utf8("╗"), utf8("╣"),
	utf8("╦"), utf8("╬")
];

at :: (using wiremap : Wiremap, pos : ivec2) -> Wire {
	return ifx point_inside_zone(pos, size) then wires[size.x * pos.y + pos.x] else .NONE;
}
fix_cost :: (using wiremap : *Wiremap) {
	cost = 0;
	for wires if it cost += 1;
}
// set :: (using wiremap : *Wiremap, pos : ivec2, wire : Wire) {
// 	assert(point_inside_zone(pos, size), "pos / size = % / %", pos, size);
// 	wires[size.x * pos.y + pos.x] = wire;
// }
at_ptr :: (using wiremap : *Wiremap, pos : ivec2) -> *Wire {
	assert(point_inside_zone(pos, size));
	return *wires[size.x * pos.y + pos.x];
}

get_wire_color :: inline (w : Wire) -> Graphics_Mode {
	lookup :: Graphics_Mode.[MODE_DEFAULT, MODE_WIRE_GREEN, MODE_WIRE_RED, MODE_WIRE_YELLOW];
	return lookup[w & .ANY];
	// lookup :: Color.[.BRIGHT_WHITE, .BRIGHT_GREEN, .BRIGHT_RED, .BRIGHT_YELLOW];
	// return .{foreground = lookup[w & .ANY], background = xx (Color.BLACK + 10)};
}
get_wire_char :: (using wiremap : Wiremap, pos : ivec2) -> Char {
	w := at(wiremap, pos);
	wa := w & .ANY;
	if !w return #run make_char(0);
	w1 := at(wiremap, pos + .{0, -1});
	w2 := at(wiremap, pos + .{1, 0});
	w4 := at(wiremap, pos + .{0, 1});
	w8 := at(wiremap, pos + .{-1, 0});

	id : u8;
	if wa & w1 then id |= 0x1;
	if wa & w2 then id |= 0x2;
	if wa & w4 then id |= 0x4;
	if wa & w8 then id |= 0x8;

	return .{code = connection_style[id], mode = get_wire_color(w)};
}
draw :: (using canvas : *Canvas, wiremap : Wiremap, $partial := false, zone := Ibox2.{}) {
	#if partial {
		assert(!screen);
		p0 := zone.corner;
		p1 := zone.corner + zone.size;

		p0 = .{max(p0.x, 0), max(p0.y, 0)};
		p1 = .{min(p1.x, size.x), min(p1.y, size.y)};
	} else {
		p0, p1 : ivec2 = .{0, 0}, size;
	}

	for y : p0.y..p1.y-1 {
		for x : p0.x..p1.x-1 {
			pos := ivec2.{xx x, xx y};
			filler := get_wire_char(wiremap, pos);
			c_putchar(canvas, filler, pos);
		}
	}
}

//                                                  list of sets of pins ids 
find_pin_groups :: (wiremap : *Wiremap, pins : []ivec2) -> [][]int {
	Pincoord_To_Id :: Table(ivec2, int, (x)=>sdbm_hash(xx *x, size_of(ivec2), 5381), (x, y)=>x==y);	
	pincoord_to_id : Pincoord_To_Id;
	pincoord_to_id.allocator = temp;

	Visit_Info :: struct { pos, dir : ivec2; prev : Wire; }

	find_pin_group :: (pincoord_to_id : *Pincoord_To_Id, wiremap : *Wiremap, pins : []ivec2, start : ivec2) -> []int {
		pin_set : [..]int; pin_set.allocator = temp;

		try_add_pin :: (pincoord_to_id : *Pincoord_To_Id, pin_set : *[..]int, pos : ivec2) {
			// log("wire at: %\n", pos);
			id, ok := table_find(pincoord_to_id, pos);
			if !ok return;
			assert(!array_find(pin_set.*, id));
			array_add(pin_set, id);
		}

		to_visit : Queue(Visit_Info); defer deinit(*to_visit);

		{
			cell := at_ptr(wiremap, start);
			C := cell.*;
			if C & .ANY == .NONE || C & .ANY == .YELLOW || C & .VISITED then return .[];
			push(*to_visit, .{start, .{0, 0}, .ANY});
		}

		directions :: ivec2.[.{1, 0}, .{0, 1}, .{-1, 0}, .{0, -1}];

		while 1 {
			visit_info, ok := pop(*to_visit);
			if !ok break;

			if !point_inside_zone(visit_info.pos, wiremap.size) continue;
			cell := at_ptr(wiremap, visit_info.pos);
			current_wire := cell.*;
			if current_wire & .VISITED continue;
			current_wire &= .ANY;
			if !(current_wire & visit_info.prev) continue;

			if current_wire == {
			case .NONE;
				continue;
			case .RED; #through;
			case .GREEN;
				try_add_pin(pincoord_to_id, *pin_set, visit_info.pos);
				cell.* |= .VISITED;
				for directions {
					if it != -visit_info.dir {
						push(*to_visit, .{visit_info.pos + it, it, current_wire});
					}
				}
			case .YELLOW;
				push(*to_visit, .{visit_info.pos + visit_info.dir, visit_info.dir, current_wire});
			}
		}
		return pin_set;
	}

	for pins {
		table_set(*pincoord_to_id, it, it_index);
	}

	result : [..][]int;
	result.allocator = temp;
	for y : 0..wiremap.size.y-1 {
		for x : 0..wiremap.size.x-1 {
			set := find_pin_group(*pincoord_to_id, wiremap, pins, .{xx x, xx y});
			if set {
				array_add(*result, set);
				// log("set = %\n", set);
			}
		}
	}
	for * wiremap.wires it.* &= .ANY;

	return result;
}