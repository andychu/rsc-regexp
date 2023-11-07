Ideas
=====

- Port whole NFA thing to Python
  - re -> postfix
  - postfix -> nfa
  - multi-state simulator
- Make sure it passes the same tests

- Add enough for our favorite regex `"([^"\]|\\.)`
- Parser
  - `[]` and `[^]` - negated char class
    - later: need `a-z` for Yaks lex.ts
  - escape `\\`
  - dot
- re2post is the same
- simulator needs to handle CharClass and Dot

- This might be natural in a PREFIX notation, not postfix (which is fine in
  Python)

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


- re2post easier to port Rust -> Python, than C -> Python
- algebraic data types for State are also better in Rust
  - After years of using Zephyr ASDL, it definitely feels "missing" in Python.
    dataclass/Union is awkard.
    - Although dataclass also has pretty-printing, which is nice.
  - However I still think Union (TypeScript, MyPy, ~ASDL) is better than sum
    types / enum.  It doesn't quite come up here, other than Byte() being a
    part of `op` and `class_item` (not in the original)

- dataclass can print cyclic graphs!  Like

```
Literal(c=97, out=Split(out1=..., out2=Literal(c=98, out=Match())))
```

- Python has clearly morphed in to an ML (in ad hoc way)
  - static types are useful -- helped me port it
  - arguably no worse than TypeScript, which has benefits

- It's taking me awhile to understand the algorithm
  - last graph algorithm I worked with was our garbage collector, which was
    also fun, but more "trivial" algorithmically

- patch() function is longer - still need to understand this
  - seemed to just work

- reminds me of Pratt parsing -- transcribing code, and fixing bugs is the
  easiest way to "feel" the algorithm

