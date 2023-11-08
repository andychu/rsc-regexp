Ideas
=====

- Fix infinite loop bug in Python
  - is it due to lastlist?

- convert postfix to prefix?
  - so we can try derivatives code?

  - alternative:
    - parse to variadic prefix
      - (++ a b c)
      - (| (++ a b))
      - this is easier to read and write, and is the style we can use with Yaks

    - convert variadic prefix to binary postfix

- Port that to tiny code from Darius, which also uses prefix
  - Is it exponential time?  The derivatives approach
  - Also needs char class, dot, etc.  Maybe try first with `"(a|b)+"`

- How to do linear time derivatives approach?
  - Look at smart constructors / hash consing
  - Does that make all the difference in the SAME algorithm?

- How to build a full DFA like re2c?
  - with any optimization?

- Compare SIZE of state machine, for derivatives, and Dragon book DFA ->
  optimized DFA
  - I think the RSC articles never give the full DFA approach.

- Advanced: compile UTF-8 into the DFA
  - A tree of ranges?

Semantic Actions
----------------

- For yaks lexer, we need either
  - semantic actions, I guess attached to the final state?
  - submatches, which we use in yaks/lex.ts
    - nfa-perl.y is 639 lines?  Looks significantly different
      - has LeftmostBiased and LeftmostLongest
	  - RepeatMinimal, RepeatLikePerl
      - it adds the idea of "Thread" I think?

- QUESTION: are submatches and semantic actions the same thing?
  - I don't think so, because submatches are more general
  - re2c just has TOP-LEVEL alternation

  - The 1994 re2c paper says 
    "In the longer term, in-line actions will be added to re2c"
    Example: decoding integers
    But Figure 13 already has semantic actions, with if statements and printf
    error messages?

  - it has it
    re2c-0.9.1/code.cc line 575 prints the actions

Backtracking: this isn't linear time!  Because you do an unanchored match over
and over again.  You can test this out with re2c.

    "a" { *tok = A }
    "b" { *tok = B }
    .* Z { *tok = Z }

Notes
-----

- dataclass can print cyclic graphs!  Like

```
Literal(c=97, out=Split(out1=..., out2=Literal(c=98, out=Match())))
```

- patch() function is longer - still need to understand this
  - seemed to just work

- reminds me of Pratt parsing -- transcribing code, and fixing bugs is the
  easiest way to "feel" the algorithm
