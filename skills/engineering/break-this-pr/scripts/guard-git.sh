#!/bin/sh
# PreToolUse guard for break-this-pr. Reads the hook's JSON on stdin. While a review marker exists, it blocks
# every git command that isn't on a read-only allowlist (exit 2, reason on stderr). With no marker it allows
# everything (exit 0).
#
# It matches command text, so it is a guard rail against accidents and injected commands, not a security
# boundary: git reached through a variable (`$g reset`), `eval`, or a script or another language is not seen.
# Needs only sh, awk, find and git.

MAX_AGE_MINUTES=240
input=$(cat)

# Prints the first JSON string value for a key, unescaped. Exits 1 if the key isn't there.
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
      s = substr($0, RSTART + RLENGTH); out = ""
      for (i = 1; i <= length(s); i++) {
        c = substr(s, i, 1)
        if (c == "\"") { printf "%s", out; exit 0 }
        if (c != "\\") { out = out c; continue }
        i++; e = substr(s, i, 1)
        if (e == "n") out = out "\n"
        else if (e == "t") out = out "\t"
        else if (e == "r" || e == "b" || e == "f") out = out " "
        else if (e == "u") {
          v = hexval(substr(s, i + 1, 4)); i += 4
          out = out ((v >= 32 && v < 127) ? sprintf("%c", v) : (v == 10 ? "\n" : " "))
        }
        else out = out e
      }
      exit 1
    }'
}

cwd=$(json_string cwd) || cwd=$PWD
marker=
for dir in "${CLAUDE_PROJECT_DIR:-}" "$cwd" "$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null)"; do
  [ -n "$dir" ] || continue
  if [ -n "$(find "$dir/.claude/review/.active" -mmin -"$MAX_AGE_MINUTES" 2>/dev/null)" ]; then
    marker="$dir/.claude/review/.active"
    break
  fi
done
[ -n "$marker" ] || exit 0

block() {
  echo "break-this-pr: $1. A review is running, so only read-only git is allowed (status, diff, log, show," \
    "archive, fetch into FETCH_HEAD or refs/remotes/, and list forms). Rephrase the command, or if no review is" \
    "running, delete $marker" >&2
  exit 2
}

command_text=$(json_string command) || block "couldn't read the command from the hook input"

