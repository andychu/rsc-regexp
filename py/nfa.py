#!/usr/bin/env python3
"""
nfa.py
"""

import re
import sys

from dataclasses import dataclass
from typing import Optional, Dict, List, Set, Tuple, Union, Optional


def log(msg, *args):
    if args:
        msg = msg % args
    print(msg, file=sys.stderr)


# All this dataclass boilerplate pains me after using Zephyr ASDL, but let's
# keep it "stock".
"""
pat: string, but assert that code point is < 256

    " ([^\"] | \\ . ) "

Postfix operations:

    op =
      Byte(int c)  # escapes like \\ and \. are translated to this
    | Dot

    | Repeat(str op)  # + * ?
    | Cat
    | Alt

    | CharClass(bool negated, List[class_item] items)

    class_item = 
      Byte(int c)
    | Range(int start, int end)

TODO:
- UTF-8 can be compiled to an alternation of 1, 2, 3, or 4 CharClass
"""


@dataclass
class Byte:
    """ 0-255, so we can do Unicode later """
    c: int


@dataclass
class Dot:
    """ .* """
    pass


@dataclass
class Repeat:
    """ + * ? """
    s: str


@dataclass
class Alt:
    """ a|b """
    pass


@dataclass
class Cat:
    """ ab """
    pass


@dataclass
class CharClass:
    """ [^"\] """
    negated: bool
    items: List['class_item']


@dataclass
class Range:
    """ [a-z] 

    ByteRange or CharRange?
    """
    start: int
    end: int


class_item = Union[Byte, Range]

op = Union[Byte, Repeat, Alt, Cat, Dot, CharClass]


def ParseCharClass(pat: str, i: int) -> Tuple[op, int]:
    """Assuming we're looking at [, parse the char class, and advance i."""

    operation = CharClass(False, [])

    n = len(pat)
    i += 1
    first_index = i  # special case for []]

    chars = []
    while True:
        if i >= n:
            raise RuntimeError('Missing closing ]')

        ch = pat[i]

        if ch == '^':
            operation.negated = True
            i += 1
            continue

        # There are no \ escapes, because special chars can be put first
        #     [-ab]
        #     []ab]
        #
        # Or last:
        #     [z^]
        #
        # And singletons are always expressible without char classes.

        if ch == ']' and i != first_index:
            break

        chars.append(ch)
        i += 1

    if len(chars) == 0:
        # [^] would be empty
        raise RuntimeError('Empty char class not allowed')

    operation.items = [Byte(ord(ch)) for ch in chars]

    #log('CHAR %s', operation)
    return operation, i


def re2post(pat: str) -> Optional[List[op]]:

    # Bug fix from Rust translation
    if len(pat) == 0:
        return None

    nalt = 0  # number of |
    natom = 0  # number of atoms, used to insert explicit . conatenation

    paren: List[Tuple[int, int]] = []
    dst: List[op] = []

    i = 0
    n = len(pat)

    while i < n:
        ch = pat[i]
        #log('ch = %s', ch)

        if ch == '(':
            if natom > 1:
                natom -= 1
                dst.append(Cat())

            paren.append((nalt, natom))
            nalt = 0
            natom = 0

        elif ch == '|':
            if natom == 0:
                raise RuntimeError('Missing LHS to |')

            natom -= 1
            while natom > 0:
                dst.append(Cat())
                natom -= 1

            nalt += 1

        elif ch == ')':
            try:
                p = paren.pop()
            except IndexError:
                raise RuntimeError('Unbalanced )')

            if natom == 0:
                raise RuntimeError('Empty ()')

            natom -= 1

            while natom > 0:
                dst.append(Cat())
                natom -= 1

            while nalt > 0:
                dst.append(Alt())
                nalt -= 1

            nalt, natom = p
            natom += 1

        elif ch in ('*', '+', '?'):
            if natom == 0:
                raise RuntimeError('Nothing to repeat')
            dst.append(Repeat(ch))

        # Enhancement for "any byte" (was bug fix in Rust)
        elif ch == '.':
            if natom > 1:
                natom -= 1
                dst.append(Cat())

            dst.append(Dot())
            natom += 1

        elif ch == '[':
            if natom > 1:
                natom -= 1
                dst.append(Cat())

            operation, i = ParseCharClass(pat, i)
            dst.append(operation)
            natom += 1

        elif ch == '\\':
            if i == n - 1:
                raise RuntimeError('Expected char after \\')
            else:
                i += 1

            if natom > 1:
                natom -= 1
                dst.append(Cat())

            # This works for \\ \. etc.
            # TODO: \t \r \n
            ch = pat[i]
            dst.append(Byte(ord(ch)))
            natom += 1

        else:
            if natom > 1:
                natom -= 1
                dst.append(Cat())
            dst.append(Byte(ord(ch)))
            natom += 1

        i += 1

    #log('DONE')

    if len(paren) != 0:
        raise RuntimeError('Unclosed (')

    # Rust bug fix
    # The original program doesn't handle this case, which in turn
    # causes UB in post2nfa. It occurs when a pattern ends with a |.
    # Other cases like `a||b` and `(a|)` are rejected correctly above.
    if natom == 0 and nalt > 0:
        raise RuntimeError('The | operator is missing a RHS')

    natom -= 1
    while natom > 0:
        dst.append(Cat())
        natom -= 1

    while nalt > 0:
        dst.append(Alt())
        nalt -= 1

    return dst


