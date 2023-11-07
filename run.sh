#!/usr/bin/env bash
#
# Usage:
#   ./run.sh <function name>

set -o nounset
set -o pipefail
set -o errexit

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


parse() {
  py/nfa.py parse 'a|b'
}

# TODO: reuse existing test cases
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

match() {

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
