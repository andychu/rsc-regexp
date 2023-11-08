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

### Benchmark

repeat() {
  local s=$1
  local n=$2

  for i in $(seq $n); do
    echo -n "$s"
  done
}

py-match() {
  local pat=$1
  local text=$2
  python3 -c 'import re, sys; print(re.match(sys.argv[1], sys.argv[2]))' "$pat" "$text"
}

pynfa-match() {
  py/nfa.py match "$@"
}

nodejs-match() {
  nodejs -e 'console.log(new RegExp(process.argv[1]).exec(process.argv[2]))' "$@"
}

perl-match() {
  perl -e '
use strict;
use warnings;
use Regexp::Common;

my ($pattern, $string) = @ARGV;

if ($string =~ /$pattern/) {
    print "Match found: $&\n";
} else {
    print "No match found\n";
}
' "$@"
}

compare() {
  local impl=${1:-py}
  local pat=$2
  local text=$3

  echo "   IMPL = $impl"

  echo
  echo 'Backtrack and succeed'
  time $impl-match "$pat" "$text"

  # Perl doesn't backtrack here
  echo
  echo 'Backtrack and fail'
  time $impl-match "${pat}$" "${text}z"

  # nodejs still backtracks here!
  echo
  echo 'Fail without backtracking'
  local nomatch="${text::-1}"
  #echo nomatch=$nomatch

  time $impl-match "$pat" "$nomatch"

  #time perl -e 'print "hi"';

  # 157 ms
  #time nodejs -e 'console.log("hi")';
}

# from blog-code/regular-languages
syn-pattern() {
  local n=$1

  # a?^n a^n
  repeat 'a?' $n
  repeat 'a' $n
  echo
}

compare-syn-1() {
  local impl=${1:-py}
  local n=${2:-25}

  local pat
  pat=$(syn-pattern $n)

  local text
  text=$(repeat a $n)

  compare $impl "$pat" "$text"
}

compare-syn-2() {
  local impl=${1:-py}
  # Python has problems at n=35
  local n=${2:-25}

  local pat='(a|aa)+'

  local text
  text="$(repeat 'a' $n)z"

  echo text=$text

  compare $impl "$pat" "$text"
}

# https://blog.cloudflare.com/details-of-the-cloudflare-outage-on-july-2-2019/
#
# Hm Python and node.js don't backtrack.  Maybe they optimized this case,
# fixing the bug?
#
# Let's see about Perl.

compare-cloudflare() {
  local impl=${1:-py}
  local n=${2:-25}

  local pat='.*(.*=.*)'

  # Does Python optimize this?
  #local pat='.*.*=.*'

  local text
  #text="$(repeat 'k' $n)=$(repeat 'x' $n)"

  text="x=$(repeat 'x' $n)"
  #text="$(repeat 'x' $n)"

  echo text=$text

  compare $impl "$pat" "$text"
}

compare-all() {
  #compare-py

  compare pynfa 
}

readonly regex='.*,.*,.*,.*'



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

test-double-star() {

  # Thompson pointed out this bug.
  # I think Darius mentioned it in one of his code snippets.

  match-case 'a**' $(repeat a 30)
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