### Second step

# Note: Set[State] is linked the linked list union Ptrlist


@dataclass
class Literal:
    c: int
    out: Optional['State']


@dataclass
class DotState:
    out: Optional['State']


@dataclass
class CharClassState:
    negated: bool
    items: List[class_item]
    out: Optional['State']


@dataclass
class Split:
    out1: 'State'
    out2: Optional['State']


@dataclass
class Match:
    pass


State = Union[Literal, DotState, CharClassState, Split, Match]


@dataclass
class Out1:
    st: State


@dataclass
class Out2:
    st: State


ToPatch = Union[Out1, Out2]


@dataclass
class Frag:
    """
    A partially built NFA without the matching state filled in.

    - Frag.start points at the start state.
    - Frag.out is a list of places that need to be set to the next state for
      this fragment.
    """
    start: State
    out: List[ToPatch]


def Patch(patches: List[ToPatch], st: State):
    for p in patches:
        match p:
            case Out1(to_patch):
                match to_patch:
                    case Literal(_, _):
                        to_patch.out = st
                    case DotState(_):
                        to_patch.out = st
                    case CharClassState(_, _):
                        to_patch.out = st
                    case Split(_, _):
                        to_patch.out1 = st
                    case _:
                        raise RuntimeError('Invalid patch 1')

            case Out2(to_patch):
                match to_patch:
                    case Split(_, _):
                        to_patch.out2 = st
                    case _:
                        raise RuntimeError('Invalid patch 2')


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

            case Dot():
                st_dot = DotState(None)
                out = [Out1(st_dot)]
                stack.append(Frag(st_dot, out))

            case CharClass(negated, items):
                st_char = CharClassState(negated, items, None)
                out = [Out1(st_char)]
                stack.append(Frag(st_char, out))

            case _:
                raise RuntimeError('oops')

    if 0:
        for item in stack:
            log('STACK %s', item)
        log('')

    e = stack.pop()
    if len(stack) != 0:
        raise RuntimeError('Stack should be empty: %s' % stack)

    st_match = Match()
    Patch(e.out, st_match)

    return e.start


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

    #log('CLIST 0 %s', clist)
    #log('NLIST 0 %s', nlist)

    for b in to_match:
        #print(b)
        for st in clist.values():
            #print('st %s' % st)
            match st:
                case Literal(c, _):
                    #log('b %d c %d', b , c)
                    if b == c:
                        addstate(nlist, st.out)

                case DotState(_):
                    addstate(nlist, st.out)

                case CharClassState(negated, items, _):
                    #log('b %d items %s', b , items)
                    matched = False
                    for item in items:
                        match item:
                            case Byte(c):
                                if b == c:
                                    matched = True
                    if negated:
                        matched = not matched
                    if matched:
                        addstate(nlist, st.out)

        clist, nlist = nlist, clist
        nlist.clear()
        #log('CLIST 1 %s', clist)

    for st in clist.values():
        match st:
            case Match():
                return True

    return False


def main(argv):

    action = argv[1]
    pat = argv[2]  # str instance

    if action == 'parse':
        # deprecated modules
        import sre_compile
        import sre_parse
        p = sre_compile.compile(pat)
        print(p)

        re_tree = sre_parse.parse(pat)
        print(re_tree)

    elif action == 're2post':
        p = re2post(pat)
        print(p)
        #print(''.join(p))

    elif action == 'post2nfa':
        p = re2post(pat)
        if p is None:
            raise RuntimeError('Syntax error')

        nfa = post2nfa(p)
        if nfa is None:
            raise RuntimeError('Error in post2nfa')

        print(nfa)

    elif action == 'match':
        p = re2post(pat)
        if p is None:
            print('bad regexp')  # for ./test harness
            raise RuntimeError('Syntax error in %r' % pat)

        DEBUG = False
        #DEBUG = True
        if DEBUG:
            log('POST %s', p)

        nfa = post2nfa(p)
        if nfa is None:
            raise RuntimeError('Error in post2nfa')

        # Exponential blowup in printing?
        if DEBUG:
            print(nfa)

        # Print the string if it matches, like the original
        s = argv[3]
        if 1:
            print('Matching %r' % s)

        if match(nfa, s):
            print(s)
        else:
            print('NOPE')
            pass

    else:
        raise RuntimeError('Invalid action %r' % action)


if __name__ == '__main__':
    try:
        main(sys.argv)
    except RuntimeError as e:
        print('FATAL: %s' % e, file=sys.stderr)
        sys.exit(1)
