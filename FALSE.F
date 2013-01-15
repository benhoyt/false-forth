\ Portable False interpreter in Forth - by Ben Hoyt - 5 February 2000

0 [IF]

This is a False interpreter written in pure ANS Forth! See README.md
for more info.

Your words are:
FALSE" FALSE-FILE FALSE-BUFFER >FILE FILE> Stack# Return#

To interpret a file, push a string (address and count) on the stack
and tell Forth to FALSE-FILE. Alternatively, use FALSE" file". To
interpret a buffer of false source code in memory, give FALSE-BUFFER
the address and length of the buffer and you're away. To exemplify:

FALSE" my-false-file.f"  \ interpret this file
S" my-false-file.f" FALSE-FILE  \ ditto
S" 10[$][1-$.]#%" FALSE-BUFFER  \ countdown in False from 9..0

To redirect False input, use FILE> ("file-from"). To redirect output,
use >FILE ("to-file"). >FILE or FILE> with a count of zero will
revert to screen output or keyboard input, respectively. By default,
redirection is set to screen output and keyboard input. Every time
you initiate a False interpretation, the file positions of the
I/O files will be rewound to zero. Some examples:

S" output" >FILE  S" input" FILE>  \ redirect both output and input
FALSE" my-false-file.f"

S" new-out" >FILE  0 0 FILE>  \ redirect output, keyboard input
FALSE" my-false-file.f"

S" " >FILE  S" another-input" FILE>  \ screen output, file input
FALSE" my-false-file.f"

When the False interpreter is redirected to or from a file, it does
I/O in binary mode, so any CR or LF will get read in or written out
directly. When you are outputting to the screen, this interpreter
will ignore any carriage-returns (char 13) and execute a Forth CR
when it gets a line-feed (char 10). When you are inputting from the
keyboard, this interpreter will return a line-feed when you press
"Enter" (ie., when KEY gives char 13), and will return -1 when you
press Control-Z (end of file, see below).

You can also set False's data and return stack sizes by changing the
VALUEs Stack# and Return#. Just set them to a given size in False
"cells". Each data stack entry requires two Forth CELLs and each
return stack entry one Forth CELL of ALLOCATEd memory. So, for a small
stack, use something like:

100 TO Stack#  50 TO Return#  \ 100 item data stack, 50 item return

This program was written to be fully ANS Standard, and I hope it lives
up to that. It requires a 32 bit Forth system (I think only because
False is 32 bit -- I believe this compiles on a 16 bit system quite
well). I use words from the following wordlists:

CORE CORE-EXT FILE FILE-EXT MEMORY EXCEPTION SEARCH-ORDER TOOLS-EXT

One could easily remove use of the FILE-EXT MEMORY SEARCH-ORDER and
TOOLS-EXT wordlists. I think TOOLS-EXT is only used for this extended
comment, however. :-)

Note that I use Control-Z (character 26, hex 1A) when the False
interpreter is receiving keyboard characters to denote end-of-file.
Most Forths give character 26 when you press Control-Z. This is
irrelevant in file input mode anyway.

[THEN]


DECIMAL

MARKER UnFalse

1000 VALUE Stack#  \ data and return stack sizes, can be changed
1000 VALUE Return#

WORDLIST CONSTANT FalseWords  \ all internal False interpreter words
GET-ORDER FalseWords SWAP 1+ SET-ORDER  \ use FalseWords
GET-CURRENT  \ "previous current" on stack
DEFINITIONS  \ compile into FalseWords

0 CONSTANT =Num  \ False data type identifiers
1 CONSTANT =Func
2 CONSTANT =Addr
3 CONSTANT =Uninit

: PLACE  ( a u dest -- )  \ place counted string a u at dest
  2DUP 2>R  CHAR+ SWAP CHARS MOVE  2R> C! ;

: STRING,  ( a u -- )  \ reserve space for and store string
  HERE  OVER 1+ CHARS ALLOT  PLACE ;

: STR  ( "<ch> ccc<ch>" -- cstr )  \ parse, reserve and return string
  HERE  BL PARSE DROP C@ PARSE  STRING, ;

\ List of error messages and types

