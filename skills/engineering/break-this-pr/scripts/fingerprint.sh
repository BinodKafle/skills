#!/bin/sh
# Prints a repo's git state, read-only. Run at D0 and before the report; any difference needs explaining.
# Tags are left out because a plain fetch can add them. Usage: fingerprint.sh <repo root>
cd "${1:?usage: fingerprint.sh <repo root>}" || exit 1

echo "head: $(git rev-parse HEAD)"
echo "branch: $(git symbolic-ref -q HEAD || echo detached)"
echo "branches: $(git for-each-ref refs/heads | cksum)"
echo "stashes: $(git stash list | wc -l | tr -d ' ')"
echo "worktrees: $(git worktree list | cksum)"
echo "config: $(git config --local --list | cksum)"
echo "staged: $(git diff --cached | cksum)"
# One hash per path, so each change is tied to its file; -z and -- handle any file name.
echo "tracked:"
git diff -z --name-only HEAD | xargs -0 -r sh -c 'for f; do echo "$(git --literal-pathspecs diff HEAD -- "$f" | cksum) $f"; done' sh
# status lists untracked names only, so hash contents too; a symlink by its target, since reading one can hang.
echo "untracked contents:"
git ls-files -z -o --exclude-standard | xargs -0 -r sh -c 'for f; do [ ! -L "$f" ] || echo "symlink $(readlink "./$f") $f"; done' sh
git ls-files -z -o --exclude-standard | xargs -0 -r sh -c 'for f; do [ -L "$f" ] || printf "%s\0" "$f"; done' sh | xargs -0 -r cksum --
echo "status:"
git status --porcelain -uall
