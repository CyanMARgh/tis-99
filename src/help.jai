get_help :: (using breadboard : Breadboard) -> int {
    if #complete state == {
        case .DEFAULT; return 2;
        case .SHOW_TASK; return 3;
        case .CIRCUITS_EDIT; return 4;
        case .ADD_WIRE; return 5;
        case .ASSEMBLY_EDIT; return 6;
    }
    return -1;
}
get_help :: (using game : Game) -> int {
    if #complete state == {
        case .MAIN_MENU; return 1;
        // case .CREATE_SOLUTION; return 1;
        case .EDIT_SOLUTION; return get_help(edit_solution.breadboard);
    }
    return -1;
}

process_help :: (str : string) -> []string {
    result := split(str, "\n",, temp);
    while result && !result[0] {
        result.count -= 1;
        result.data += 1;
    }
    while result && !result[result.count-1] {
        result.count -= 1;
    }
    for * result {
        it.* = copy_string(it.*);
        assert(it.count <= 80, "count = %; line = %", it.count, it.*);
    }
    return array_copy(result);
}
MANUAL :: []string.[
    TABLE_OF_CONTENTS,
    HELP_START_MENU,
    HELP_DEFAULT,
    HELP_SHOW_TASK,
    HELP_CIRCUITS_EDIT,
    HELP_ADD_WIRE,
    HELP_ASSEMBLY_EDIT,
    HELP_ASCII_TABLE
];
#scope_file

TABLE_OF_CONTENTS :: #run process_help(#string STR
TIS-99 manual

1 - table of contents
2 - start menu; basic information
3 - default mode
4 - "show task" mode
5 - circuits editing mode; circuits models
6 - wire editing mode
7 - assembly edit mode; communication protocol
8 - ascii table
STR);

HELP_START_MENU :: #run process_help(#string STR
You can open/close the help menu in any mode by pressing the "?" or F1.
It will contain mode-specific information for every screen.
Use UP/DOWN to scroll and LEFT/RIGHT to switch pages.

To close this popup / return back in general, you should use Q button
or ESC in case if you use text editor and Q means "append Q character".

Use the ARROWS to move the cursor, navigate through code, circuits translation.
and other kind of movement. (Sorry, vim fans)
ENTER is used to confirm actions.
During breadboard editing you can use CTRL+arrow for faster navigation.

You can see mode-specific hotkeys in left-bottom corner of screen or
inside manual.

To open an existing solution, move the cursor to the task you whant,
press ENTER, select solution and press ENTER again.

To create new solution select level, press ENTER with [+] under the cursor,
or just N, then enter solution name and press ENTER again. 

press R or BACKSPACE to remove solution files.
ATTENTION: for now, there are no "are you sure?" popups, so be careful!
STR);

HELP_DEFAULT :: #run process_help(#string STR
C - Add circuit.
R - Remove circuit.
M - Move circuit. You must first aim at the required circuit.
    Moving the circuit preserves its state
W - Wire editing mode.
A - Switch to code editing/simulation mode. (TAB to switch between submodes)
T - Open task description.

You can use same key to return back to default mode.
STR);

HELP_SHOW_TASK :: #run process_help(#string STR
Use UP and DOWN to scroll. I have nothing more to say :) 
STR);

HELP_CIRCUITS_EDIT :: #run process_help(#string STR
ESC     - Exit to default.
1-9     - Switch circuit model.
ARROWS  - Navigation.
R/ENTER - remove (in FREE mode)
N/C     - select new circuit
M       - Move
ENTER   - place (in PLACE/MOVE mode)
CTRL+C  - copy circuit under cursor

Pins on circuits are marked with "&". There are two types of pins - 
input and output. They are not visually different, the only way to tell
them apart is to know where each is for each individual board.
More than one pin of each type can be connected to one wire.
Pins can only connect to red and green wires.
List of circuit models:

