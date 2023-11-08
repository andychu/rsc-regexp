#!/usr/bin/env bash
#
# Usage:
#   ./backtrack.sh <function name>

set -o nounset
set -o pipefail
set -o errexit


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

  echo "   IMPL = $impl   pat = $pat"

  echo
  echo "text=$text"
  time $impl-match "$pat" "$text"

  # Perl doesn't backtrack here
  echo
  echo "text=${text}z"
  time $impl-match "${pat}$" "${text}z"

  # nodejs still backtracks here!
  echo
  echo 'Fail without backtracking'
  local nomatch="${text::-1}"
  #echo nomatch=$nomatch

  echo "text=${nomatch}"
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

compare-syn-3() {
  local impl=${1:-py}
  local n=${2:-25}

  # Thompson mentioned this

  # - Python doesn't allow multiple repeat
  # - ditto node.js
  # - ditto Perl.  OK let's do this
  local pat='a**'

  # Weirdly, this is allowed by SOME engines!
  #local pat='a*+'
  #local pat='a+*'

  local text
  text=$(repeat a $n)

  compare $impl "$pat" "$text"
}

compare-csv() {
  local impl=${1:-py}

  # Python starts failing here only around n=30, for one case only
  local n=${2:-10}

  # Thompson mentioned this
  #

  # Not able to repro?

  # https://www.regular-expressions.info/catastrophic.html
  local pat
  pat="$(repeat '.*,' $n)P"
  echo pat=$pat

  local text
  text=$(repeat hello, $n)P
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

  for impl in pynfa py nodejs perl; do
    #compare-syn-1 $impl
    compare-csv $impl 25
  done
}


"$@"
