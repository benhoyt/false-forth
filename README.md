
A False interpreter and compiler written in ANS Forth
=====================================================

**Historical note:** I wrote this in 2000 (when I was 18), so I'm just putting
it up here as a backup and for "historical interest".
[False](http://en.wikipedia.org/wiki/FALSE) is definitely one of the more
elegant esoteric languages, and I still a have soft spot for False,
Forth, Factor, and other F-languages. :-)

All the documentation that follows (and the comments in the Forth source
files) is original.

Introduction
------------

A False interpreter in Forth! What next? A False compiler of course! If you
don't already know what the False programming language is, go read [Wouter van
Oortmerssen's False page](http://strlen.com/false-language) -- this compiler
is referred to there under "False Links". Or go to [Wouter's home
page](http://strlen.com/).

False was meant to be cryptic and fun, but it does have a few neat
features: its functional nature and "lambda calculus" with the [ and
] structure, and its stack-based architecture. Anyway, it's just a
toy, and so is this (very slow) interpreter. Hopefully the compiler
will do a faster job when I get it going.

What's included
---------------

The Forth source for the interpreter and compiler:

    False.F     ANS Forth source for a False interpreter
    FalseCom.F  semi-ANS Forth source for a DOS 386 False compiler

You just need a 32 bit ANS Forth system to run 'em --
[Gforth](http://www.gnu.org/software/gforth/), for example.

Then type "INCLUDE False.F" or "INCLUDE FalseCom.F" and you're away.

See the extended comments at the top of the source files for more information.

I've also included some False examples, mostly from the original False
distribution:

    DUMP.FAL        hex dumper, 16 chars/line, extra space after 8 chars
    EVAL.FAL        infix expression evaluator
    FAC.FAL         actorial program
    FBREAK.FAL      FALSE Breakout game by Ed Mackey

Notes on the code
-----------------

In writing the code I copied the basic data structures (like stacks
and the source pointer) from Wouter van Oortmerssen's original
"Portable False" interpreter in C. One thing I tried not to copy was
his "good C style". :-) I tried rather to use some of Forth's
features like CATCH and THROW, ability to create many small words
easily, and the ability to easily create jump tables.

Basically the interpreter grabs a character from the False buffer,
looks an execution token up in a 256-cell jump table, and EXECUTEs
that. Clean and simple. Even the digits and variables are done
that way (albeit at the expense of quite a few similar words, see
MakeVars and MakeNumbers). I didn't make it a "pure state machine",
so whenever it comes across a comment { or lambda [ or quote " it
doesn't switch state and keep going, but parses there and then.

I fixed a little bug in Wouter's "Portable False", namely that the
' symbol was ignored while parsing inside lambda constructs. So if
you had '" or '] or something, his Portable False would burp.
Personally I believe False's ~ operator should be a logical not
rather than a bitwise not. Ie., should be 0= rather than INVERT,
but it might have broken existing code if I changed it. So use ~
only on flags returned by False's > or = or as a bitwise invert.

I'm not exactly a purist when it comes to CASE, but I try to avoid
it where it makes sense. Anyway, I've used it a few times in the
source (unforgiveable, you say! :-) where it was kind of handy.

Most of my words are short and sweet, but a few (namely the debugger
and error display, as well as Buffer -- the initialisation word) of
my words are "long and hairy". Again, I'm not a "short word Purist",
and I use long words where it would be silly to break them up, but
short words most of the time, trying to keep with good Forth style.

My personal Forth style is ever-changing. I don't like the difficulty
of inserting nice comments without breaking up your Forth flow. Forth
should be so well-written that it doesn't need comments and can just
be strung together, you say. I'm not from that school of thought
either. So whether you like my source or not, I don't think it's
ideal.