verdict=$(printf '%s' "$command_text" | awk '
  BEGIN { RS = "\001" }

  # A redirection target (`> file`) is dropped, so the word after it is still seen as the command.
  function flush_token() {
    if (in_token) { if (redirect) redirect = 0; else { ntok++; tok[ntok] = cur } }
    cur = ""; in_token = 0
  }
  function end_segment() { flush_token(); redirect = 0; check_segment(); ntok = 0 }
  # Past the cap, a command that mentions git is blocked rather than left partly unchecked.
  function queue_nested(s) {
    if (nq < 200) { nq++; queue[nq] = s }
    else if (mentions_git) deny("blocked: too many quoted strings to check")
  }

  # Splits a command line into segments of tokens, queueing the inside of quoted strings to be checked as
  # commands too (`sh -c "git reset"`).
  function scan(s,   i, c, n, q) {
    ntok = 0; cur = ""; in_token = 0; n = length(s)
    for (i = 1; i <= n; i++) {
      c = substr(s, i, 1)
      if (c == "\\") {
        i++
        if (substr(s, i, 1) != "\n") { cur = cur substr(s, i, 1); in_token = 1 }  # backslash-newline joins lines
        continue
      }
      if (c == "\047") {
        q = ""
        for (i++; i <= n && substr(s, i, 1) != "\047"; i++) q = q substr(s, i, 1)
        cur = cur q; in_token = 1; queue_nested(q); continue
      }
      if (c == "\"") {
        q = ""
        for (i++; i <= n && substr(s, i, 1) != "\""; i++) {
          if (substr(s, i, 1) == "\\" && i < n) i++
          q = q substr(s, i, 1)
        }
        cur = cur q; in_token = 1; queue_nested(q); continue
      }
      if (c == " " || c == "\t") { flush_token(); continue }
      if (c == "<" || c == ">") {
        if (cur ~ /^[0-9]+$/) { cur = ""; in_token = 0 }  # the fd number in 2>
        flush_token()
        while (index("<>&|", substr(s, i + 1, 1))) i++  # >>, >&, <&, >|, <<
        redirect = 1; continue
      }
      if (c == ";" || c == "&" || c == "|" || c == "(" || c == ")" || c == "`" || c == "\n") {
        end_segment(); continue
      }
      if (c == "$" && substr(s, i + 1, 1) == "(") { end_segment(); i++; continue }
      cur = cur c; in_token = 1
    }
    end_segment()
  }

  # The command name, lowercased because macOS runs `GIT` as git.
  function name(t,   n) { n = split(t, parts, "/"); return tolower(parts[n]) }
  function is_assignment(t) { return t ~ /^[A-Za-z_][A-Za-z0-9_]*=/ }

  # Finds git in command position: the first word after assignments and keywords, or after find -exec. When the
  # first word is a wrapper, its flags may take arguments (xargs -n 1, nice -n 10), so the first git after it counts.
  function check_segment(   i, start, xargs) {
    start = 1
    while (start <= ntok) {
      xargs = 0
      for (i = start; i <= ntok && (is_assignment(tok[i]) || tok[i] ~ /^(then|do|else|elif|if|while|until|!|\{)$/); i++);
      if (i <= ntok && has("command exec nohup time nice sudo doas xargs env timeout stdbuf noglob nocorrect", name(tok[i]))) {
        for (; i <= ntok && name(tok[i]) != "git"; i++) if (name(tok[i]) == "xargs") xargs = 1
      }
      if (i <= ntok && name(tok[i]) == "git") check_git(i + 1, xargs)
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
    # --output (and archive -o) makes a read-only command write any file, including .git/HEAD, refs and config.
    for (j = i + 1; j <= ntok; j++) {
      if (tok[j] ~ /^--output(=|$)/ || (subcmd == "archive" && tok[j] ~ /^-[^-]*o/)) { deny("blocked `git " subcmd " " tok[j] "`: it writes a file"); return }
    }
    if (has("status diff diff-tree diff-index diff-files log show shortlog whatchanged rev-parse rev-list merge-base ls-files ls-tree ls-remote cat-file blame annotate grep describe name-rev for-each-ref show-ref cherry range-diff check-ignore check-attr count-objects var version help archive", subcmd)) return
    a = (i < ntok) ? tok[i + 1] : ""
    if (subcmd == "stash" && has("list show", a)) return
    if (subcmd == "worktree" && a == "list") return
    if (subcmd == "notes" && has("list show", a)) return
    if (subcmd == "submodule" && has("status summary", a)) return
    if (subcmd == "sparse-checkout" && a == "list") return
    if (subcmd == "remote" && (a == "" || has("-v --verbose show get-url", a))) return
    if (subcmd == "symbolic-ref") {
      nonflag = 0
      for (j = i + 1; j <= ntok; j++) {
        if (tok[j] !~ /^-/) nonflag++
        else if (!has("-q --quiet --short", tok[j])) { deny("blocked `git symbolic-ref " tok[j] "`: it may change refs"); return }
      }
      if (nonflag > 1) deny("blocked `git symbolic-ref` with a target: it would move a ref")
      return
    }
    if (subcmd == "reflog" && !has("expire delete drop", a)) return
    # The read action must come first, after scope flags. Git refuses a second action, so a write later fails.
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
        if (has("-l --list --contains --no-contains --merged --no-merged --points-at", t)) { listish = 1; continue }
        if (has("-a --all -r --remotes -v -vv --verbose --show-current -i --ignore-case --no-column --no-color --no-abbrev --verify", t)) continue
        if (t ~ /^--(sort|format|column|color|abbrev|contains|no-contains|merged|no-merged|points-at)=/ || t ~ /^-n[0-9]*$/) { listish = 1; continue }
        deny("blocked `git " subcmd " " t "`: it may change refs"); return
      }
      if (nonflag && !listish) deny("blocked `git " subcmd " " tok[i + 1] "`: it would create a " subcmd)
      return
    }
    if (subcmd == "fetch") {
      nonflag = 0
      for (j = i + 1; j <= ntok; j++) {
        t = tok[j]
        if (has("-f --force -u --update-head-ok", t) || t ~ /^--(refmap|upload-pack)/) { deny("blocked `git fetch " t "`: it can overwrite local refs"); return }
        if (t ~ /^-/) continue
        nonflag++
        if (nonflag == 1) continue
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
