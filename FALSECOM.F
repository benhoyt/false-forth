\ 80386 False compiler in Forth - by Ben Hoyt - 7 February 2000

0 [IF]

Yes, a real 80386 False compiler in Forth! See README.md for for more
info.

Your words are:
FALSE" FALSE-FILE FALSE-BUFFER

They compile the executable (DOS .COM format, requires 386) to A.COM
No optimisation is done (like the original Amiga compiler :-) but it
is reasonably speedy for a fun language anyway.

This program was written to be ANS Standard, but it assumes you have
a 32 bit system, and that your Forth CHAR is equal to an 8-bit byte.
Other than that, it's probably not too system-dependent.

[THEN]


DECIMAL

MARKER UnFalse

WORDLIST CONSTANT FalseWords  \ all internal False compiler words
GET-ORDER FalseWords SWAP 1+ SET-ORDER  \ use FalseWords
GET-CURRENT  \ "previous current" on stack
DEFINITIONS  \ compile into FalseWords

: $  ( "word" -- )  \ evaluate next word in hex
  BASE @ >R  HEX  BL PARSE EVALUATE  R> BASE ! ;  IMMEDIATE

\ Object code output

0 VALUE CodeBuf  0 VALUE CP  \ code buffer and pointer
CREATE Code"Buf  256 CHARS ALLOT  \ buffer for Code"

: CodeStr  ( a u -- )  \ output a code string
  CodeBuf CP +  SWAP  DUP CP + TO CP  MOVE ;

: CodeByte  ( byte -- )  \ output a code byte
  CodeBuf CP + C!  CP 1+ TO CP ;  \ assumes Forth char = byte

: -LEADING  ( a u -- a' u' )  \ skip leading spaces in string
  BEGIN
    DUP WHILE  OVER C@ BL = WHILE  1 /STRING
  REPEAT THEN ;

: Code"  ( "hex hex hex...<quote>" -- )  \ compile code to compile code :-)
  BASE @ HEX  Code"Buf 0  [CHAR] " PARSE
  BEGIN
    -LEADING  DUP WHILE  \ skip spaces
    0. 2SWAP >NUMBER 2>R DROP  \ convert next hex byte
    >R 2DUP CHARS +  R> SWAP C!  1+  2R>  \ store it in buffer
  REPEAT  2DROP
  POSTPONE SLITERAL  POSTPONE CodeStr  \ compile code at runtime
  BASE ! ;  IMMEDIATE  \ must be an immediate word!

: Code16  ( x -- )  \ compile x in code as 16-bit word
  DUP $ 0FF AND CodeByte  8 RSHIFT  $ 0FF AND CodeByte ;

: Code16!  ( x addr -- )  \ store x in code at addr as 16-bit word
  OVER $ 0FF AND OVER CodeBuf + C!  \ low byte first
  SWAP 8 RSHIFT SWAP  1+ CodeBuf + C! ;

: Code32  ( x -- )  \ compile x in code as 32-bit dword
  DUP $ 0FF AND CodeByte  8 RSHIFT
  DUP $ 0FF AND CodeByte  8 RSHIFT  Code16 ;

VARIABLE LastSize  \ last CodePush size, t=byte (for inline code)

: CodePush  ( x -- )  \ compile code to push 32-bit x
  DUP -128 128 WITHIN  DUP LastSize !
  IF  Code" 66 6A" CodeByte  \ use 8-bit push if we can (sign extended)
  ELSE  Code" 66 68"  Code32  THEN ;

: CodeInit  ( -- )  \ compile startup code
  \ mov sp,$FFFC; mov bp,$F000; jmp start
  Code" BC FC FF  BD 00 F0  EB 39"
  \ dot: mov di,$DF98; or eax,eax; pushf; jns >L2; neg eax;
  Code" BF 98 DF  66 0B C0  9C  79 03  66 F7 D8"
  \ L2: sub edx,edx; mov ebx,10; div ebx; add dl,'0'; dec di; mov [di],dl
  Code" 66 2B D2  66 BB 0A 00 00 00  66 F7 F3  80 C2 30  4F  88 15"
  \ or eax,eax; jnz L2; popf; jns >L3; dec di; mov [di],'-'; L3: mov ah,$40
  Code" 66 0B C0  75 E9  9D  79 04  4F  C6 05 2D  B4 40"
  \ mov bx,1; mov cx,$DF98; sub cx,di; mov dx,di; int $21; ret;
  Code" BB 01 00  B9 98 DF  2B CF  8B D7  CD 21  C3" ;

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

