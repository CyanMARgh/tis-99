#load "labels_spider.jai";

LABEL_IO441 :: #string STR 
 _      
(_)     
 _ ___  
| |   | 
| | | | 
|_|___| 
 __   _ 
|  \ / |
| | | / 
|_|\_/  
 __   _ 
|  \ / |
| | | / 
|_|\_/  
 _      
| | 4i4o
| |     
|_|  v1 
        
 Inkel' 
 81 (C) 
STR;

LABEL_IO102 :: #string STR 
 _   
| | |
| |_|
 ___ 
| _ |
|___|
     
 ___|
|   |
     
  |  
  |  
 ___ 
|   |
|___|
     
|___|
|   |
     
BMD' 
82(C)
     
1i0o 
v2   
STR;

LABEL_IO013 :: #string STR 
 _ _ 
| | |
| | |
     
 ___|
|   |
 ___ 
| _ |
|___|
     
  |  
  |  
 ___ 
|   |
|___|
     
|___|
|   |
     
BMD' 
82(C)
     
0i1o 
v3   
STR;


LABEL_TIS3 :: #string STR
  _____   _   ____              
 |_   _| |_| | ___|  .-'''-.    
   | |    _  | |__  /   _   \   
   | |   | |  \__ ||__/` '.  |  
   |_|   |_| |____|   .--'  /   
                   ___'--.   \  
    17ins 5reg    |   |__(    | 
    1i4o          |           | 
    Inkel' 79      \         /  
                    `-..__.-'   
STR

LABEL_SM255 :: #string STR
 S.M. 255
                                    
 .------------........._:.          
  \__--.-.               |          
          ^--.---_     Florida      
                  --     Instruments
                    |     .-        
                    |      -|       
                   |-.     .|       
                   .|.      ..      
                     .--      |     
                     .*|      |     
                       -.     |     
                        .|  .|.     
                         .-/-.      
                        --:.        
STR;

LABEL_2DFY :: #string STR
  ___     _  __           
 |__ \   | |/ _|      (TM)
    ) |__| | |_ _   _     
   / // _` |  _| | | |    
  / /| (_| | | | |_| |  a 
 |____\__,_|_|  \__, |  c 
                 __/ |  t 
     visuals   _/ ___/  i 
   ___________/ _/      v 
  /____________/        e 
STR;

LABEL_SOZAP :: #string STR
  ___             
 /   \            
 \___/  S|ingle   
  ___   O|r       
 |   |  Z|ero     
 |  |   A|rgument 
 |  |   P|rocessor
 |  |             
|____|   (C)      
                  
  Inkel' 82       
STR;

LABEL_JBMS3232 :: #run replace_with_zeroes(#char"?", #string STR 




??????????       ====  ========    =====     =====
??????????        ==    ===   ==    ===       === 
??????????        ==    ===   ==    ====     ==== 
??????????        ==    =======     == ==   == == 
??????????        ==    ===    ==   ==  == ==  == 
??????????  ==    ==    ===    ==   ==   ===   == 
??????????  ==    ==    ===    ==   ==    =    == 
??????????   ======    =========   ====       ====
??????????                                        
??????????    Ultra XD 3-bit dual screen. 30x30   
STR);

replace_with_zeroes :: (repl : u8, str : string) -> string {
  result := copy_string(str,, temp);
  for * cast([]u8)result {
    if it.* == repl then it.* = 0;
  }
  return result;
}

LABEL_JBMS32 :: #run replace_with_zeroes(#char"?", #string STR 




??????????       ====  ========    =====     =====
??????????        ==    ===   ==    ===       === 
??????????        ==    ===   ==    ====     ==== 
??????????        ==    =======     == ==   == == 
??????????        ==    ===    ==   ==  == ==  == 
??????????  ==    ==    ===    ==   ==   ===   == 
??????????  ==    ==    ===    ==   ==    =    == 
??????????   ======    =========   ====       ====
??????????                                        
??????????       Ultra XD 3-bit screen. 30x30     
STR);

LABEL_TWICS :: #string STR
          +---------------+
          | T. W. I. C. S.|
          | e  r  n  h  c |
          | l  i  p  a  r |
          | e  t  u  n  e |
          |    e  t  n  e |
  +-------------+    e  n |
  | I-O Quartz  |    l    |
  | Inc.        |---------+
  | y1981 q3    |          
  |    _____    |          
  |   |     |   |          
  |   | IOQ |   |          
  +---|_____|---+          
STR;
LABEL_TWOCS :: #string STR
+---------------+           
| T. W. O. C. S.|           
| e  r  u  h  c |           
| l  i  t  a  r |           
| e  t  p  n  e |           
|    e  u  n  e |           
|       t  e +-------------+
|          l |  I-O Quartz |
+------------|        Inc. |
             |    y1981 q4 |
             |    _____    |
             |   |     |   |
             |   | IOQ |   |
             +---|_____|---+
STR;
LABEL_Q5 :: #string STR


  Q-5  
STR;

TITLE :: #run tprint(#string END
  _______ _____  _____       ___   ___  
 |__   __|_   _|/ ____|     / _ \ / _ \ 
    | |    | | | (___ _____| (_) | (_) |
    | |    | |  \___ \______\__, |\__, |
    | |   _| |_ ____) |       / /   / / 
    |_|  |_____|_____/       /_/   /_/  

     % build
END, BUILD_DATE);
TITLE_WIDTH :: #run -> int {
    l := 0;
    for split(TITLE, "\n") {
        l = max(l, it.count);
    }
    return l;
};

LABEL_BUTTERFLY :: #string STR
                             _.
                          _,/ :
                        ,/   ,|
                      ,/     :
;".____            ,/      ,/
|       \.__      ,/        |
 \          \_`:'_:         ;
  \           \:/           /
   |           ::.         /
   `:          `::         `:
     \          ::          |
     :          `:._        /
     |         /'  "\,    ,"
      \       :      \._.* 
       \_____/

STR;