STR | char expected|
STR | return stack underflow|
STR | return stack overflow|
STR | unbalanced '['|
STR | unbalanced '"'|
STR | unbalanced '{'|
STR | inline assembly unavailable|
STR | unknown symbol|
STR | stack not empty at program exit|
STR | type conflict|
STR | data stack underflow|
STR | data stack overflow|
STR | source too large|  \ errors 1 2 and 3 are unused
STR | could not open source file|
STR | no arguments|

CREATE ErrorStrs  \ error messages (15 of them)
  , , , , ,  , , , , ,  , , , , ,

STR | unexpected|
STR | uninitialised|
STR | address|
STR | function|
STR | number|

CREATE TypeStrs  \ data types (5 of them)
  , , , , ,

: TypeTYPE  ( type -- )  \ display type string
  DUP 3 U> IF  DROP 4  THEN  \ make sure it's in range
  CELLS TypeStrs + @  COUNT TYPE ;  \ display

\ Input/output and redirection

0 VALUE InFile  0 VALUE OutFile  \ in and out file-ids
CREATE CharBuf  0 C,  \ temp storage for cEmit

: Putch  ( char -- )  \ write char to False output
  OutFile IF
    CharBuf C!  CharBuf 1 OutFile WRITE-FILE THROW
  ELSE
    DUP 10 = IF  CR  ELSE  \ do a CR if line feed char
    DUP 13 <> IF  DUP EMIT  THEN THEN  DROP  \ ignore CRs
  THEN ;

: Puts  ( a u -- )  \ write string to False output
  OVER + SWAP ?DO  I C@ Putch  LOOP ;

: Getch  ( -- char )  \ read char from False input
  InFile IF
    CharBuf 1 InFile READ-FILE THROW
    IF  CharBuf C@  ELSE  -1  THEN  \ char -1 means end-of-file
  ELSE
    KEY  DUP 13 = IF  CR  DROP 10  \ replace CR with LF
    ELSE  DUP EMIT  DUP 26 = IF  DROP -1  THEN  THEN
  THEN ;

\ Source buffer stuff

0 VALUE Src  0 VALUE Src#  \ source buffer pointer
VARIABLE p  \ pointer into source buffer

: SrcEnd?  ( -- flag )  \ true if end of source buffer
  p @  Src Src# CHARS +  U< 0= ;

: SrcChar  ( -- char )  \ grab char from source, don't move pointer
  p @ c@ ;

: SrcInc  ( -- )  \ move source pointer along a char
  1 CHARS p +!  ;

: NextChar  ( -- char )  \ grab next char from source buffer
  SrcChar SrcInc ;

\ False stack manipulation

0 VALUE StackB  0 VALUE StackE  \ data stack beginning and end
0 VALUE ReturnB  0 VALUE ReturnE  \ return stack
VARIABLE s  VARIABLE r  \ data and return stack pointers

VARIABLE Expected  VARIABLE Received  \ expected and received types
VARIABLE Debugging  \ debugging flag (stack dump etc)

: Push  ( x type -- )  \ push x with type
  s @ 2 CELLS -  DUP StackB U< 4 AND THROW  \ overflow?
  DUP s !  2! ;  \ type is on top

: Popt  ( -- x type  )  \ pop x and type, no check
  s @ 2 CELLS +  DUP StackE U> 5 AND THROW  \ underflow?
  s @ 2@  ROT s ! ;  \ fetch and set new stack pointer

: Pop  ( type -- x )  \ pop x, check type
  DUP Expected !  Popt  Dup Received !  \ save types for errors
  ROT <> 6 AND THROW ;  \ check for type conflict

: nPush  ( n -- )  \ push number
  =Num Push ;

: nPop  ( -- n )  \ pop number
  =Num Pop ;

: rPush  ( x -- )  \ push x to return stack
  r @ 1 CELLS -  DUP ReturnB U< 13 AND THROW
  DUP r !  ! ;

: rPop  ( -- x )  \ pop x from return stack
  r @ CELL+  DUP ReturnE U> 14 AND THROW
  r @ @  SWAP r ! ;

: Func  ( func -- )  \ enter lambda function
  p @ rPush  p ! ;

\ Variable space handling

0 VALUE Vars  \ variable space

: Var?  ( char -- t=var )  \ true if char is variable a..z
  [CHAR] a - 26 U< ;

