deflate_sequences :: (_src : []u8) -> []u8 {
	if !_src return .[];
	src := _src;
	Sequence :: struct {
		length : u16;
		value : u8;
	}
	MAX_SEQUENCE_LENGTH :: 65535;

	sequences : [..]Sequence; sequences.allocator = temp;
	current_sequence := Sequence.{1, src[0]};
	while 1 {
		src.count -= 1; src.data += 1;
		if !src break;
		if src[0] == current_sequence.value && current_sequence.length < MAX_SEQUENCE_LENGTH {
			current_sequence.length += 1;
		} else {
			array_add(*sequences, current_sequence);
			if !src break;
			current_sequence = Sequence.{1, src[0]};			
		}
	}
	array_add(*sequences, current_sequence);

	LENGTH_BIG :: 5;
	chop_view_of_short_sequences :: () -> []Sequence, total_length:u8 #expand {
		result : []Sequence;
		result.data = sequences.data;
		total_length := 0;
		while 1 {
			if result.count == sequences.count break;
			extra_length := sequences[result.count].length;
			if extra_length >= LENGTH_BIG break;
			new_length := total_length + extra_length;
			if new_length >= 256 break;
			total_length = new_length;
			result.count += 1;
		}
		sequences.count -= result.count;
		sequences.data += result.count;

		return result, xx total_length;
	}

	result : [..]u8;

	while sequences {
		sseq, L := chop_view_of_short_sequences();
		if sseq {
			array_add(*result, L);
			for s : sseq {
				for 1..s.length {
					array_add(*result, s.value);
				}
			}
		} else {
			array_add(*result, 0);
			array_add(*result, xx((sequences[0].length) & 0xff));
			array_add(*result, xx((sequences[0].length >> 8) & 0xff));
			array_add(*result, sequences[0].value);
			sequences.count -= 1;
			sequences.data += 1;
		}
	}

	return result;
}

chop_n :: (src : *[]$T, n : int) -> []T, bool {
	if src.count < n return .[], false;
	result : []T;
	result.data = src.data;
	result.count = n;
	src.count -= n;
	src.data += n;
	return result, true;
}
chop_1 :: (src : *[]$T) -> T, bool {
	result : T;
	if src.count < 1 return result, false;
	result = src.*[0];
	src.count -= 1;
	src.data += 1;
	return result, true;
}

inflate_sequences :: (_src : []u8) -> []u8, ok:bool {
	src := _src;
	result : [..]u8;
	verify :: (cond : bool) #expand {
		if !cond {
			array_free(result);
			`return .[], false;			
		}
	}

	while src {
		L, ok := chop_1(*src);
		if L == 0 {
			seq, ok2 := chop_n(*src, 3);
			verify(ok2);
			L := (cast(u16)seq[0]) | ((cast(u16)seq[1]) << 8);
			for 1..L {
				array_add(*result, seq[2]);
			}
		} else {
			seq, ok2 := chop_n(*src, L);
			verify(ok2);
			for seq {
				array_add(*result, it);
			}
		}
	}
	return result, true;
}