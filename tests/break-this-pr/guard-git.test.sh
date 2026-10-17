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
unset GUARD_CMD
failures=0
passes=0

# A JSON string literal for $1.
json_quote() {
  printf '%s' "$1" | awk 'BEGIN { RS = "\001"; ORS = "" } {
    gsub(/\\/, "\\\\"); gsub(/"/, "\\\""); gsub(/\t/, "\\t"); gsub(/\n/, "\\n"); print "\"" $0 "\"" }
    END { if (NR == 0) print "\"\"" }'
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

# JSON escapes json_quote never writes, sent as raw hook input.
raw() { printf '{"cwd":"%s","tool_input":{"command":"%s"}}' "$project" "$1" | sh "$GUARD" >/dev/null 2>&1; echo $?; }
expect "\\u0067 for g" 2 "$(raw '\u0067it reset --hard')"
expect "\\u000a newline" 2 "$(raw 'git status\u000agit stash')"
expect "\\u0026 ampersands" 2 "$(raw 'git log \u0026\u0026 git stash')"
expect "\\r\\n line ending" 2 "$(raw 'git status\r\ngit stash')"
expect "escaped quotes, read-only" 0 "$(raw 'git log --format=\"%H\"')"

# 2. The marker decides whether the guard is on.
expect "subfolder cwd, CLAUDE_PROJECT_DIR unset" 2 "$(unset CLAUDE_PROJECT_DIR; run_hook "$project/sub/dir" 'git reset --hard')"
expect "CLAUDE_PROJECT_DIR elsewhere, cwd in repo" 2 "$(CLAUDE_PROJECT_DIR="$WORK" run_hook "$project/sub" 'git reset --hard')"
expect "CLAUDE_PROJECT_DIR in a subfolder, cwd outside" 2 "$(CLAUDE_PROJECT_DIR="$project/sub" run_hook "$WORK" 'git -C project reset --hard')"
git -C "$WORK" init -q submodule && git -C "$WORK/submodule" commit -q --allow-empty -m s
git -C "$project" -c protocol.file.allow=always submodule -q add "$WORK/submodule" mod 2>/dev/null
expect "cwd in a submodule" 2 "$(unset CLAUDE_PROJECT_DIR; run_hook "$project/mod" 'git reset --hard')"
expect "unreadable hook input blocks" 2 "$(cd "$WORK" && printf 'not json' | sh "$GUARD" >/dev/null 2>&1; echo $?)"
touch -t 202001010000 "$project/.claude/review/.active"
expect "stale marker" 0 "$(run_hook "$project" 'git reset --hard')"
rm "$project/.claude/review/.active"
expect "no marker" 0 "$(run_hook "$project" 'git reset --hard')"
expect "no marker, unreadable input" 0 "$(cd "$WORK" && printf 'not json' | sh "$GUARD" >/dev/null 2>&1; echo $?)"

# 3. The launcher in SKILL.md finds the script in both install layouts.
launcher=$(sed -n 's/^ *command: "\(.*\)"$/\1/p' "$SKILL/SKILL.md" | sed 's/\\"/"/g')
[ -n "$launcher" ] || { echo "FAIL: no hook command found in SKILL.md"; failures=$((failures + 1)); }
touch "$project/.claude/review/.active"
for root in "$REPO" "$SKILL"; do # plugin root, and a skill copied into ~/.claude/skills
  expect "launcher, root $root, blocked" 2 "$(CLAUDE_PLUGIN_ROOT="$root" GUARD_CMD="$launcher" run_hook "$project" 'git reset --hard')"
  expect "launcher, root $root, allowed" 0 "$(CLAUDE_PLUGIN_ROOT="$root" GUARD_CMD="$launcher" run_hook "$project" 'git log')"
done
expect "launcher, script missing, marker active" 2 "$(CLAUDE_PLUGIN_ROOT="$WORK" GUARD_CMD="$launcher" run_hook "$project" 'git log')"
expect "launcher, script missing, not git" 0 "$(CLAUDE_PLUGIN_ROOT="$WORK" GUARD_CMD="$launcher" run_hook "$project" 'ls')"
expect "launcher, script missing, project subfolder" 2 "$(CLAUDE_PROJECT_DIR="$project/sub" CLAUDE_PLUGIN_ROOT="$WORK" GUARD_CMD="$launcher" run_hook "$project/sub" 'git log')"
mkdir -p "$WORK/flat/skills" && cp -R "$SKILL" "$WORK/flat/skills/break-this-pr"
expect "launcher, flat plugin layout" 0 "$(CLAUDE_PLUGIN_ROOT="$WORK/flat" GUARD_CMD="$launcher" run_hook "$project" 'git log')"
rm "$project/.claude/review/.active"
expect "launcher, script missing, no marker" 0 "$(CLAUDE_PLUGIN_ROOT="$WORK" GUARD_CMD="$launcher" run_hook "$project" 'git log')"

echo "$passes passed, $failures failed"
[ "$failures" -eq 0 ]
