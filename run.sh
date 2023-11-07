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

readonly -a CASES=(
  'ab'
  'a+b'
  'ab*'
  'a|b'
  '((ab)?c)'
  '.*'
  '..'
)

# TODO: reuse existing test cases
re2post() {
  for pat in "${CASES[@]}"; do
    py/nfa.py re2post "$pat"
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
