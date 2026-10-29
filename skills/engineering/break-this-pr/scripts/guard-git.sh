#!/bin/sh
# PreToolUse hook: while a fresh review marker exists, blocks git not on the read-only allowlist (exit 2).
# Matches command text only, so git via a variable, `eval` or a script slips through: a guard rail, not a boundary.

MAX_AGE_MINUTES=240
input=$(cat)

# Prints the first JSON string value for key $1, unescaped. Exits 1 if the key is missing.
json_string() {
  printf '%s' "$input" | awk -v key="$1" '
    function hexval(h,   i, c, v) {
      v = 0
      for (i = 1; i <= length(h); i++) {
        c = index("0123456789abcdef", tolower(substr(h, i, 1)))
        if (c == 0) return -1
        v = v * 16 + c - 1
      }
      return v
    }
    BEGIN { RS = "\001" }
    {
      if (!match($0, "\"" key "\"[ \t\r\n]*:[ \t\r\n]*\"")) exit 1
      # Print as we go (string building is slow); on exit 1 the caller discards the output.
      n = split(substr($0, RSTART + RLENGTH), ch, "")
      for (i = 1; i <= n; i++) {
        c = ch[i]
        if (c == "\"") exit 0
        if (c == "\\") {
          i++; c = ch[i]
          if (c == "n") c = "\n"
          else if (c == "t") c = "\t"
          else if (c == "r" || c == "b" || c == "f") c = " "
          else if (c == "u") {
            v = hexval(ch[i + 1] ch[i + 2] ch[i + 3] ch[i + 4]); i += 4
            c = (v >= 32 && v < 127) ? sprintf("%c", v) : (v == 10 ? "\n" : " ")
          }
        }
        printf "%s", c
      }
      exit 1
    }'
}

cwd=$(json_string cwd) || cwd=$PWD

