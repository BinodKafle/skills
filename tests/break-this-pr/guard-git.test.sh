#!/bin/sh
# Tests guard-git.sh and its plugin hook. Exits 1 on any failure.
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

# Runs "$@" in its own process group, killed after 5 s (exit 124), so a hang fails the case. macOS has no `timeout`.
with_timeout() {
  perl -e '$p = fork; if (!$p) { setpgrp(0, 0); exec @ARGV } $SIG{ALRM} = sub { kill "KILL", -$p; exit 124 };
    alarm 5; waitpid($p, 0); exit($? & 127 ? 128 + ($? & 127) : $? >> 8)' "$@"  # a signal death is not exit 0
}

# Runs the guard (or $GUARD_CMD) on a Bash tool call: run_hook <cwd> <command> -> exit code.
run_hook() {
  printf '{"session_id":"t","cwd":%s,"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":%s,"description":"d"}}' \
    "$(json_quote "$1")" "$(json_quote "$2")" | with_timeout sh -c "${GUARD_CMD:-sh \"$GUARD\"}" >/dev/null 2>&1
  echo $?
}

expect() { # expect <label> <wanted> <got>
  if [ "$2" = "$3" ]; then passes=$((passes + 1)); else failures=$((failures + 1)); echo "FAIL $1: wanted $2, got $3"; fi
}

project="$WORK/project"
mkdir -p "$project/sub/dir" "$project/.claude/review"
git -C "$project" init -q
export CLAUDE_PROJECT_DIR="$project"

# 1. Table cases, marker active.
touch "$project/.claude/review/.active"
tab=$(printf '\t')
while IFS="$tab" read -r wanted command; do
  case "$wanted" in ''|'#'*) continue ;; esac
  expect "$command" "$wanted" "$(run_hook "$project" "$command")"
done < "$HERE/guard-cases.tsv"

# Cases the table can't hold: multi-line, or many quoted strings.
nl='
'
expect "line continuation" 2 "$(run_hook "$project" "git fetch origin && \\${nl}  git reset --hard")"
expect "indented continuation" 2 "$(run_hook "$project" "git status && \\${nl}    git stash")"
expect "git split by a line join" 2 "$(run_hook "$project" "gi\\${nl}t stash")"
expect "line join inside double quotes" 2 "$(run_hook "$project" "\"gi\\${nl}t\" stash")"
expect "continuation, read-only" 0 "$(run_hook "$project" "git log \\${nl}  --oneline")"
many=$(awk 'BEGIN { for (i = 0; i < 250; i++) printf "\047\047 " }')
expect "many quotes, then git" 2 "$(run_hook "$project" ": $many; sh -c 'git reset --hard'")"
expect "many quotes, no git" 0 "$(run_hook "$project" "printf %s $many")"
# Parsing took about 47 s for 1.6 MB on macOS, past the hook's 10 s timeout, so commands over 50 KB are blocked.
blob=$(awk 'BEGIN { for (i = 0; i < 80000; i++) printf "aaaaaaaaaa" }')
expect "large quoted string, then git" 2 "$(run_hook "$project" "printf %s '$blob' \"$blob\" > f && git reset --hard")"
expect "over 50 KB, read-only git" 2 "$(run_hook "$project" "printf %s '$blob' > f && git log")"
blob=$(awk 'BEGIN { for (i = 0; i < 2400; i++) printf "aaaaaaaaaa" }')
expect "just under 50 KB, read-only git" 0 "$(run_hook "$project" "printf %s '$blob' \"$blob\" > f && git log")"

# Raw hook input with JSON escapes json_quote never writes.
raw() { printf '{"cwd":"%s","tool_input":{"command":"%s"}}' "$project" "$1" | with_timeout sh "$GUARD" >/dev/null 2>&1; echo $?; }
expect "\\u0067 for g" 2 "$(raw '\u0067it reset --hard')"
expect "\\u000a newline" 2 "$(raw 'git status\u000agit stash')"
expect "\\u0026 ampersands" 2 "$(raw 'git log \u0026\u0026 git stash')"
expect "\\r\\n line ending" 2 "$(raw 'git status\r\ngit stash')"
expect "escaped quotes, read-only" 0 "$(raw 'git log --format=\"%H\"')"

# 2. Marker lookup and expiry.
expect "subfolder cwd, CLAUDE_PROJECT_DIR unset" 2 "$(unset CLAUDE_PROJECT_DIR; run_hook "$project/sub/dir" 'git reset --hard')"
expect "CLAUDE_PROJECT_DIR elsewhere, cwd in repo" 2 "$(CLAUDE_PROJECT_DIR="$WORK" run_hook "$project/sub" 'git reset --hard')"
expect "CLAUDE_PROJECT_DIR in a subfolder, cwd outside" 2 "$(CLAUDE_PROJECT_DIR="$project/sub" run_hook "$WORK" 'git -C project reset --hard')"
git -C "$WORK" init -q submodule && git -C "$WORK/submodule" commit -q --allow-empty -m s
git -C "$project" -c protocol.file.allow=always submodule -q add "$WORK/submodule" mod 2>/dev/null
expect "cwd in a submodule" 2 "$(unset CLAUDE_PROJECT_DIR; run_hook "$project/mod" 'git reset --hard')"
expect "unreadable hook input blocks" 2 "$(cd "$WORK" && printf 'not json' | with_timeout sh "$GUARD" >/dev/null 2>&1; echo $?)"
# The marker names the reviewing session (run_hook sends session_id "t"); other sessions keep their git.
echo t > "$project/.claude/review/.active"
expect "marker names this session" 2 "$(run_hook "$project" 'git reset --hard')"
echo other > "$project/.claude/review/.active"
expect "marker names another session" 0 "$(run_hook "$project" 'git reset --hard')"
expect "another session's marker, worktree below it" 0 "$(run_hook "$project/sub/dir" 'git stash')"
: > "$project/.claude/review/.active"
touch -t 202001010000 "$project/.claude/review/.active"
expect "stale marker" 0 "$(run_hook "$project" 'git reset --hard')"
rm "$project/.claude/review/.active"
expect "no marker" 0 "$(run_hook "$project" 'git reset --hard')"
expect "no marker, unreadable input" 0 "$(cd "$WORK" && printf 'not json' | with_timeout sh "$GUARD" >/dev/null 2>&1; echo $?)"

# 3. The plugin hook: it matches Monitor too (it runs shell commands), and runs the guard.
grep -q '"matcher": "Bash|Monitor"' "$REPO/hooks/hooks.json" || { echo "FAIL: hooks.json matcher isn't Bash|Monitor"; failures=$((failures + 1)); }
plugin_hook=$(sed -n 's/^ *"command": "\(.*\)",*$/\1/p' "$REPO/hooks/hooks.json" | sed 's/\\"/"/g')
[ -n "$plugin_hook" ] || { echo "FAIL: no hook command found in hooks/hooks.json"; failures=$((failures + 1)); }
touch "$project/.claude/review/.active"
expect "plugin hook, blocked" 2 "$(CLAUDE_PLUGIN_ROOT="$REPO" GUARD_CMD="$plugin_hook" run_hook "$project" 'git reset --hard')"
expect "plugin hook, allowed" 0 "$(CLAUDE_PLUGIN_ROOT="$REPO" GUARD_CMD="$plugin_hook" run_hook "$project" 'git log')"

echo "$passes passed, $failures failed"
[ "$failures" -eq 0 ]
