#!/usr/bin/env bash
#
# Usage:
#   ./run.sh <function name>

set -o nounset
set -o pipefail
set -o errexit

### Tools

make-venv() {
  local dir=_tmp/venv
  mkdir -p $dir
  python3 -m venv $dir
}

install() {
  . _tmp/venv/bin/activate
  pip3 install mypy yapf
}

check() {
  . _tmp/venv/bin/activate

  mypy py/nfa.py
}

format() {
  . _tmp/venv/bin/activate

  yapf -i py/nfa.py
}


### Tests

parse() {
  py/nfa.py parse 'a|b'
}

readonly -a CASES=(
  'ab'
  'a+b'
  'ab*'
  'a|b'
  '((ab)?c)'
  '.*'
  '..'

  # syntax error
  '|a'
  'a|b|'
  '+'
)

re2post() {
  for pat in "${CASES[@]}"; do
    echo "$pat"
    py/nfa.py re2post "$pat"
    echo
  done
}

post2nfa() {
  for pat in "${CASES[@]}"; do
    echo "$pat"
    py/nfa.py post2nfa "$pat"
    echo
  done
}

match-case() {
  echo "  $1  $2"
  py/nfa.py match "$@"
  echo
}

test-dot() {
  match-case '.' ''
  match-case '.' x
  match-case '.' y
  match-case '.*' xyz
  match-case 'xx.*zz' xxzz
  match-case 'xx.*xz' xyyyz
  match-case 'xx.*zz' xxyyyzz
}

test-infinite-repeat() {

  # Thompson pointed out this bug in the appendix of the 1968 paper.

  # Python / Perl / nodejs disallow some of them, but not all.  They're
  # inconsistent.

  # I think Darius mentioned it in one of his code snippets.

  # These are all bugs
  #match-case 'a**' $(repeat a 30)
  #match-case 'a*+' $(repeat a 30)
  #match-case 'a?*' $(repeat a 30)
  match-case 'a?+' aaa

  # Not a bug
  #match-case 'a*?' $(repeat a 30)
}

test-backslash() {
  match-case '\\' '\'
  match-case '\\' 'z'

  match-case '\\+' '\\\'
  match-case '\\+' ''

  match-case '\\+' '\\\'
  match-case '\\+' ''

  match-case '\.' '.'
  match-case '\.' 'a'
  match-case '\.' '\'
}

test-char-class() {
  match-case '[\"]' 'a'
  match-case '[\"]' '\'
  match-case '[\"]' '"'

  # Special rule
  match-case '[]"]' ']'
  match-case '[]a]' 'a'
  match-case '[]a]' 'z'

  match-case 'a[\"]' 'a\'
  match-case 'a[\"]' 'a"'
}

test-or() {
  # C-style / JSON-style string literal
  local pat='"(ab|cd)*"'

  match-case "$pat" '"ab"'
  match-case "$pat" '"cd"'
  match-case "$pat" '"abcd"'

  # No
  match-case "$pat" '"abc"'

  match-case "$pat" '""'

}

test-favorite() {
  # C-style / JSON-style string literal
  # Oh we need negation
  local fav='"([^"\]|\\.)*"'

  match-case "$fav" 'no'
  match-case "$fav" '"no'

  match-case "$fav" '"yes"'
}

test-matches() {
  match-case 'a' a
  match-case 'a|b' a
  match-case 'a|b' b
  match-case 'a|b' c

  match-case 'ab' a
  match-case 'ab' ab
  match-case 'ab' abc

  match-case 'a*' ''
  match-case 'a*' a
  match-case 'a*' aa

  match-case 'a+' ''
  match-case 'a+' a
  match-case 'a+' aa

  match-case 'a?' ''
  match-case 'a?' a
  match-case 'a?' aa

  match-case 'a(b|c)d' abcd
  match-case 'a(b|c)d' abd
  match-case 'a(b|c)d' acd
  match-case 'a(b|c)d' ad

  match-case 'a(b|c)*d' abbd
  match-case 'a(b|c)*d' accd
  match-case 'a(b|c)*d' acbcbbccd
  match-case 'a(b|c)*d' ad
  match-case 'a(b|c)*d' a
  match-case 'a(b|c)*d' dad

  match-case 'a(b|c)*d' dad

  return

  for pat in "${CASES[@]}"; do
    echo "$pat"
    py/nfa.py match "$pat" a
    echo
  done
}

orig-tests() {
  . ~/.cargo/env

  # Hack for clang

  local clang_bin
  clang_bin=$(echo $PWD/../oil_DEPS/clang*/bin)

  export PATH=$PATH:$clang_bin
  echo PATH=$PATH

  clang --version
  #return

  ./test all
  echo

  ./torture-test original/nfa
}

### git stuff

test-py() {
  ./test py/nfa.py match
}

log-staging() {
  ### log: for working with the merge bot
  git log master..
}

diff-staging() {
  ### diff: for working with the merge bot
  git diff master..
}

rebase-staging() {
  git rebase -i master
}

merge-to-staging() {
  local do_push=${1:-T}  # pass F to disable

  local branch=$(git rev-parse --abbrev-ref HEAD)

  if test "$do_push" = T; then
    git checkout master &&
    git merge $branch &&
    git push andychu &&
    git checkout $branch
  else
    git checkout master &&
    git merge $branch &&
    git checkout $branch
  fi
}

"$@"