: Var!  ( x type vaddr -- )  \ store x and type in variable
  2* CELLS Vars + 2! ;

: Var@  ( vaddr -- x type )  \ fetch x and type from variable
  2* CELLS Vars + 2@ ;

: Var  ( 0..25 -- )  \ push False variable "address"
  =Addr Push ;

: MakeVars  ( -- xt-z .. xt-a )  \ make words to do each variable
  0 25 DO
    :NONAME  I POSTPONE LITERAL POSTPONE Var POSTPONE ;
  -1 +LOOP ;

\ Number conversion

: (.)  ( n -- a u )  \ return string to display n
  DUP ABS 0  <# #S ROT SIGN #> ;  \ False . will use Forth's BASE

: Number  ( 0..9 -- )  \ parse and push False number
  BEGIN
    SrcEnd? 7 AND THROW  \ finished source but stack not empty
    SrcChar  [CHAR] 0 -  DUP 10 U< WHILE  \ go till non-digit
    SrcInc  SWAP 10 *  +  \ convert and accumulate
  REPEAT  DROP nPush ;  \ push it to False stack

: MakeNumbers  ( -- xt-9 .. xt-0 )  \ make words to do each digit
  0 9 DO
    :NONAME  I POSTPONE LITERAL POSTPONE Number POSTPONE ;
  -1 +LOOP ;

\ Some False operator stuff

: BinaryOp  ( xt -- )  \ execute binary operator xt on False stack
  nPop nPop SWAP  ROT EXECUTE nPush ;  \ False: n1 n2 -- n3

: LAND  ( n1 n2 -- flag )  \ true if n1 and n2 are nonzero
  0<> SWAP 0<> AND ;  \ like C's logical and operator &&

: LOR  ( n1 n2 -- flag )  \ true if n1 or n2 is nonzero
  0<> SWAP 0<> OR ;  \ like C's logical or operator ||

\ Words for all the False symbols, these don't touch the Forth stack

