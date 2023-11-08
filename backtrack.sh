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
  echo "text $text"
  time $impl-match "$pat" "$text"

  # Perl doesn't backtrack here
  echo
  echo "text ${text}z"
  time $impl-match "${pat}$" "${text}z"

  # nodejs still backtracks here!
  echo
  echo 'Fail without backtracking'
  local nomatch="${text::-1}"
  #echo nomatch=$nomatch

  echo "text ${nomatch}"
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
# Hm this case is too short to reproduce the slowness?

compare-cloudflare-short() {
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

# Deleted ' since it shouldn't matter
readonly CF='(?:(?:\"|\]|\}|\\|\d|(?:nan|infinity|true|false|null|undefined|symbol|math)|\`|\-|\+)+[)]*;?((?:\s|-|~|!|{}|\|\||\+)*.*(?:.*=.*)))'

# Turn (?:) into () since it doesn't matter
CF2='((\"|\]|\}|\\|\d|(nan|infinity|true|false|null|undefined|symbol|math)|\`|\-|\+)+[)]*;?((\s|-|~|!|{}|\|\||\+)*.*(.*=.*)))'

compare-cloudflare() {
  local impl=${1:-py}
  local n=${2:-25}

  local text
  text="false x=$(repeat 'x' $n)"
  #text="$(repeat 'x' $n)"

  compare $impl "$CF2" "$text"
}

install-pcregrep() {
  # try this on Debian
  sudo apt-get install pcregrep 
}

# It's pcregrep 8.39, from 2016, so it seems like it should have the bug.
#
# Hm not able to reproduce, on the matching text.
#
# But maybe they used an even older version.

CF3='.*.*=.*;'

try-pcregrep() {
  local n=${1:-25}

  #local grep=grep
  local grep=pcregrep

  time for i in $(seq 100); do
    local text
    text="false x=$(repeat 'x' $n)"
    #text="x=$(repeat 'x' $n)"
    echo "$text" 
  done | $grep "$CF" #| wc -l

  # Hm can't get it with either $CF or $CF2
}

# https://stackstatus.tumblr.com/post/147710624694/outage-postmortem-july-20-2016
#
# Not able to reproduce this -- I don't think they gave enough info on their
# implementations.

# Both mentioned here, but no repros
# https://levelup.gitconnected.com/the-regular-expression-denial-of-service-redos-cheat-sheet-a78d0ed7d865

SO_PAT='^[\s\u200c]+|[\s\u200c]+$'
SO_PAT2='\s+$'

compare-stack-overflow() {
  local impl=${1:-py}
  local n=${2:-25}

  local text
  text="$(repeat ' ' $n)z"
  #text="$(repeat 'x' $n)"

  compare $impl "$SO_PAT2" "$text"

}

compare-all() {
  #compare-py

  #for impl in pynfa py nodejs perl; do
  for impl in py nodejs perl; do
    #compare-syn-1 $impl
    #compare-csv $impl 25
    #compare-cloudflare $impl 500 # 500

    # needed 20,000 whitespace chars?
    compare-stack-overflow $impl 20000 # 500
    echo
    echo
  done
}


"$@"
