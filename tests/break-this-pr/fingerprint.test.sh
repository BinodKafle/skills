#!/bin/sh
# Tests fingerprint.sh: same state gives the same output, and each kind of change shows up. Exits 1 on any failure.
set -u

HERE=$(cd "$(dirname "$0")" && pwd)
FP="$HERE/../../skills/engineering/break-this-pr/scripts/fingerprint.sh"
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
failures=0

repo="$WORK/repo"
git init -q "$repo" && git -C "$repo" commit -q --allow-empty -m init
echo a > "$repo/tracked" && git -C "$repo" add tracked && git -C "$repo" commit -q -m tracked
echo u > "$repo/untracked"

# changes <label> <command>: the command must change the fingerprint.
changes() {
  before=$(sh "$FP" "$repo")
  (cd "$repo" && eval "$2")
  [ "$before" != "$(sh "$FP" "$repo")" ] || { failures=$((failures + 1)); echo "FAIL $1: fingerprint unchanged"; }
}

[ "$(sh "$FP" "$repo")" = "$(sh "$FP" "$repo")" ] || { failures=$((failures + 1)); echo "FAIL: not stable"; }
changes "untracked file contents" 'echo v > untracked'
changes "tracked edit" 'echo b > tracked'
changes "staged" 'git add tracked'
changes "stash" 'git stash -q'
changes "new branch" 'git branch other'
changes "switch branch" 'git switch -q other'
changes "local config" 'git config --local x.y z'
changes "new untracked file" 'touch new'

echo "fingerprint: $failures failed"
[ "$failures" -eq 0 ]
