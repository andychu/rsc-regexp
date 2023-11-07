Translation of NFA Compilation / Multi-State Simulation to Python
=====

Thanks to BurntSushi for nerd-sniping me:

- <https://github.com/BurntSushi/rsc-regexp>

## What I did

1. Copy `re2post()`, and massage it into Python.  It was actually easier to
   copy the Rust version than the C version, although I referred to both.
1. Figure out the skeleton of `post2nfa()`.  I then realized that using
   **typed** Python and "algebraic data types" would be easier.
   - For example, the C code uses `.` as the concat operator, but this leads to
     confusion with "any char".  So our postfix encoding has typed data, not
     just bytes.

I used Python 3 `dataclass` and `Union` type, statically checked by MyPy:

```python
@dataclass
class Byte:
    """ 0-255, so we can do Unicode later """
    c: int

@dataclass
class Cat:
    """ ab """
    pass

# ...

op = Union[Byte, Repeat, Alt, Cat, Dot]
```

It definitely **looks** ugly and verbose, compared to Zephyr ASDL, which we
use in Oils.  In ASDL, it's:

```ocaml
op =
  Byte(int c)     # translate escapes like \\ and \. to this
| Repeat(str op)  # + * ?
| Cat
| Alt
```

The sum type in the Rust code also helped a lot!  It matches the prose
explanation of the algorithm much more closely than the C codes does.

```rust
enum State {
    Literal { byte: u8, out: StateID },
    Split { out1: StateID, out2: StateID },
    Match,
}
```

3. Combine the NFA simulation into fewer function (see below).  It's simpler if
   you don't have to worry about efficiency or memory management.
   - The state "lists" are represented as a Python `Dict[int, State]`, because
     `set()` can only contain hashable values, and `dataclass` instances aren't
     hashable unless `frozen=True`.

The `py/nfa.py` file now **passes original tests**, except the `a.b` test,
which is intentional.  We're interpreting `.` in the traditional way (any
char).

## I Read the Rust Code

Even though 

- I regularly read C code for Oils, and first touched C over 25 years ago
- I don't really know Rust (I tried it once, and occasionally read blog posts
  with Rust code)

I found myself referring to the Rust code more!  The strong types help.

(I recently started a new `micro-syntax` program in C, but quickly upgraded it
to C++, for the same reason.)

---

I find that physically typing in algorithms is a good first pass toward
understanding them.

This is a fun algorithm.  I would say it's a little "meatier" than a tracing
GC, which is the another graph-based algorithm I've worked with recently.

### Ownership / Memory Management

This was the original motivation for the experiment.  But I don't really have
any comments now -- I was mainly trying to understand the algorithm first!

I would say that greater difference is between GC'd Python vs. C or Rust,
rather than C vs. Rust.

## Code Snippets

I'm copying the code here, before adding more features.

Python clarified the algorithm for me!  For the usual reason that it looks like
"executable pseudo-code".

### Python Morphed into ML Dialect (a bit like TypeScript)

These examples alsow show that Python has gradually turned into an ML dialect--
not just with `Union` types, but also `match case`!

These language features are recent -- `match case` is from Python 3.10 as of
October 2021, and MyPy support came even later.

(Related note below on Union vs. sum types.)

---

### post2fa

```python
def post2nfa(postfix: List[op]) -> Optional[State]:

    stack: List[Frag] = []

    for p in postfix:
        match p:
            case Cat():
                e2 = stack.pop()
                e1 = stack.pop()
                Patch(e1.out, e2.start)
                stack.append(Frag(e1.start, e2.out))

            case Alt():
                e2 = stack.pop()
                e1 = stack.pop()
                st = Split(e1.start, e2.start)
                e1.out.extend(e2.out)
                stack.append(Frag(st, e1.out))

            case Repeat(op):
                e = stack.pop()
                st = Split(e.start, None)

                if op == '?':
                    e.out.append(Out2(st))
                    stack.append(Frag(st, e.out))

                elif op == '*':
                    Patch(e.out, st)
                    out: List[ToPatch] = [Out2(st)]
                    stack.append(Frag(st, out))

                elif op == '+':
                    Patch(e.out, st)
                    out = [Out2(st)]
                    stack.append(Frag(e.start, out))

            case Byte(c):
                st_lit = Literal(c, None)
                out = [Out1(st_lit)]
                stack.append(Frag(st_lit, out))

            case _:
                raise RuntimeError('oops')

    e = stack.pop()
    if len(stack) != 0:
        return None

    st_match = Match()
    Patch(e.out, st_match)

    return e.start
```

### match


```python
def addstate(nlist: Dict[int, State], st: Optional[State]):
    if st is None:
        return

    match st:
        case Split(out1, out2):
            # follow unlabeled arrows
            addstate(nlist, out1)
            addstate(nlist, out2)
            return
    nlist[id(st)] = st


def match(start: State, s: str) -> bool:
    to_match = s.encode('utf-8')

    # dataclass instances aren't not hashable because they're mutable.  So use
    # object IDs
    clist: Dict[int, State] = {}
    nlist: Dict[int, State] = {}

    addstate(nlist, start)
    clist, nlist = nlist, clist

    for b in to_match:
        for st in clist.values():
            match st:
                case Literal(c, _):
                    if b == c:
                        addstate(nlist, st.out)

        clist, nlist = nlist, clist
        nlist.clear()

    for st in clist.values():
        match st:
            case Match():
                return True

    return False
```

## Related: Union types vs. Sum Types

The issue of union types vs. sum types doesn't really come up in this code.
Though it's starting to with `.` metacharacter support, and possibly char
classes `[^"\]`.

Here's a comment / "rant" about something I leared the hard way - Union types
in TypeScript / MyPy / Zephyr ASDL are more natural than sum types for
representing languages:

- <https://lobste.rs/s/tpe028/on_learning_compilers_creating#c_n8svhu> (on
  OCaml and the `Bool Int` smell)
- <https://lobste.rs/s/hkkcan/typescript_is_surprisingly_ok_for> - I tried
  TypeScript based on code snippets from `matklad` and I agree it's
  surprisingly OK.  MyPy is similarly OK!
  - They both feel cobbled together and ugly in spots, but they work, and have
    some advantages.

### Speed is Necessary

The main problem is that they're not fast enough:

- <https://news.ycombinator.com/item?id=35045520>

Which is another point for Rust.

As mentioned, I definitely prefer the Rust to C, especially to make this
production quality.  A C++ port would be interesting, but I actually want to
explore regex algorithms (DFAs, derivatives), more than the implementation
language.

I will probably do a few more experiments in Python, e.g. with

- <https://github.com/darius/regexercise_solutions/tree/master>

Which I mentioned back in 2020:

- <http://www.oilshell.org/blog/2020/07/ideas-questions.html#regular-expression-derivatives-papers-and-code>

(I forgot about all these links, and they were surprisingly helpful to me :) )






