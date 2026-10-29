#!/bin/sh
# Tests fingerprint.sh: same state gives the same output, and each kind of change shows up. Exits 1 on any failure.
set -u

HERE=$(cd "$(dirname "$0")" && pwd)
FP="$HERE/../../skills/engineering/break-this-pr/scripts/fingerprint.sh"
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
failures=0
# CI runners have no git identity, so commits would fail.
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t

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

# names <label> <path> <command>: the command must change a line ending in <path>, so the change is attributed.
names() {
  before=$(sh "$FP" "$repo")
  (cd "$repo" && eval "$3")
  sh "$FP" "$repo" | grep -vxF "$before" | grep -q -- " $2\$" || { failures=$((failures + 1)); echo "FAIL $1: no changed line names $2"; }
}

echo n > "$repo/notes.txt"; echo n > "$repo/café.txt"; echo n > "$repo/-dash.txt"; echo c > "$repo/tracked"
names "untracked edit" notes.txt 'echo m > notes.txt'
names "non-ASCII name" café.txt 'echo m > café.txt'
names "leading dash" -dash.txt 'echo m > ./-dash.txt'
names "second edit to a modified tracked file" tracked 'echo d > tracked'

# A symlink to /dev/zero must not hang it. The timeout kills the whole group, so no cksum is left reading.
ln -s /dev/zero "$repo/zero"
if perl -e '$p = fork; if (!$p) { setpgrp(0, 0); exec @ARGV } $SIG{ALRM} = sub { kill "KILL", -$p; exit 124 };
    alarm 10; waitpid($p, 0); exit($? >> 8)' sh "$FP" "$repo" >/dev/null 2>&1; then
  names "retargeted symlink" zero 'ln -sf /dev/null zero'
else
  failures=$((failures + 1)); echo "FAIL symlink to /dev/zero: fingerprint didn't finish in 10 s"
fi

echo "fingerprint: $failures failed"
[ "$failures" -eq 0 ]
