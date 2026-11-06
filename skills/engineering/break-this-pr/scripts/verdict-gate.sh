#!/bin/sh
# Computes the verdict from a review ledger, so a skipped gate can't be argued past.
# Usage: verdict-gate.sh <ledger.md> <current head SHA>
# Prints the verdict, then one line per reason. Exit 0 MERGE, 1 NOT YET, 2 DO NOT MERGE, 64 usage.
[ $# -eq 2 ] && [ -r "$1" ] || { echo "usage: verdict-gate.sh <ledger.md> <current head SHA>" >&2; exit 64; }

# \| inside a cell is an escaped pipe, not a column break.
sed 's/\\|/<PIPE>/g' "$1" | awk -v head="$2" '
function trim(s) { gsub(/^[ \t]+|[ \t]+$/, "", s); return s }
function low(s) { return tolower(trim(s)) }
function reason(r) { reasons = reasons "\n- " r }
# Tables whose every row must be filled; an n/a cell is fine, an empty one is not.
function filled(s) { return s == "Rounds" || s == "Dimensions" || s == "Assumption ledger" || s == "Readers" ||
  s == "Parameters and channels" || s == "Messages and side effects" || s == "Differences by class" ||
  s == "Verdict inputs" }
BEGIN {
  ngates = split("Findings|D1 complete|Every corpus current|Previous-head differential mapped|" \
    "D10 finding verifier|D10 blind adversary|No open decisions|Time box", gates, "|")
  # Only these can not apply: no corpus, a first round, no findings, a depth below Deep.
  split("Every corpus current|Previous-head differential mapped|D10 finding verifier|D10 blind adversary", na, "|")
  for (i in na) may_skip[na[i]] = 1
}
/^## / { section = trim(substr($0, 4)); row = 0; next }
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
  if (section == "Dimensions") {
    s = low(c[3])
    if (s != "pass" && s != "finding" && s != "n/a") reason("Dimensions: " label " is \"" trim(c[3]) "\"")
  }
  if (section == "Verdict inputs") {
    seen[label] = 1
    s = low(c[3])
    if (label == "Findings" && s == "fail") blocked = 1
    else if (s != "pass" && !(s == "n/a" && label in may_skip)) reason("gate " label " is \"" trim(c[3]) "\"")
  }
}
END {
  for (i = 1; i <= ngates; i++) if (!(gates[i] in seen)) reason("Verdict inputs: gate \"" gates[i] "\" is missing")
  split("Rounds|Dimensions|Assumption ledger|Readers|Parameters and channels|Messages and side effects|" \
    "Differences by class", need, "|")
  for (i in need) if (!rows[need[i]]) reason(need[i] ": no rows (write one n/a row with the reason)")
  # Either SHA may be abbreviated; they match when one starts with the other and both have 7+ characters.
  h = tolower(head); l = tolower(ledger_head)
  if (length(l) < 7 || length(h) < 7 || (index(h, l) != 1 && index(l, h) != 1))
    reason("ledger head \"" ledger_head "\" is not the current head " head)
  if (blocked) { print "DO NOT MERGE"; print "- gate Findings is fail" reasons; exit 2 }
  if (reasons != "") { print "NOT YET" reasons; exit 1 }
  print "MERGE"; exit 0
}'
