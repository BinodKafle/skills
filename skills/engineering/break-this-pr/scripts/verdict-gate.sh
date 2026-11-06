#!/bin/sh
# Computes the verdict from a review ledger, so a skipped gate can't be argued past.
# Usage: verdict-gate.sh <ledger.md> <current head SHA>
# Prints the verdict, then one line per reason. Exit 0 MERGE, 1 NOT YET, 2 DO NOT MERGE, 64 usage.
# The required dimensions and gates, and when each may be n/a, are read from templates/ledger.md, so they're
# defined once and a review can't loosen them by editing its own copy.
tpl="$(dirname "$0")/../templates/ledger.md"
[ $# -eq 2 ] && [ -r "$1" ] && [ -r "$tpl" ] || { echo "usage: verdict-gate.sh <ledger.md> <current head SHA>" >&2; exit 64; }

# \| inside a cell is an escaped pipe, not a column break. The template is read first, then the ledger.
sed 's/\\|/<PIPE>/g' "$1" | awk -v head="$2" '
# Markdown emphasis and code marks around a value are ignored.
function trim(s) { gsub(/^[ \t`*]+|[ \t`*\r]+$/, "", s); return s }
function low(s) { return tolower(trim(s)) }
function reason(r) { reasons = reasons "\n- " r }
# The cell under a header, by the header text before any "(...)".
function cell(name) { return (name in col) ? c[col[name]] : "" }
# Either SHA may be abbreviated: 7+ characters, and one starts with the other.
function same_sha(a, b) { a = tolower(a); b = tolower(b)
  return length(a) >= 7 && length(b) >= 7 && (index(a, b) == 1 || index(b, a) == 1) }
# An "n/a allowed" rule: yes, no, or conditions joined by " or ".
function may_be_na(rule,   k, p, i) {
  k = split(rule, p, / or /)
  for (i = 1; i <= k; i++)
    if (p[i] == "yes" || (p[i] == "at light" && depth == "light") ||
        (p[i] == "below deep" && depth != "deep") || (p[i] == "no findings" && !nfindings) ||
        (p[i] == "first round" && !later_round)) return 1
  return 0
}
BEGIN {
  # Tables whose every row must be filled and which need at least one row; an n/a cell is fine, an empty one not.
  ntables = split("Rounds|Dimensions|Intent ledger|Assumption ledger|Readers|Parameters and channels|" \
    "Messages and side effects|Differences by class|Findings|Verdict inputs", tables, "|")
  for (i = 1; i <= ntables; i++) must_fill[tables[i]] = 1
}
FNR == 1 { file++; section = "" }
/^## / { section = trim(substr($0, 4)); row = 0; next }
!/^[|]/ { next }
{
  row++
  n = split($0, c, "|") - 2              # cells are c[2] .. c[n+1]
  if (row == 1) {
    cols = n; split("", col)
    for (i = 2; i <= n + 1; i++) { h = low(c[i]); sub(/ *\(.*/, "", h); col[h] = i }
    next
  }
  # The separator is the row under the header, and each of its cells has a dash.
  if (row == 2 && $0 ~ /^[|]( *:?-+:? *[|])+ *$/) next
  label = trim(c[2])
  # A dimension is keyed by its first word (D4), with any marks around it dropped (**D4**, D4:).
  split(label, w, " "); dim = w[1]; gsub(/[*`:]/, "", dim)

  if (file == 1) {                         # the template: the rules
    if (section == "Dimensions") { dims[++ndims] = dim; dim_rule[dim] = low(cell("n/a allowed")) }
    if (section == "Verdict inputs") { gates[++ngates] = label; gate_rule[label] = low(cell("n/a allowed")) }
    next
  }

  rows[section]++
  if (section in must_fill) {
    if (n != cols) reason(section ": row \"" label "\" has " n " cells, the header has " cols)
    # A cell of only dashes (hyphen, en or em dash) is a placeholder, not a value.
    for (i = 2; i <= n + 1; i++) if (trim(c[i]) ~ "^(-|\342\200\223|\342\200\224| )*$") { reason(section ": row \"" label "\" has an empty cell"); break }
  }
  if (section == "Scope" && low(label) == "head sha") ledger_head = trim(c[3])
  if (section == "Scope" && low(label) ~ /^depth/ && match(low(c[3]), /^(light|standard|deep)/))
    depth = substr(low(c[3]), 1, RLENGTH)
  # Rows may be grouped by unit, so a dimension can have several rows; an n/a on any of them counts.
  if (section == "Dimensions") {
    s = low(cell("status")); dim_seen[dim] = 1
    if (s == "n/a") dim_na[dim] = 1
    if (s != "pass" && s != "finding" && s != "n/a") reason("Dimensions: " label " is \"" s "\"")
  }
  # n/a is only for a no-intent row, one whose promised behaviour is itself n/a.
  if (section == "Intent ledger") {
    s = low(c[n + 1])
    if (s != "done" && !(s == "n/a" && low(cell("promised behaviour")) ~ /^n\/a/)) reason("Intent ledger: row \"" label "\" is \"" s "\"")
  }
  # A later round: more than one row, a round past 1, or a previous reviewed head. The last row is this round.
  if (section == "Rounds") {
    if (rows[section] > 1 || low(label) != "1" || low(cell("previous reviewed sha")) !~ /^(n\/a|none)$/) later_round = 1
    round_head = trim(cell("head sha"))
  }
  if (section == "Findings" && low(label) != "none") {
    sev = low(cell("severity")); org = low(cell("origin")); st = low(cell("status"))
    if (sev !~ /^(blocker|major|minor|nit)$/) reason("Findings: " label " has severity \"" sev "\"")
    if (org !~ /^(introduced|pre-existing|claimed class)$/) reason("Findings: " label " has origin \"" org "\"")
    closed = st ~ /^rejected/ || st == "stale"
    if (st ~ /^fixed@/) {
      closed = 1
      if (!same_sha(substr(st, 7), head)) reason("Findings: " label " is " st ", not re-checked on head " head)
    } else if (!closed && st != "open") reason("Findings: " label " has status \"" st "\"")
    if (st !~ /^rejected/) nfindings++
    if (!closed && (sev == "blocker" || (sev == "major" && org != "pre-existing"))) {
      blocked = 1; reason("open " sev " " label " (" org ")")
    }
  }
  if (section == "Verdict inputs") gate_status[label] = low(cell("status"))
}
END {
  if (depth == "") reason("Scope: \"Depth and why\" must start with Light, Standard or Deep")
  for (i = 1; i <= ntables; i++) if (!rows[tables[i]]) reason(tables[i] ": no rows (write one n/a row with the reason)")
  for (i = 1; i <= ndims; i++) {
    d = dims[i]
    if (!(d in dim_seen)) reason("Dimensions: " d " is missing")
    else if (dim_na[d] && !may_be_na(dim_rule[d])) reason("Dimensions: " d " can'\''t be n/a here (n/a allowed: " dim_rule[d] ")")
  }
  for (d in dim_seen) if (!(d in dim_rule)) reason("Dimensions: \"" d "\" is not a dimension in the template")
  for (i = 1; i <= ngates; i++) {
    g = gates[i]
    if (!(g in gate_status)) { reason("Verdict inputs: gate \"" g "\" is missing"); continue }
    s = gate_status[g]
    if (s != "pass" && !(s == "n/a" && may_be_na(gate_rule[g]))) reason("gate " g " is \"" s "\"")
  }
  if (!same_sha(ledger_head, head)) reason("ledger head \"" ledger_head "\" is not the current head " head)
  if (!same_sha(round_head, head)) reason("Rounds: the last round head \"" round_head "\" is not the current head " head)
  if (blocked) { print "DO NOT MERGE" reasons; exit 2 }
  if (reasons != "") { print "NOT YET" reasons; exit 1 }
  print "MERGE"; exit 0
}' "$tpl" -