# The marker is at the repo (or superproject) root, so walk up from the project dir and cwd.
marker=
for dir in "${CLAUDE_PROJECT_DIR:-}" "$cwd"; do
  while [ -n "$dir" ] && [ -z "$marker" ]; do
    if [ -e "$dir/.claude/review/.active" ] && [ -n "$(find "$dir/.claude/review/.active" -mmin -"$MAX_AGE_MINUTES" 2>/dev/null)" ]; then
      marker="$dir/.claude/review/.active"
    fi
    dir=${dir%/*}
  done
done
[ -n "$marker" ] || exit 0

block() {
  echo "break-this-pr: $1. A review is running; only read-only git is allowed (status, diff, log, show, blame, grep," \
    "rev-parse, archive, fetch into FETCH_HEAD or refs/remotes/, list forms; full list in guard-git.sh)." \
    "Rephrase, or if no review is running, delete $marker" >&2
  exit 2
}

command_text=$(json_string command) || block "couldn't read the command from the hook input"

# No git once quotes, backslashes and line breaks are gone (they can split the word: g\it, "g"it): nothing to check.
printf '%s' "$command_text" | tr -d '\\"\047\n' | grep -qi git || exit 0

verdict=$(printf '%s' "$command_text" | awk '
  BEGIN { RS = "\001" }

  # Drop redirection targets so the next word is still the command.
  function flush_token() {
    if (in_token) { if (redirect) redirect = 0; else { ntok++; tok[ntok] = cur } }
    cur = ""; in_token = 0
  }
  function end_segment() { flush_token(); redirect = 0; check_segment(); ntok = 0 }
  # Past the cap, block anything mentioning git.
  function queue_nested(s) {
    if (nq < 200) { nq++; queue[nq] = s }
    else if (mentions_git) deny("blocked: too many quoted strings to check")
  }

  # Splits into token segments; quoted strings are queued as commands too (`sh -c "git reset"`).
  function scan(s,   i, c, n, q, ch) {
    ntok = 0; cur = ""; in_token = 0; n = split(s, ch, "")
    for (i = 1; i <= n; i++) {
      c = ch[i]
      if (c == "\\") {
        i++
        if (ch[i] != "\n") { cur = cur ch[i]; in_token = 1 }  # backslash-newline joins lines
        continue
      }
      if (c == "\047") {
        q = ""
        for (i++; i <= n && ch[i] != "\047"; i++) q = q ch[i]
        cur = cur q; in_token = 1; queue_nested(q); continue
      }
      if (c == "\"") {
        q = ""
        for (i++; i <= n && ch[i] != "\""; i++) {
          if (ch[i] == "\\" && i < n) i++
          q = q ch[i]
        }
        cur = cur q; in_token = 1; queue_nested(q); continue
      }
      if (c == " " || c == "\t") { flush_token(); continue }
      if (c == "<" || c == ">") {
        if (cur ~ /^[0-9]+$/) { cur = ""; in_token = 0 }  # the fd number in 2>
        flush_token()
        # i < n: macOS awk finds "" at index 1, so a trailing > looped forever.
        while (i < n && index("<>&|", ch[i + 1])) i++  # >>, >&, <&, >|, <<
        redirect = 1; continue
      }
      if (c == ";" || c == "&" || c == "|" || c == "(" || c == ")" || c == "`" || c == "\n") {
        end_segment(); continue
      }
      if (c == "$" && ch[i + 1] == "(") { end_segment(); i++; continue }
      cur = cur c; in_token = 1
    }
    end_segment()
  }

  # The command name, lowercased because macOS runs `GIT` as git.
  function name(t,   n) { n = split(t, parts, "/"); return tolower(parts[n]) }
  function is_assignment(t) { return t ~ /^[A-Za-z_][A-Za-z0-9_]*=/ }
  # Like `-c`, GIT_* variables can set config or run commands (GIT_CONFIG_COUNT, GIT_SSH_COMMAND, GIT_DIR).
  function check_git_env(from, to,   j) {
    for (j = from; j <= to; j++) {
      if (tok[j] ~ /^GIT_[A-Za-z0-9_]*=/ && !has("GIT_PAGER=cat GIT_TERMINAL_PROMPT=0 GIT_OPTIONAL_LOCKS=0", tok[j])) {
        deny("blocked `" substr(tok[j], 1, index(tok[j], "=")) "`: git environment variables can change config or run commands")
      }
    }
  }

  # Finds git in command position, after assignments, keywords, find -exec, or a wrapper (xargs -n 1 git).
  function check_segment(   i, start, xargs) {
    start = 1
    while (start <= ntok) {
      xargs = 0
      for (i = start; i <= ntok && (is_assignment(tok[i]) || tok[i] ~ /^(then|do|else|elif|if|while|until|!|\{)$/); i++);
      if (i <= ntok && has("command exec nohup time nice sudo doas xargs env timeout stdbuf noglob nocorrect", name(tok[i]))) {
        for (; i <= ntok && name(tok[i]) != "git"; i++) if (name(tok[i]) == "xargs") xargs = 1
      }
      if (i <= ntok && name(tok[i]) == "git") { check_git_env(start, i - 1); check_git(i + 1, xargs) }
      if (i <= ntok && name(tok[i]) == "export") check_git_env(i + 1, ntok)
      for (start = i + 1; start <= ntok && tok[start - 1] !~ /^-(exec|execdir|ok|okdir)$/; start++);
    }
  }

  function deny(why) { if (verdict == "") verdict = why }
  function has(set, t) { return index(" " set " ", " " t " ") > 0 }

  function check_git(i, xargs,   subcmd, j, a, nonflag, listish, dst) {
    while (i <= ntok && tok[i] ~ /^-/) {
      t = tok[i]
      if (t == "-C" || t == "--git-dir" || t == "--work-tree" || t == "--namespace") { i += 2; continue }
      if (t ~ /^--(git-dir|work-tree|namespace)=/) { i++; continue }
      if (has("-p --paginate -P --no-pager --bare --no-replace-objects --literal-pathspecs --glob-pathspecs --noglob-pathspecs --icase-pathspecs --no-optional-locks --no-advice --version --help -v -h", t)) { i++; continue }
      if (t == "-c" || t ~ /^--(config-env|exec-path)/) { deny("blocked `git " t "`: config overrides can run commands or change what git does"); return }
      deny("blocked `git " t "`: unknown git option"); return
    }
    if (i > ntok) { if (xargs) deny("blocked `xargs git`: the subcommand would come from input"); return }
    subcmd = tok[i]
    # --output and archive -o write arbitrary files.
    for (j = i + 1; j <= ntok; j++) {
      if (tok[j] ~ /^--output(=|$)/ || (subcmd == "archive" && tok[j] ~ /^-[^-]*o/)) { deny("blocked `git " subcmd " " tok[j] "`: it writes a file"); return }
      # These name a program for git to run.
      if (tok[j] ~ /^--(upload-pack|exec|open-files-in-pager)(=|$)/ || (subcmd == "grep" && tok[j] ~ /^-[^-]*O/) ||
          (subcmd == "ls-remote" && tok[j] ~ /^-[^-]*u/)) { deny("blocked `git " subcmd " " tok[j] "`: it runs a program"); return }
    }
    if (has("status diff diff-tree diff-index diff-files log show shortlog whatchanged rev-parse rev-list merge-base ls-files ls-tree ls-remote cat-file blame annotate grep describe name-rev for-each-ref show-ref cherry range-diff check-ignore check-attr count-objects var version help archive", subcmd)) return
    a = (i < ntok) ? tok[i + 1] : ""
    if (subcmd == "stash" && has("list show", a)) return
    if (subcmd == "worktree" && a == "list") return
    if (subcmd == "notes" && has("list show", a)) return
    if (subcmd == "submodule" && has("status summary", a)) return
    if (subcmd == "sparse-checkout" && a == "list") return
    if (subcmd == "remote") {
      for (j = i + 1; j <= ntok && has("-v --verbose", tok[j]); j++);
      if (j > ntok || has("show get-url", tok[j])) return
      deny("blocked `git remote " tok[j] "`: it may change remotes"); return
    }
    if (subcmd == "symbolic-ref") {
      nonflag = 0
      for (j = i + 1; j <= ntok; j++) {
        if (tok[j] !~ /^-/) nonflag++
        else if (!has("-q --quiet --short", tok[j])) { deny("blocked `git symbolic-ref " tok[j] "`: it may change refs"); return }
      }
      if (nonflag > 1) deny("blocked `git symbolic-ref` with a target: it would move a ref")
      return
    }
    # A leading flag means `reflog show <flag>`.
    if (subcmd == "reflog" && (a == "" || a ~ /^-/ || has("show list exists", a))) return
    # The read action must come first; git rejects a second action.
    if (subcmd == "config") {
      for (j = i + 1; j <= ntok && (has("--global --system --local --worktree --show-origin --show-scope --null -z --name-only --includes --no-includes", tok[j]) || tok[j] ~ /^--type=/); j++);
      if (j <= ntok && has("--get --get-all --get-regexp --get-urlmatch --list -l get list", tok[j])) return
      deny("blocked `git config`: only a read (--get, --list, get, list) is allowed, and it must come first"); return
    }
    if (subcmd == "branch" || subcmd == "tag") {
      nonflag = 0; listish = 0
      for (j = i + 1; j <= ntok; j++) {
        t = tok[j]
        if (t !~ /^-/) { nonflag++; continue }
        # Only these mean list mode; with a name, display flags still create a ref.
        if (has("-l --list --contains --no-contains --merged --no-merged --points-at", t) || t ~ /^--(contains|no-contains|merged|no-merged|points-at)=/ ||
            (subcmd == "tag" && (t ~ /^-n[0-9]*$/ || has("-v --verify", t)))) { listish = 1; continue }
        if (has("-a --all -r --remotes -v -vv --verbose --show-current -i --ignore-case --column --no-column --no-color --no-abbrev", t) ||
            t ~ /^--(sort|format|column|color|abbrev)=/) continue
        deny("blocked `git " subcmd " " t "`: it may change refs"); return
      }
      if (nonflag && !listish) deny("blocked `git " subcmd " " tok[i + 1] "`: it would create a " subcmd)
      return
    }
    if (subcmd == "fetch") {
      nonflag = 0
      for (j = i + 1; j <= ntok; j++) {
        t = tok[j]
        # Other flags can move refs (--refmap), delete tags (-P) or write config (--set-upstream).
        if (t ~ /^-/) {
          if (has("-q --quiet -v --verbose -n --no-tags -p --prune --all --dry-run --progress --no-progress --no-write-fetch-head --no-recurse-submodules", t)) continue
          deny("blocked `git fetch " t "`: not on the read-only flag list"); return
        }
        nonflag++
        if (nonflag == 1) continue
        if (t == "tag") { deny("blocked `git fetch <remote> tag`: it creates a local tag"); return }
        if (t ~ /^\+/) { deny("blocked `git fetch " t "`: a forced refspec overwrites refs"); return }
        if (index(t, ":")) {
          dst = substr(t, index(t, ":") + 1)
          if (dst !~ /^refs\/remotes\//) { deny("blocked `git fetch " t "`: fetch into refs/remotes/ or FETCH_HEAD only"); return }
        }
      }
      return
    }
    deny("blocked `git " subcmd (a == "" ? "" : " " a) "`: not on the read-only allowlist")
  }

  {
    nq = 1; queue[1] = $0; mentions_git = tolower($0) ~ /git/
    for (qi = 1; qi <= nq && verdict == ""; qi++) scan(queue[qi])
  }
  END { if (verdict != "") print verdict }
')

[ -z "$verdict" ] || block "$verdict"
exit 0
