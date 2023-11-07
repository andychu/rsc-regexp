Ideas
=====

- Port whole NFA thing to Python
  - re -> postfix
  - postfix -> nfa
  - multi-state simulator
- Make sure it passes the same tests

- Add enough for our favorite regex `"([^"\]|\\.)`
  - negated char class
  - escape `\\`
  - dot

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
  - For yaks lexer, we need either
    - semantic actions, I guess attached to the final state?
    - submatches, which we use in yaks/lex.ts

- Compare SIZE of state machine, for derivatives, and Dragon book DFA ->
  optimized DFA
  - I think the RSC articles never give the full DFA approach.

- Advanced: compile UTF-8 into the DFA
  - A tree of ranges?




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
  - arguably no worse than TypeScript, which has benefits

- It's taking me awhile to understand the algorithm
  - last graph algorithm I worked with was our garbage collector, which was
    also fun, but more "trivial" algorithmically

- patch() function is longer - still need to understand this