(*) TIS-3:
Inputs: top left pin (#0).
Outputs: right, bottom, left, top (#0-#3 respectively)

This circuit has a built-in assembly editor (more about it in 
assembly edit mode->help). It's processor has 5 registers: a, b, c, d, e.
Each of them can be used for mathematical operations and data movement,
but some of them have additional functionality:
A is used for conditional jumps.
C, D and E are used for communication 
(more details in assembly edit mode->help)

(*) io441:
Outputs: 4 top pins (from #0 to #3 from top to bottom).
Inputs: 4 bottom pins (#0 to #3 from top to bottom).
This board sends test data and expects calculation results as input
The data and the expected result are visible in assembly edit mode. 
If the input data does not match the expected ones, the circuit will 
go into the ERROR state. As soon as all tests are passed, it will go 
into the HALT state.

(*) S.M. 255:
This circuit is a stack with a limit of 255 elements.
It has 1 input pin on the top and 4 output pins on the bottom with indexes
from 0 to 3, left to right. It constantly tries to push the value from the top
of the stack (if the stack is not empty). First of all, it tries to send a
number through the 0th output pin. If the sending is not possible, then it
tries the 1st pin and so on. Also note that this board does not block writes
even if the stack is full, which causes it to go into an invalid state instead
of waiting when trying to write the 256th value.

(*) io102 & io013:
These circuits are used as a replacement for io441 in some tasks.
io102 - for input data; io013 - for output data. They have single output and
one input pin, respectively. Therefore, if a task uses several channels,
then several circuits are installed. Otherwise they act like io441.

(*) twics & twocs:
These circuits work the same as io102 & io013. The only difference is that
they serve to represent text information and send/accept, respectively,
instead of numbers, character codes in ASCII. (see table on the last page)

(*) Q5:
This small circuit serves as a queue buffer for signals. 
It has 3 pins, 1 left is input, 2 right are output (with indices #0 and #1
from top to bottom, respectively). It can contain no more than 5 values.
If another board tries to send a value to Q5 while it is full, Q5 will
block the transfer instead of going into an invalid state like the S.M.255.
If both output pins occupied by some circuit, then Q5 will alternate the
output between outputs every tick. Also, you can change the initial state
of Q5, but unfortunately you cannot write more than one number.

(*) JBM S30
This circuit is a screen for outputting 3-bit color. The 1st least
significant bit is responsible for the red channel, the 2nd for the green
and the 3rd for the blue. So, for example, 6 (110 in binary) is cyan.
All pins of S30 are input and they are grouped into groups of 3. In each
group, the left pin is responsible for the X coordinate, the middle one for
the Y coordinate, and the right one for the pixel color. To recolor a pixel
at coordinate (X, Y) in color C, you just need to send the corresponding
values to the three pins. Delays in dispatch time are not important,
because for each input channel, circuit has a built-in buffer. Its size is not
specified by the manufacturer, but you can find out its size experimentally,
because the buffer will not allow sending a signal when the limit is reached.
Also, note that all triplets are independent. This means that if you send x
and y to the 0th and 1st pins, and C to the 5th, the pixel will not be redrawn.
This division was created to allow parallel recording from several drawing
processors. If (X, Y) is outside the screen boundaries, then the pixel will
not be updated. if C is not in the range [0; 7], then all bits starting from
the 4th will be cut off, so, for example, 109 (1101101 in binary) will be
displayed as magenta.

(*) JBM S3030
This circuit is completely identical to the S30 in terms of interaction, with
the exception of further described differences. Instead of one screen, it
contains two: the screen with the target image on the left and the screen
where you draw on the right. At the moment when, as you think, the images on
both sides coincide, you need to send any signal to the left pin. After this,
the circuit will switch to the new target image, if there is one. If there are
no more, it will halt, displaying the word "DONE" on the left screen.
STR);

HELP_ADD_WIRE :: #run process_help(#string STR
The red and green wires do not transmit a signal to each other.
Yellow wires can be used to connect the red and green ones.
Also, note that the signal inside the yellow wires only travels
in a straight line, so they can be used to create "bridges".

ESC     - Exit to default.
ENTER   - Temporarily disable/enable editing.
          The cursor will appear as a small "w" if editing is 
          temporarily disabled.
ARROWS  - Move, then place wire, if in active editing mode.
R, G, Y - Select red/green/yellow wire "brush".
E       - Enable wire eraser.
STR);

// HELP_REMOVE_CIRCUIT :: #run process_help(#string STR
// ESC    - Exit to default.
// ENTER  - Delete circuit under cursor.
// ARROWS - Navigation.
// STR);

HELP_ASSEMBLY_EDIT :: #run process_help(#string _HELP_ASSEMBLY_EDIT
ARROWS - navigation in code
TAB    - switch editing/simulation mode
SHIFT+COMMA/DOT
ALT+RIGHT/LEFT - switch focus

only during simulation:
+/=    - speed up simulation
-      - slow down simulation
SPACE  - pause/unpause simulation
S      - do 1 step of simulation 
R      - restart simulation

TIS-3's ASSEMBLY:
All lines of code must satisfy the following pattern:
    
    label_name: operation destination source

The line may not contain "label_name:", the right side
or may be completely empty.

Also, you can use ; for comments, like that:

    mov b a; moving content of a to register b

Assembler is not case sensitive, 
that is, "mov", "MOV" and "MoV" are the same thing.

LIST OF INSTRUTIONS
    R - register, V - integer value (can be written as 123 for decimal or
    as #7b for hex), L - label name.
    Some of instruction can use both registers and raw values,
    it's indicated by R/V
COMMON

    nop         ; do nothing for 1 tick
    mov R1 R2/V ; R <- R2/V 
    add R R/V   ; R <- R + R2/V
    sub R R/V   ; R <- R - R2/V
    jmp L       ; proceed to execution starting with the
                ;instructions right after
                ; the L label.
    inc R       ; R <- R + 1
    dec R       ; R <- R - 1

conditional jumps:

    jz  L; if a == 0 then jmp L 
    jnz L; if a != 0 then jmp L 
    jlz L; if a <  0 then jmp L 
    jgz L; if a >  0 then jmp L 

PROGRAM TERMINATION:

    halt ; halt
    error; stop program with error

COMMUNICATION (see communication protocol for more details):

    send V1 R/V2; send R/V2 to through pin V1
    recv        ; wait until d will be set to non-zero from outside

COMMUNICATION PROTOCOL:

All circuits use the following sending mechanism:
Let's say the output pin of circuit C_0 is connected to the input pins of
circuits C_1, C_2, ... C_n numbered S_1, S_2, ... S_n, respectively.

Sending a message from C_0 to C_1..C_n occurs only if each of the
receivers is ready to receive it. If this condition is met, then the message is
duplicated for all receiving circuits. If another output pin is connected to
the output pin, it is ignored when sending.

However, let's look at an example: let there be three circuits C_1, C_2 and
C_3, where the first 2 are senders whose output pins are connected to the input 
pin C_3. How can C_3 distinguish who the input signal is coming from?
Especially for this, during assembly, each of the schemes is assigned a unique
number, which is written in the upper left corner, let's call this number
SENDER_CIRCUIT_ID. Also, every pin has unique id (SENDER_PIN_ID). Thus, you can
determine the source address of the message as:

    SENDER_ID = SENDER_CIRCUIT_ID | (SENDER_PIN_ID << 8)

which is implicitly sent along with the sent value. Test circuits ignore it, but
calculation circuits do not. TIS-3 Uses 3 registers for communication:
c("occupant"), d("lock") and e("input"). TIS-3 is ready to accept a message
only if

    (d == 0) && (c == -1 || c == SENDER_ID)

If the condition is met, then the sender atomically writes:

    e = sent_value;
    d = 1;
    c = SENDER_ID;

Thus, to receive a message on the TIS-3 diagram, you need to write:

    mov with SENDER_ID
    mov d 0
    recv

Also, let me remind you that assembly supports hex notation of numbers, which
can conveniently be used to write SENDER_ID.
The only thing recv does is wait for register d to be assigned a non-zero value
from outside. In order to send a value from TIS-3, you need to write:

    send V1 R/V2

where V1 is the pin number from which the sending occurs, R/V2 is the register
from which the value is sent/the value itself
_HELP_ASSEMBLY_EDIT);

HELP_ASCII_TABLE :: #run process_help(#string STR
 all characters without description are unused

  0 NULL      32 SPACE     64 @         96 `
  1           33 !         65 A         97 a
  2           34 "         66 B         98 b
  3           35 #         67 C         99 c
  4           36 $         68 D        100 d
  5           37 %         69 E        101 e
  6           38 &         70 F        102 f
  7           39 '         71 G        103 g
  8           40 (         72 H        104 h
  9           41 )         73 I        105 i
 10 LINE END  42 *         74 J        106 j
 11           43 +         75 K        107 k
 12           44 ,         76 L        108 l
 13           45 -         77 M        109 m
 14           46 .         78 N        110 n
 15           47 /         79 O        111 o
 16           48 0         80 P        112 p
 17           49 1         81 Q        113 q
 18           50 2         82 R        114 r
 19           51 3         83 S        115 s
 20           52 4         84 T        116 t
 21           53 5         85 U        117 u
 22           54 6         86 V        118 v
 23           55 7         87 W        119 w
 24           56 8         88 X        120 x
 25           57 9         89 Y        121 y
 26           58 :         90 Z        122 z
 27           59 ;         91 [        123 {
 28           60 <         92 \        124 |
 29           61 =         93 ]        125 }
 30           62 >         94 ^        126 ~
 31           63 ?         95 _        127  
STR);