: cWhite    ;
: cBad      8 THROW ;
: cApply    =Func Pop Func ;
: cDup      Popt 2DUP Push Push ;
: cDrop     Popt 2DROP ;
: cAnd      ['] LAND BinaryOp ;
: cChar     SrcEnd? 15 AND THROW  NextChar nPush ;
: cStar     ['] * BinaryOp ;
: cPlus     ['] + BinaryOp ;
: cMinus    ['] - BinaryOp ;
: cSlash    ['] / BinaryOp ;
: cStore    =Addr Pop Popt  ROT Var! ;
: cFetch    =Addr Pop Var@  Push ;
: cEquals   Popt Pop = nPush ;  \ equals works with any one type
: cGreater  ['] > BinaryOp ;  \ greater only works with numbers
: cIf       =Func Pop nPop IF  Func  ELSE DROP THEN ;
: cRot      Popt Popt Popt  2ROT 2ROT  Push Push Push ;
: cDebug    Debugging @ 0= Debugging ! ;
: cSwap     Popt Popt  2SWAP  Push Push ;
: cNegate   nPop NEGATE nPush ;
: cAsm      9 THROW ;
: cOr       ['] LOR BinaryOp ;
: cNot      nPop INVERT nPush ;
: cEmit     nPop Putch ;
: cDot      nPop (.) Puts ;
: cRead     Getch nPush ;

: cFlush  \ flush I/O (only output for us)
  OutFile IF  \ truncate to current file position and flush
    OutFile FILE-POSITION THROW  OutFile RESIZE-FILE THROW
    OutFile FLUSH-FILE THROW
  THEN ;

: cString  \ output all chars till ending quote
  BEGIN
    SrcEnd? 11 AND THROW  NextChar DUP [CHAR] " <> WHILE
    Putch
  REPEAT  DROP ;

: cPick  \ pick, zero based, 0O is $ (ie., 0 PICK is DUP)
  nPop 2* CELLS s @ +
  DUP s @ StackE WITHIN 0=  5 AND THROW  \ bounds check
  2@ Push ;  \ push value and type

: cComment  \ ignore all chars till ending brace, non-nesting
  BEGIN  SrcEnd? 10 AND THROW  NextChar  [CHAR] } = UNTIL ;

: cWhile  \ False return stack: if-func do-func p-afterwhile 0
  =Func Pop =Func Pop  TUCK rPush rPush  Func  0 rPush ;

: cLambda  \ parse nested lambdas, return function
  p @ =Func Push  1 BEGIN  \ nest depth on stack
    SrcEnd? 12 AND THROW  DUP 0> WHILE
    NextChar CASE
      [CHAR] ' OF  \ skip char after ' (in case it's [ or " etc)
        SrcEnd? 15 AND THROW  NextChar DROP  ENDOF
      [CHAR] ] OF  1-  ENDOF  \ nest into lambda
      [CHAR] [ OF  1+  ENDOF  \ unnest lambda
      [CHAR] { OF  cComment  ENDOF  \ skip comments
      [CHAR] " OF  \ skip strings
        BEGIN  SrcEnd? 11 AND THROW  NextChar [CHAR] " = UNTIL  ENDOF
      \ ignore anything else
    ENDCASE
  REPEAT  DROP ;

: cAdbmal  \ end lambda function
  rPop CASE
    0 OF  \ just finished comparison part of while construct
      rPop p !  \ set p to just after while #
      nPop IF  \ flag<>0, start executing "do" lambda
        rPop DUP rPush  Func  1 rPush
      ELSE  rPop rPop 2DROP  THEN  ENDOF  \ flag=0, skip to after #
    1 OF  \ just finished function part of while construct
      rPop p !  rPop rPop TUCK rPush rPush  Func  0 rPush  ENDOF
    DUP p !  \ end lambda function "normally"
  ENDCASE ;

\ Create the symbol jump table

: TICKS-OF  ( n "word" -- )  \ comma n xt's of word
  '  SWAP 0 ?DO  DUP ,  LOOP  DROP ;

: TICKS  ( n "words" -- )  \ tick and comma n words
  0 ?DO  ' ,  LOOP ;

MakeVars  MakeNumbers  \ 36 xt's on stack for digits and variables

CREATE Jumper  \ 256-char jump table for False symbols
  32 TICKS-OF cWhite  \ treat all low ASCII chars as whitespace
  \       BL     !      "       #      $    %     &    '
  8 TICKS cWhite cApply cString cWhile cDup cDrop cAnd cChar
  \       (    )    *     +     ,     -      .    /
  8 TICKS cBad cBad cStar cPlus cEmit cMinus cDot cSlash
  \ 0 1 2 3 4 5 6 7 8 9          :      ;      <    =       >        ?
    , , , , , , , , , ,  6 TICKS cStore cFetch cBad cEquals cGreater cIf
  \       @    A    B      C    D       E through N       O
  5 TICKS cRot cBad cFlush cBad cDebug  10 TICKS-OF cBad  1 TICKS cPick
  \ P through Z             [       \     ]       ^     _
  11 TICKS-OF cBad  5 TICKS cLambda cSwap cAdbmal cRead cNegate
  \       `     a b c d e f g h i j  k l m n o p q r s t  u v w x y z
  1 TICKS cAsm  , , , , , , , , , ,  , , , , , , , , , ,  , , , , , ,
  \       {        |   }    ~
  5 TICKS cComment cOr cBad cNot cBad
  \ high ASCII chars begin here, all bad except the Amiga flush and pick
  \                         ß $DF                             ø $F8
  95 TICKS-OF cBad  1 TICKS cFlush  24 TICKS-OF cBad  1 TICKS cPick
  7 TICKS-OF cBad

: Jump  ( char -- xt )  \ get the jump for symbol ch
  CELLS Jumper + @ ;

\ The False debugger

: Desplay  ( x type -- )  \ show item for debugger
  CASE
    =Num OF  .  ENDOF
    =Func OF  ." p="  Src - 1 CHARS / .  ENDOF
    =Addr OF  [CHAR] a + EMIT  SPACE  ENDOF
    NIP DUP TypeTYPE  SPACE
  ENDCASE ;

: Debugger  ( -- )  \ show debugging info: [ stack ... top | nextsymbol ]
  SrcEnd? 0= IF  \ if not at end of source
    SrcChar Jump  ['] cWhite <> IF  \ only if next symbol is non-white
      ." [ "  \ display top (max ten) stack items
      s @ 20 CELLS +  DUP StackE U> IF  DROP StackE  THEN
      BEGIN  DUP s @ U> WHILE  2 CELLS -  DUP 2@ Desplay  REPEAT
      DROP  ." | "  SrcChar EMIT  ."  ] "  \ show next symbol
    THEN
  THEN ;

\ The False and deceitful interpreter

: Falsehood  ( -- )  \ interpret False characters
  BEGIN
    SrcEnd? 100 AND THROW
    NextChar  Jump EXECUTE  \ get char and go to its symbol
    Debugging @ IF  Debugger  THEN
  AGAIN ;

: Deceit  ( n -- )  \ process a False deception (error)
  DUP 100 =  s @ StackE <>  AND IF  DROP 7  THEN  \ stack not empty at end
  DUP 100 <> IF  \ 100 means normal end, else error
    DUP DUP 0< AND THROW  \ reTHROW internal errors
    CR  ." Error "  DUP .  ." at char "
    p @ Src - 1 CHARS /  0 .R  ." : "
    DUP 1 16 WITHIN IF  \ in the range of our errors?
      DUP 1- CELLS ErrorStrs + @  COUNT TYPE  SPACE  \ display error msg
      DUP 6 = IF  \ type conflict, show types involved
        CR ." Expecting "  Expected @ TypeTYPE
        ."  and received " Received @ TypeTYPE  SPACE
      THEN
    ELSE  ." unexpected error"  THEN  \ some wacko error!
  THEN  DROP ;

: Buffer  ( -- )  \ interpret the False buffer
  Stack# 2* CELLS ALLOCATE THROW  TO StackB  \ allocate False data stack
  StackB Stack# 2* CELLS + TO StackE  StackE s !
  Return# CELLS ALLOCATE THROW  TO ReturnB  \ allocate False return stack
  ReturnB Return# CELLS + TO ReturnE  ReturnE r !
  52 CELLS ALLOCATE THROW  TO Vars  \ allocate 26 variables/types
  26 0 DO  0 =Uninit I Var!  LOOP  \ undefine variables
  Src p !  \ init source pointer
  -1 Expected !  -1 Received !  \ unexpected types
  FALSE Debugging !  \ not debugging by default
  OutFile IF  0. OutFile REPOSITION-FILE THROW  THEN  \ rewind I/O files
  InFile IF  0. InFile REPOSITION-FILE THROW  THEN
  ['] Falsehood CATCH  \ catch the interpreter
  Vars FREE THROW  StackB FREE THROW  ReturnB FREE THROW  \ free memory
  Deceit  cFlush ;  \ process False deceptions, flush output

SET-CURRENT  \ public words in previous current

: >FILE  ( a u -- )  \ write False output to file named a u
  OutFile ?DUP IF  CLOSE-FILE THROW  THEN
  DUP 0= IF  2DROP 0  \ if u=0 then write to screen
  ELSE  W/O BIN CREATE-FILE THROW  THEN TO OutFile ;

: FILE>  ( a u -- )  \ read False input from file named a u
  InFile ?DUP IF  CLOSE-FILE THROW  THEN
  DUP 0= IF  2DROP 0  \ if u=0 then read from keyboard
  ELSE  R/O BIN OPEN-FILE THROW  THEN TO InFile ;

: FALSE-BUFFER  ( a u -- )  \ interpret buffer of False
  TO Src# TO Src  Buffer ;

: FALSE-FILE  ( a u -- )  \ interpret source file named by string a u
  R/O BIN OPEN-FILE THROW  >R  \ open in binary mode
  R@ FILE-SIZE THROW DROP  TO Src#  \ get file size
  Src# CHARS ALLOCATE THROW TO Src  \ allocate buffer for source
  Src Src# R@ READ-FILE THROW  Src# <> -39 AND THROW  \ read in whole file
  R> CLOSE-FILE THROW  \ close file
  Buffer  \ interpret buffer
  Src FREE THROW ;  \ free source buffer

: FALSE"  ( "filename<quote>" -- )  \ interpret False file
  [CHAR] " PARSE FALSE-FILE ;

PREVIOUS  \ remove FalseWords from search order

CR .( Portable False interpreter in Forth - by Ben Hoyt - 5 February 2000)
CR
CR .( Type FALSE" filename" to interpret a False file, or S" 42.")
CR .( FALSE-BUFFER to execute a given string of False source directly.)
CR
