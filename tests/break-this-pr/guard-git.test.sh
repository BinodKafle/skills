#!/bin/sh
# Tests for skills/engineering/break-this-pr/scripts/guard-git.sh and the SKILL.md hook that launches it.
# Usage: sh tests/break-this-pr/guard-git.test.sh   (exits 1 on any failure)
set -u

HERE=$(cd "$(dirname "$0")" && pwd)
REPO=$(cd "$HERE/../.." && pwd)
SKILL="$REPO/skills/engineering/break-this-pr"
GUARD="$SKILL/scripts/guard-git.sh"
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
failures=0
passes=0

# A JSON string literal for $1.
json_quote() {
  printf '%s' "$1" | awk 'BEGIN { RS = "\001"; ORS = "" } {
    gsub(/\\/, "\\\\"); gsub(/"/, "\\\""); gsub(/\t/, "\\t"); gsub(/\n/, "\\n"); print "\"" $0 "\"" }'
}

# Runs the guard (or $GUARD_CMD) on a Bash tool call: run_hook <cwd> <command> -> exit code.
run_hook() {
  printf '{"session_id":"t","cwd":%s,"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":%s,"description":"d"}}' \
    "$(json_quote "$1")" "$(json_quote "$2")" | sh -c "${GUARD_CMD:-sh \"$GUARD\"}" >/dev/null 2>&1
  echo $?
}

expect() { # expect <label> <wanted> <got>
  if [ "$2" = "$3" ]; then passes=$((passes + 1)); else failures=$((failures + 1)); echo "FAIL $1: wanted $2, got $3"; fi
}

project="$WORK/project"
mkdir -p "$project/sub/dir" "$project/.claude/review"
git -C "$project" init -q
export CLAUDE_PROJECT_DIR="$project"

# 1. Every case in the table, with an active marker.
touch "$project/.claude/review/.active"
tab=$(printf '\t')
while IFS="$tab" read -r wanted command; do
  case "$wanted" in ''|'#'*) continue ;; esac
  expect "$command" "$wanted" "$(run_hook "$project" "$command")"
done < "$HERE/guard-cases.tsv"

# Commands the table can't hold: several lines, or many quoted strings.
nl='
'
expect "line continuation" 2 "$(run_hook "$project" "git fetch origin && \\${nl}  git reset --hard")"
expect "indented continuation" 2 "$(run_hook "$project" "git status && \\${nl}    git stash")"
expect "continuation, read-only" 0 "$(run_hook "$project" "git log \\${nl}  --oneline")"
many=$(awk 'BEGIN { for (i = 0; i < 250; i++) printf "\047\047 " }')
expect "many quotes, then git" 2 "$(run_hook "$project" ": $many; sh -c 'git reset --hard'")"
expect "many quotes, no git" 0 "$(run_hook "$project" "printf %s $many")"

# 2. The marker decides whether the guard is on.
expect "subfolder cwd, CLAUDE_PROJECT_DIR unset" 2 "$(unset CLAUDE_PROJECT_DIR; run_hook "$project/sub/dir" 'git reset --hard')"
expect "CLAUDE_PROJECT_DIR elsewhere, cwd in repo" 2 "$(CLAUDE_PROJECT_DIR="$WORK" run_hook "$project/sub" 'git reset --hard')"
expect "unreadable hook input blocks" 2 "$(printf 'not json' | sh "$GUARD" >/dev/null 2>&1; echo $?)"
touch -t 202001010000 "$project/.claude/review/.active"
expect "stale marker" 0 "$(run_hook "$project" 'git reset --hard')"
rm "$project/.claude/review/.active"
expect "no marker" 0 "$(run_hook "$project" 'git reset --hard')"
expect "no marker, unreadable input" 0 "$(printf 'not json' | sh "$GUARD" >/dev/null 2>&1; echo $?)"

# 3. The launcher in SKILL.md finds the script in both install layouts.
launcher=$(sed -n 's/^ *command: "\(.*\)"$/\1/p' "$SKILL/SKILL.md" | sed 's/\\"/"/g')
[ -n "$launcher" ] || { echo "FAIL: no hook command found in SKILL.md"; failures=$((failures + 1)); }
touch "$project/.claude/review/.active"
for root in "$REPO" "$SKILL"; do # plugin root, and a skill copied into ~/.claude/skills
  expect "launcher, root $root, blocked" 2 "$(CLAUDE_PLUGIN_ROOT="$root" GUARD_CMD="$launcher" run_hook "$project" 'git reset --hard')"
  expect "launcher, root $root, allowed" 0 "$(CLAUDE_PLUGIN_ROOT="$root" GUARD_CMD="$launcher" run_hook "$project" 'git log')"
done
expect "launcher, script missing, marker active" 2 "$(CLAUDE_PLUGIN_ROOT="$WORK" GUARD_CMD="$launcher" run_hook "$project" 'git log')"
rm "$project/.claude/review/.active"
expect "launcher, script missing, no marker" 0 "$(CLAUDE_PLUGIN_ROOT="$WORK" GUARD_CMD="$launcher" run_hook "$project" 'git log')"

echo "$passes passed, $failures failed"
[ "$failures" -eq 0 ]
