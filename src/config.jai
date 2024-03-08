FORMAT_VERSION :u64: 0;
MAX_FILE_NAME_SIZE :: 20;
BUILD_DATE :: #run calendar_to_string(to_calendar(current_time_consensus()));
LOAD_FILES_DELAY :: 1;
SUS_LIMIT :: 1 << 25; // 32 mb

MODE_DEFAULT :: #run make_graphics_mode();
MODE_DEFAULT_INVERTED :: #run make_graphics_mode(foreground = .BLACK, background = .BRIGHT_WHITE);
MODE_ERROR :: #run make_graphics_mode(foreground = .BLACK, background = .BRIGHT_RED);
MODE_ERROR_INVERTED :: #run make_graphics_mode(background = .BLACK, foreground = .BRIGHT_RED);
MODE_OK :: #run make_graphics_mode(foreground = .BLACK, background = .BRIGHT_GREEN);
MODE_OK_INVERTED :: #run make_graphics_mode(background = .BLACK, foreground = .BRIGHT_GREEN);
MODE_WAIT :: #run make_graphics_mode(foreground = .BLACK, background = .BRIGHT_YELLOW);
MODE_WAIT_INVERTED :: #run make_graphics_mode(foreground = .BRIGHT_YELLOW, background = .BLACK);

MODE_START_MENU_TITLE :: #run make_graphics_mode(foreground = .BRIGHT_GREEN);
MODE_SOLUTION_SLOT :: #run make_graphics_mode(foreground = .BLACK, background = .BRIGHT_BLUE);
MODE_SOLUTION_SLOT_SELECTED :: MODE_DEFAULT_INVERTED;

MODE_TEXT_DESCRIPTION :: #run make_graphics_mode(foreground = .BRIGHT_GREEN);

MODE_BORDER_NUMBERS :: #run make_graphics_mode(background = .BLACK, foreground = .BRIGHT_BLUE);
BORDER_NUMBERS_WFREQ, BORDER_NUMBERS_HFREQ :: 20, 10;

MODE_CIRCUIT_MAIN  :: MODE_DEFAULT;
MODE_CIRCUIT_ID    :: MODE_DEFAULT;
MODE_CIRCUIT_LABEL :: MODE_DEFAULT; 
MODE_CIRCUIT_COST  :: #run make_graphics_mode(foreground = .BRIGHT_YELLOW);

MODE_WIRE_GREEN  :: #run make_graphics_mode(foreground = .BRIGHT_GREEN);
MODE_WIRE_RED    :: #run make_graphics_mode(foreground = .BRIGHT_RED);
MODE_WIRE_YELLOW :: #run make_graphics_mode(foreground = .BLACK, background = .BRIGHT_YELLOW);

MODE_EDITOR_DEFAULT :: #run make_graphics_mode(background = .BLACK, foreground = .BRIGHT_GREEN);
MODE_EDITOR_INVERTED:: #run make_graphics_mode(background = .BRIGHT_GREEN, foreground = .BLACK);
MODE_EDITOR_CURSOR  :: #run make_graphics_mode(background = .BRIGHT_YELLOW, foreground = .BLACK);
MODE_EDITOR_EMPTY   :: #run make_graphics_mode(background = .BLACK, foreground = .BRIGHT_BLUE);

MODE_RESULT_TEXT :: #run make_graphics_mode(foreground = .BRIGHT_GREEN);

MODE_LABEL_DEFAULT :: #run make_graphics_mode(background = .BRIGHT_GREEN, foreground = .BLACK); 
MODE_LABEL_PAUSED  :: #run make_graphics_mode(background = .BRIGHT_WHITE, foreground = .BLACK);

MODE_LABEL_HINT    :: #run make_graphics_mode(foreground = .BLACK, background = .BRIGHT_GREEN);

MODE_REGISTER :: #run make_graphics_mode(background = .BLACK, foreground = .BRIGHT_BLUE);

MODE_MATRIX_TAIL2 :: #run make_graphics_mode(foreground = .GREEN);
MODE_MATRIX_TAIL :: #run make_graphics_mode(foreground = .BRIGHT_GREEN);
MODE_MATRIX_CORE :: #run make_graphics_mode();
MATRIX_PALETTE :: Graphics_Mode.[MODE_MATRIX_CORE, MODE_MATRIX_TAIL, MODE_MATRIX_TAIL, MODE_MATRIX_TAIL2, MODE_MATRIX_TAIL2, MODE_MATRIX_TAIL2];