\ Words for all the False symbols

: cWhite    ;
: cBad      1 THROW ;
: cDebug    2 THROW ;
: cChar     SrcEnd? 3 AND THROW  NextChar CodePush ;

: cApply  \ pop ebx; sub bp,2; mov [bp],L1; jmp bx; L1:
  Code" 66 5B  83 ED 02  C7 46 00 00 00  FF E3"
  CP CP 4 - Code16! ;

: cDup  \ pop eax; push eax; push eax
  Code" 66 58 66 50 66 50" ;

: cDrop  \ pop eax
  Code" 66 58" ;

: cAnd  \ pop ebx; pop eax; or eax,eax; setnz al; or ebx,ebx; setnz bl
        \ and al,bl; neg al; movsx eax,al; push eax
  Code" 66 5B  66 58  66 0B C0  0F 95 C0  66 0B DB  0F 95 C3"
  Code" 22 C3  F6 D8  66 0F BE C0  66 50" ;

: cStar  \ pop ebx; pop eax; imul ebx; push eax
  Code" 66 5B  66 58  66 F7 EB  66 50" ;

: cPlus  \ pop ebx; pop eax; add eax,ebx; push eax
  Code" 66 5B  66 58  66 03 C3  66 50" ;

: cMinus  \ pop ebx; pop eax; sub eax,ebx; push eax
  Code" 66 5B  66 58  66 2B C3  66 50" ;

: cSlash  \ pop ebx; pop eax; cdq; idiv ebx; push eax
  Code" 66 5B  66 58  66 99  66 F7 FB  66 50" ;

: cStore  \ pop ebx; pop dword [bx]
  Code" 66 5B  66 8F 07" ;

: cFetch  \ pop ebx; push dword [bx]
  Code" 66 5B  66 FF 37" ;

: cEquals  \ pop ebx; pop eax; sub eax,ebx; sub eax,1; sbb eax,eax; push eax
  Code" 66 5B  66 58  66 2B C3  66 2D 01 00 00 00  66 1B C0  66 50" ;

: cGreater  \ pop ebx; pop eax; sub ecx,ecx; cmp eax,ebx
            \ jle >L1; dec ecx; L1: push ecx
  Code" 66 5B  66 58  66 2B C9  66 3B C3  7E 02  66 49  66 51" ;

: cIf  \ pop ebx; pop eax; or eax,eax;
       \ jz >L1; sub bp,2; mov [bp],L1; jmp bx; L1:
  Code" 66 5B  66 58  66 0B C0  74 0A  83 ED 02  C7 46 00 00 00  FF E3"
  CP CP 4 - Code16! ;

: cRot  \ pop ecx; pop ebx; pop eax; push ebx; push ecx; push eax
  Code" 66 59  66 5B  66 58  66 53  66 51  66 50" ;

: cSwap  \ pop ebx; pop eax; push ebx; push eax
  Code" 66 5B  66 58  66 53  66 50" ;

: cNegate  \ pop eax; neg eax; push eax
  Code" 66 58  66 F7 D8  66 50" ;

: cAsm  \ inline code: back-up and fetch byte, then compile to code
  CodeBuf CP +
  LastSize @ IF  1 - C@  CP 3  ELSE  4 - C@  CP 6  THEN
  - TO CP  CodeByte ;

: cOr  \ pop ebx; pop eax; or eax,eax; setnz al; or ebx,ebx; setnz bl
       \ or al,bl; neg al; movsx eax,al; push eax
  Code" 66 5B  66 58  66 0B C0  0F 95 C0  66 0B DB  0F 95 C3"
  Code" 0A C3  F6 D8  66 0F BE C0  66 50" ;

