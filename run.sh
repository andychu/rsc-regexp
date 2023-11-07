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

match() {
  py/nfa.py match a a
  py/nfa.py match 'a|b' a
  py/nfa.py match 'a|b' b

  return

  for pat in "${CASES[@]}"; do
    echo "$pat"
    py/nfa.py match "$pat" a
    echo
  done
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
