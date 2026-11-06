#!/bin/sh
# Computes the verdict from a review ledger, so a skipped gate can't be argued past.
# Usage: verdict-gate.sh <ledger.md> <current head SHA>
# Prints the verdict, then one line per reason. Exit 0 MERGE, 1 NOT YET, 2 DO NOT MERGE, 64 usage.
[ $# -eq 2 ] && [ -r "$1" ] || { echo "usage: verdict-gate.sh <ledger.md> <current head SHA>" >&2; exit 64; }

# \| inside a cell is an escaped pipe, not a column break.
sed 's/\\|/<PIPE>/g' "$1" | awk -v head="$2" '
# Markdown emphasis and code marks around a value are ignored.
function trim(s) { gsub(/^[ \t`*]+|[ \t`*\r]+$/, "", s); return s }
function low(s) { return tolower(trim(s)) }
function reason(r) { reasons = reasons "\n- " r }
# Tables whose every row must be filled; an n/a cell is fine, an empty one is not.
function filled(s) { return s == "Rounds" || s == "Dimensions" || s == "Intent ledger" ||
  s == "Assumption ledger" || s == "Readers" || s == "Parameters and channels" ||
  s == "Messages and side effects" || s == "Differences by class" || s == "Verdict inputs" }
BEGIN {
  ngates = split("Findings|D1 complete|Every corpus current|Previous-head differential mapped|" \
    "D10 finding verifier|D10 blind adversary|No open decisions|Time box|No verdict cap", gates, "|")
  # Only these can not apply: no corpus, a first round, no findings, a depth below Deep.
  split("Every corpus current|Previous-head differential mapped|D10 finding verifier|D10 blind adversary", na, "|")
  for (i in na) may_skip[na[i]] = 1
}
/^## / { section = trim(substr($0, 4)); row = 0; next }
# A finding line: open blockers, and open majors introduced by the change, block whatever the gate says.
section == "Findings" && / · / {
  f = tolower($0)
  if (f ~ /fixed@|rejected|stale/) next
  if (f ~ / · blocker · / || (f ~ / · major · / && f ~ / · introduced/)) {
    blocked = 1; reason("open finding: " trim($0))
  }
  next
}
!/^[|]/ { next }
{
  row++
  n = split($0, c, "|") - 2              # cells are c[2] .. c[n+1]
  if (row == 1) { cols = n; next }
  if ($0 ~ /^[|][ :|-]+$/) { row = 1; next }   # separator row
  rows[section]++
  label = trim(c[2])
  if (filled(section)) {
    if (n != cols) reason(section ": row \"" label "\" has " n " cells, the header has " cols)
    for (i = 2; i <= n + 1; i++) if (trim(c[i]) == "") { reason(section ": row \"" label "\" has an empty cell"); break }
  }
  if (section == "Scope" && low(c[2]) == "head sha") ledger_head = trim(c[3])
  if (section == "Scope" && low(c[2]) ~ /^depth/) depth = low(c[3])
  if (section == "Dimensions") {
    s = low(c[3])
    if (match(label, /^D[0-9]+/)) dim[substr(label, 2, RLENGTH - 1)] = s
    if (s != "pass" && s != "finding" && s != "n/a") reason("Dimensions: " label " is \"" trim(c[3]) "\"")
  }
  if (section == "Intent ledger") {
    s = low(c[n + 1])
    if (s == "partial" || s == "not done") reason("Intent ledger: row \"" label "\" is " s)
  }
  if (section == "Verdict inputs") {
    seen[label] = 1
    s = low(c[3])
    if (label == "Findings" && s == "fail") { blocked = 1; reason("gate Findings is fail") }
    else if (s != "pass" && !(s == "n/a" && label in may_skip)) reason("gate " label " is \"" trim(c[3]) "\"")
    if (label == "D10 blind adversary" && s == "n/a" && depth ~ /^deep/) reason("gate D10 blind adversary is n/a at Deep")
  }
}
END {
  for (i = 1; i <= ngates; i++) if (!(gates[i] in seen)) reason("Verdict inputs: gate \"" gates[i] "\" is missing")
  split("Rounds|Dimensions|Intent ledger|Assumption ledger|Readers|Parameters and channels|" \
    "Messages and side effects|Differences by class", need, "|")
  for (i in need) if (!rows[need[i]]) reason(need[i] ": no rows (write one n/a row with the reason)")
  for (d = 0; d <= 10; d++) {
    if (!(d in dim)) reason("Dimensions: D" d " is missing")
    # Only Light depth skips these; at any other depth they always apply.
    else if (dim[d] == "n/a" && (d <= 2 || d >= 9) && depth !~ /^light/) reason("Dimensions: D" d " can only be n/a at Light depth")
  }
  # Either SHA may be abbreviated; they match when one starts with the other and both have 7+ characters.
  h = tolower(head); l = tolower(ledger_head)
  if (length(l) < 7 || length(h) < 7 || (index(h, l) != 1 && index(l, h) != 1))
    reason("ledger head \"" ledger_head "\" is not the current head " head)
  if (blocked) { print "DO NOT MERGE" reasons; exit 2 }
  if (reasons != "") { print "NOT YET" reasons; exit 1 }
  print "MERGE"; exit 0
}'