: cNot  \ pop eax; not eax; push eax
  Code" 66 58  66 F7 D0  66 50" ;

: cEmit  \ mov ah,$40; mov bx,1; mov cx,1; mov dx,sp; int $21; pop eax
  Code" B4 40  BB 01 00  B9 01 00  8B D4  CD 21  66 58" ;

: cRead  \ mov ah,$3f; sub bx,bx; mov cx,1; push dword 0; mov dx,sp;
         \ int $21; or ax,ax; jnz >L1; mov bx,sp; mov dword [bx],-1; L1:
  Code" B4 3F  2B DB  B9 01 00  66 6A 00  8B D4"
  Code" CD 21  0B C0  75 09  8B DC  66 C7 07 FF FF FF FF" ;

: cDot  \ pop eax; call dot;
  Code" 66 58  E8"  $ 0108 CP 2 + - Code16 ;

: cString  \ mov ah,$40; mov bx,1; mov cx,size; mov dx,S; int $21;
           \ jmp >L1; S: db string; L1:
  Code" B4 40  BB 01 00  B9 00 00  BA 00 00  CD 21  E9 00 00"
  CP  DUP DUP 7 - Code16!  \ patch string address
  BEGIN
    SrcEnd? 4 AND THROW  NextChar DUP [CHAR] " <> WHILE
    CodeByte
  REPEAT  DROP
  CP OVER -  SWAP 2DUP 10 - Code16!  \ patch string length
  2 - Code16! ;  \ patch jump instruction

: cPick  \ pop eax; shl ax,2; mov bx,sp; add bx,ax; push dword [bx]
  Code" 66 58  C1 E0 02  8B DC  03 D8  66 FF 37" ;

: cComment  \ ignore all chars till ending brace, non-nesting
  BEGIN  SrcEnd? 5 AND THROW  NextChar  [CHAR] } = UNTIL ;

: cWhile  \ False return stack: if-func do-func
  \     pop ebx; pop eax; sub bp,4; mov [bp],bx; mov [bp+2],ax
  \ L3: mov bx,[bp+2]; sub bp,2; mov [bp],L1; jmp bx;
  \ L1: pop eax; or eax,eax; jz >L2; mov bx,[bp];
  \     sub bp,2; mov [bp],L3; jmp bx;
  \ L2: add bp,4
  Code" 66 5B  66 58  83 ED 04  89 5E 00  89 46 02"  CP
  Code" 8B 5E 02  83 ED 02  C7 46 00 00 00  FF E3"  CP CP 4 - Code16!
  Code" 66 58  66 0B C0  74 0D  8B 5E 00"
  Code" 83 ED 02  C7 46 00 00 00  FF E3"  CP 4 - Code16!
  Code" 83 C5 04" ;

\ The Forth stack is used as a "lambda stack" during compilation

: cLambda  \ push lambda-func; jmp after-lambda
  CP 9 + CodePush  Code" E9 00 00"  CP ;

: cAdbmal  \ mov bx,[bp]; add bp,2; jmp bx
  Code" 8B 5E 00  83 C5 02  FF E3"
  CP OVER - SWAP 2 - Code16! ;  \ patch pre-lambda jump

\ Create the symbol jump table

: Var  ( 0..25 -- )  \ compile code to push False variable address
  2 LSHIFT $ DF98 + CodePush ;

: MakeVars  ( -- xt-z .. xt-a )  \ make words to do each variable
  0 25 DO
    :NONAME  I POSTPONE LITERAL POSTPONE Var POSTPONE ;
  -1 +LOOP ;

: Number  ( 0..9 -- )  \ parse and compile code to push False number
  BEGIN
    SrcEnd? 3 AND THROW  \ expecting symbol after number
    SrcChar  [CHAR] 0 -  DUP 10 U< WHILE  \ go till non-digit
    SrcInc  SWAP 10 *  +  \ convert and accumulate
  REPEAT  DROP  CodePush ;

