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




