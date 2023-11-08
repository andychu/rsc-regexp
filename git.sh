#!/usr/bin/env bash
#
# Usage:
#   ./git.sh <function name>

set -o nounset
set -o pipefail
set -o errexit

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
