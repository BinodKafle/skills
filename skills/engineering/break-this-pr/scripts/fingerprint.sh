#!/bin/sh
# Prints the git state of a repo, so break-this-pr can show it changed nothing: run at D0 and before the report,
# then compare. Read-only. Tags are left out because a plain fetch can add them.
# Usage: fingerprint.sh <repo root>
cd "${1:?usage: fingerprint.sh <repo root>}" || exit 1

echo "head: $(git rev-parse HEAD)"
echo "branch: $(git symbolic-ref -q HEAD || echo detached)"
echo "branches: $(git for-each-ref refs/heads | cksum)"
echo "stashes: $(git stash list | wc -l | tr -d ' ')"
echo "worktrees: $(git worktree list | cksum)"
echo "config: $(git config --local --list | cksum)"
echo "staged: $(git diff --cached | cksum)"
echo "tracked: $(git diff HEAD | cksum)"
# status lists untracked names only, so hash their contents too.
echo "untracked contents: $(git ls-files -o --exclude-standard | while IFS= read -r f; do cksum "$f"; done | cksum)"
echo "status:"
git status --porcelain -uall
