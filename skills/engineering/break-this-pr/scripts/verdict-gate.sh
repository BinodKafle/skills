#!/bin/sh
# Computes the verdict from a review ledger, so a skipped gate can't be argued past.
# Usage: verdict-gate.sh <ledger.md> <current head SHA>
# Prints the verdict, then one line per reason. Exit 0 MERGE, 1 NOT YET, 2 DO NOT MERGE, 64 usage.
# The tables, Scope fields, dimensions and gates, and when each may be n/a, are read from templates/ledger.md, so
# they're defined once and a review can't loosen them by editing its own copy.
tpl="$(dirname "$0")/../templates/ledger.md"
[ $# -eq 2 ] && [ -r "$1" ] && [ -r "$tpl" ] || { echo "usage: verdict-gate.sh <ledger.md> <current head SHA>" >&2; exit 64; }

# \| inside a cell is an escaped pipe, not a column break. The template is read first, then the ledger.
sed 's/\\|/<PIPE>/g' "$1" | awk -v head="$2" '
# Markdown emphasis and code marks around a value are ignored.
function trim(s) { gsub(/^[ \t`*]+|[ \t`*\r]+$/, "", s); return s }
function low(s) { return tolower(trim(s)) }
function reason(r) { reasons = reasons "\n- " r }
# The cell under a header, by the header text before any "(...)".
function cell(name) { return (name in col) ? cells[col[name]] : "" }
# Either SHA may be abbreviated: 7+ characters, and one starts with the other.
function same_sha(a, b) { a = tolower(a); b = tolower(b)
  return length(a) >= 7 && length(b) >= 7 && (index(a, b) == 1 || index(b, a) == 1) }
# An "n/a allowed" rule: yes, no, or conditions joined by " or ".
function may_be_na(rule,   nparts, parts, i) {
  nparts = split(rule, parts, / or /)
  for (i = 1; i <= nparts; i++)
    if (parts[i] == "yes" || (parts[i] == "at light" && depth == "light") ||
        (parts[i] == "below deep" && depth != "deep") || (parts[i] == "no findings" && !nfindings) ||
        (parts[i] == "first round" && !later_round)) return 1
  return 0
}
# A misspelled condition would silently mean "not allowed", so the template is checked too.
function check_rule(name, rule,   nparts, parts, i) {
  nparts = split(rule, parts, / or /)
  for (i = 1; i <= nparts; i++)
    if (parts[i] !~ /^(yes|no|at light|below deep|no findings|first round)$/)
      reason("template: " name " has an unknown n/a rule \"" parts[i] "\"")
}
FNR == 1 { file++; section = "" }
/^## / { section = trim(substr($0, 4)); row = 0; next }
!/^[|]/ { next }
{
  row++
  ncells = split($0, cells, "|") - 2     # cells are cells[2] .. cells[ncells+1]
  if (row == 1) {
    header_cells = ncells; split("", col)
    for (i = 2; i <= ncells + 1; i++) { h = low(cells[i]); sub(/ *\(.*/, "", h); col[h] = i }
    # Every table in the template must be in the ledger, with at least one filled row.
    if (file == 1 && !(section in must_fill)) { must_fill[section] = 1; tables[++ntables] = section }
    next
  }
  # The separator is the row under the header, and each of its cells has a dash.
  if (row == 2 && $0 ~ /^[|]( *:?-+:? *[|])+ *$/) next
  label = trim(cells[2])
  # A dimension is keyed by its first word (D4), with any marks around it dropped (**D4**, D4:).
  split(label, words, " "); dim = words[1]; gsub(/[*`:]/, "", dim)

  if (file == 1) {                         # the template: the rules
    if (section == "Scope") { fields[++nfields] = low(label); hint[low(label)] = trim(cell("value")) }
    if (section == "Dimensions") {
      dims[++ndims] = dim; dim_rule[dim] = low(cell("n/a allowed")); check_rule(dim, dim_rule[dim])
    }
    if (section == "Verdict inputs") {
      gates[++ngates] = label; gate_rule[label] = low(cell("n/a allowed")); check_rule(label, gate_rule[label])
    }
    next
  }

  rows[section]++
  if (section in must_fill) {
    if (ncells != header_cells) reason(section ": row \"" label "\" has " ncells " cells, the header has " header_cells)
    # A cell of only dashes (hyphen, en or em dash) is a placeholder, not a value.
    for (i = 2; i <= ncells + 1; i++) if (trim(cells[i]) ~ "^(-|\342\200\223|\342\200\224| )*$") {
      reason(section ": row \"" label "\" has an empty cell"); break
    }
    # not-run caps the verdict wherever it is written.
    for (i = 2; i <= ncells + 1; i++) if (low(cells[i]) ~ /^not-run/) {
      reason(section ": row \"" label "\" is not-run"); break
    }
  }
  if (section == "Scope") {
    field = low(label); value = trim(cell("value")); scope_seen[field] = 1
    if (value != "" && value == hint[field]) reason("Scope: \"" label "\" is still the template text")
    if (field == "head sha") ledger_head = value
    if (field ~ /^depth/ && match(tolower(value), /^(light|standard|deep)/)) depth = substr(tolower(value), 1, RLENGTH)
  }
  # Rows may be grouped by unit, so a dimension can have several rows; an n/a on any of them counts.
  if (section == "Dimensions") {
    status = low(cell("status")); dim_seen[dim] = 1
    if (status == "n/a") dim_na[dim] = 1
    if (status != "pass" && status != "finding" && status != "n/a") reason("Dimensions: " label " is \"" status "\"")
  }
  # n/a is only for a no-intent row, one whose promised behaviour is itself n/a.
  if (section == "Intent ledger") {
    intent_ids[low(label)] = 1
    status = low(cells[ncells + 1])
    if (status != "done" && !(status == "n/a" && low(cell("promised behaviour")) ~ /^n\/a/))
      reason("Intent ledger: row \"" label "\" is \"" status "\"")
  }
  # A later round: more than one row, a round past 1, or a previous reviewed head. The last row is this round.
  if (section == "Rounds") {
    if (rows[section] > 1 || low(label) != "1" || low(cell("previous reviewed sha")) !~ /^(n\/a|none)$/) later_round = 1
    round_head = trim(cell("head sha"))
  }
  # Each difference maps to intent rows or findings that exist ("intent 1, 2, finding F3"); a fix only answers
  # the previous head.
  if (section == "Differences by class") {
    target = low(cell("intent row, fix, or finding id"))
    if (target == "n/a") {
      if (low(cell("count")) !~ /^(0|n\/a)$/) reason("Differences by class: \"" label "\" has a count but maps to n/a")
    } else if (target ~ /^fix: *[^ ]/) {
      if (low(label) !~ /^previous/) reason("Differences by class: \"" label "\" maps to a fix; only a previous-head row can")
    } else if (target ~ /^(intent|finding) /) {
      nitems = split(target, items, ",")
      for (i = 1; i <= nitems; i++) {
        item = trim(items[i])
        if (item ~ /^intent /) { kind = "intent"; item = trim(substr(item, 8)) }
        else if (item ~ /^finding /) { kind = "finding"; item = trim(substr(item, 9)) }
        if (kind == "intent") wanted_intent[item] = label; else wanted_finding[item] = label
      }
    } else reason("Differences by class: \"" label "\" maps to \"" target "\", not intent <#>, finding <ID> or fix: <what>")
  }
  if (section == "Findings") {
    id = low(label)
    # A none row is skipped only when it says nothing else; otherwise it is read as a finding.
    if (id == "none") {
      empty_row = 1
      for (i = 3; i <= ncells + 1; i++) if (low(cells[i]) != "n/a") empty_row = 0
      if (empty_row) next
    }
    finding_ids[id] = 1
    severity = low(cell("severity")); origin = low(cell("origin")); status = low(cell("status"))
    if (severity !~ /^(blocker|major|minor|nit)$/) reason("Findings: " label " has severity \"" severity "\"")
    if (origin !~ /^(introduced|pre-existing|claimed class)$/) reason("Findings: " label " has origin \"" origin "\"")
    run = low(cell("run / read"))
    if (run != "run" && run != "read") reason("Findings: " label " has Run / read \"" run "\"")
    # Only an open finding blocks. An unrecognised status is a ledger error (NOT YET), not a defect.
    rejected = status ~ /^rejected: *[^ ]/
    if (status ~ /^fixed@/) {
      if (!same_sha(substr(status, 7), head)) reason("Findings: " label " is " status ", not re-checked on head " head)
    } else if (status ~ /^rejected/ && !rejected) reason("Findings: " label " is rejected without a reason (rejected: why)")
    else if (status != "open" && !rejected && status != "stale") reason("Findings: " label " has status \"" status "\"")
    if (!rejected) nfindings++
    # A read finding (the code couldn'\''t run) blocks only as a blocker a verifier confirmed; otherwise it caps.
    if (status == "open" && run == "read") {
      if (severity == "blocker" && low(cell("reproduced by")) ~ /verifier/) { blocked = 1; reason("open read blocker " label ", confirmed by a verifier") }
      else reason("Findings: open read " severity " " label " caps the verdict at NOT YET")
    } else if (status == "open" && (severity == "blocker" || (severity == "major" && origin != "pre-existing"))) {
      blocked = 1; reason("open " severity " " label " (" origin ")")
    }
  }
  if (section == "Verdict inputs") gate_status[label] = low(cell("status"))
}
END {
  for (i = 1; i <= nfields; i++) if (!(fields[i] in scope_seen)) reason("Scope: field \"" fields[i] "\" is missing")
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
    status = gate_status[g]
    if (status != "pass" && !(status == "n/a" && may_be_na(gate_rule[g]))) reason("gate " g " is \"" status "\"")
  }
  for (id in wanted_intent) if (!(id in intent_ids))
    reason("Differences by class: \"" wanted_intent[id] "\" maps to intent " id ", which isn'\''t an intent row")
  for (id in wanted_finding) if (!(id in finding_ids))
    reason("Differences by class: \"" wanted_finding[id] "\" maps to finding " id ", which isn'\''t a finding")
  if (!same_sha(ledger_head, head)) reason("ledger head \"" ledger_head "\" is not the current head " head)
  if (!same_sha(round_head, head)) reason("Rounds: the last round head \"" round_head "\" is not the current head " head)
  if (blocked) { print "DO NOT MERGE" reasons; exit 2 }
  if (reasons != "") { print "NOT YET" reasons; exit 1 }
  print "MERGE"; exit 0
}' "$tpl" -