: MakeNumbers  ( -- xt-9 .. xt-0 )  \ make words to do each digit
  0 9 DO
    :NONAME  I POSTPONE LITERAL POSTPONE Number POSTPONE ;
  -1 +LOOP ;

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
  5 TICKS cRot cBad cWhite cBad cDebug  10 TICKS-OF cBad  1 TICKS cPick
  \ P through Z             [       \     ]       ^     _
  11 TICKS-OF cBad  5 TICKS cLambda cSwap cAdbmal cRead cNegate
  \       `     a b c d e f g h i j k l m n o p q r s t u v w x y z
  1 TICKS cAsm  , , , , , , , , , , , , , , , , , , , , , , , , , ,
  \       {        |   }    ~
  5 TICKS cComment cOr cBad cNot cBad
  \ high ASCII chars begin here, all bad except the Amiga flush and pick
  \                         ß $DF                             ø $F8
  95 TICKS-OF cBad  1 TICKS cWhite  24 TICKS-OF cBad  1 TICKS cPick
  7 TICKS-OF cBad

: Jump  ( char -- xt )  \ get the jump for symbol ch
  CELLS Jumper + @ ;

\ The False and deceitful compiler

: Falsehood  ( -- )  \ interpret False symbols
  BEGIN  SrcEnd? 0= WHILE  NextChar  Jump EXECUTE  REPEAT ;

: Deceit  ( n -- )  \ process a False deception (error)
  ?DUP IF
    DUP DUP 0< AND THROW  \ reTHROW internal errors
    CR  ." Error "  DUP .  ." at char "  \ show what/where the error was
    p @ Src - 1 CHARS /  0 .R  ." : "
    CASE
      1 OF  ." unknown symbol "  ENDOF
      2 OF  ." debugger unavailable "  ENDOF
      3 OF  ." char expected "  ENDOF
      4 OF  ." unbalanced '"  [CHAR] " EMIT  ." ' "  ENDOF
      5 OF  ." unbalanced '{' "  ENDOF
      ." unexpected error "  \ some weird error!
    ENDCASE
  THEN ;

: Buffer  ( -- )  \ interpret the False buffer
  65536 ALLOCATE THROW  To CodeBuf  \ allocate code buffer
  $ 100 TO CP  \ COM program loads at 100 hex
  CodeInit  \ compile init code
  Src p !  \ init source pointer
  ['] Falsehood CATCH  \ catch the symbol interpreter
  Code" B8 00 4C CD 21"  \ compile "exit to DOS" code
  S" a.com" W/O BIN CREATE-FILE THROW  \ write .COM executable
  DUP  CodeBuf CP $ 100 /STRING  ROT WRITE-FILE THROW
  CLOSE-FILE THROW  CodeBuf FREE THROW  \ free code buffer
  Deceit ;  \ process False deceptions

SET-CURRENT  \ public words in previous current

: FALSE-BUFFER  ( a u -- )  \ compile False buffer
  TO Src# TO Src  Buffer ;

: FALSE-FILE  ( a u -- )  \ compile source file named by string a u
  R/O BIN OPEN-FILE THROW  >R  \ open in binary mode
  R@ FILE-SIZE THROW DROP  TO Src#  \ get file size
  Src# CHARS ALLOCATE THROW TO Src  \ allocate buffer for source
  Src Src# R@ READ-FILE THROW  Src# <> -39 AND THROW  \ read in whole file
  R> CLOSE-FILE THROW  \ close file
  Buffer  \ parse, interpret and compile buffer
  Src FREE THROW ;  \ free source buffer

: FALSE"  ( "filename<quote>" -- )  \ compile a False file
  [CHAR] " PARSE FALSE-FILE ;

PREVIOUS  \ remove FalseWords from search order

CR .( False compiler in Forth - by Ben Hoyt - 5 February 2000)
CR
CR .( Type FALSE" filename" to compile a False file to A.COM, or
CR .( S" 42." FALSE-BUFFER to compile a given string of False source.)
CR
