#!/bin/sh
# Tests verdict-gate.sh: a complete ledger gives MERGE, and each kind of gap gives NOT YET or DO NOT MERGE.
# Exits 1 on any failure.
set -u

HERE=$(cd "$(dirname "$0")" && pwd)
GATE="$HERE/../../skills/engineering/break-this-pr/scripts/verdict-gate.sh"
TEMPLATE="$HERE/../../skills/engineering/break-this-pr/templates/ledger.md"
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
failures=0
HEAD=4466eed49c885ed0a471393d84a3e18047d01eae

# A complete ledger, as a review that ran every gate would leave it. It leaves out the template's
# "n/a allowed" columns: the gate takes those rules from the template, never from the ledger.
ledger() {
  cat <<EOF
## Scope
| Field | Value |
|---|---|
| Head SHA | $HEAD |
| Depth and why | Deep: prep.py is Verify |

## Rounds
| Round | Head SHA | Previous reviewed SHA | Files changed since | Units |
|---|---|---|---|---|
| 2 | 4466eed | b01b69c | git diff --name-only → 4 | prep.py Verify |

## Dimensions
| Dim | Status | Evidence | Reason |
|---|---|---|---|
| D0 Inputs | pass | fetched 3 | n/a |
| D1 Intent | pass | 1 of 1 done | n/a |
| D2 Blast radius | pass | 4 readers | n/a |
| D3 Root cause | n/a | none | not a bug fix |
| D4 Break it | finding | F1 | n/a |
| D5 Design | pass | read | n/a |
| D6 Simplicity | pass | read | n/a |
| D7 Standards and supply chain | n/a | none | no manifest touched |
| D8 Operational | pass | messages asserted | n/a |
| D9 Tests and words | pass | test diff clean | n/a |
| D10 Verification | pass | 2 of 2 reproduced | n/a |

## Intent ledger
| # | Promised behaviour | Scenario run | Result | Done / partial / not done |
|---|---|---|---|---|
| 1 | escape formulas | prep.py on a.csv | no live formula | done |

## Assumption ledger
| Decision | Reads | Premise | Premise attacks | Both directions | 0 / 1 / 2+ | Edges | Corpus | Test |
|---|---|---|---|---|---|---|---|---|
| prep.py:10 | cell tail | leading = is a formula | ' = 1 → kept | =a → 'a; a=b → a=b | 0, 1, 2 cells | last cell 'x | fires, misses | t1 |

## Readers
| Unit | Reader | Role | Input | Result |
|---|---|---|---|---|
| labels() | box.py:5 | key | two hours on one day | one group |

## Parameters and channels
| Parameter | Default | Off | Hostile | Result |
|---|---|---|---|---|
| null_value | ok | ok | ok | ok |

## Messages and side effects
| Output | Fact | Asserted | After success | Reader |
|---|---|---|---|---|
| n/a | n/a | n/a | n/a | no message changed |

## Differences by class
| Compared with | Class | Count | Example | Maps to |
|---|---|---|---|---|
| base | prefix added before a call | 12 | a → 'a | intent 1 |

## Findings
| ID | Severity | File:line | Run / read | Trigger | Expected vs observed | Origin | Reproduced by | Status |
|---|---|---|---|---|---|---|---|---|
| F1 | minor | prep.py:12 | run | python t.py | note vs none | introduced | verifier | open |
| F2 | major | prep.py:30 | run | python stale_rejected.py | 'a vs a | introduced | verifier | fixed@4466eed |

## Verdict inputs
| Gate | Status | Evidence |
|---|---|---|
| Every corpus current | pass | decision list vs inventory |
| Previous-head differential mapped | pass | 1 class, mapped |
| D10 finding verifier | pass | 2 of 2 reproduced |
| D10 blind adversary | pass | 40 inputs, 0 mismatches |
| No open decisions | pass | none |
| Time box | pass | 70 of 120 min |
| No verdict cap | pass | ran in sandbox, full depth, fetch ok |
EOF
}

# expect <label> <exit code> <first line> <ledger file> [head]
expect() {
  out=$(sh "$GATE" "$4" "${5:-$HEAD}" 2>&1); code=$?
  first=$(printf '%s\n' "$out" | head -1)
  if [ "$code" != "$2" ] || [ "$first" != "$3" ]; then
    failures=$((failures + 1)); echo "FAIL $1: wanted $2 \"$3\", got $code:"; printf '%s\n' "$out" | sed 's/^/    /'
  fi
}

# case_ <label> <exit code> <first line> <sed script applied to the complete ledger> [head]
case_() {
  ledger | sed "$4" > "$WORK/ledger.md"
  expect "$1" "$2" "$3" "$WORK/ledger.md" "${5:-$HEAD}"
}

F1='/^| F1 /'
F2='/^| F2 /'

# Head
case_ "complete ledger" 0 "MERGE" ''
case_ "abbreviated head" 0 "MERGE" '' 4466eed
case_ "stale head" 1 "NOT YET" '' b01b69c43aaaaaaa
case_ "too short a head" 1 "NOT YET" '' 4466
case_ "backticked head SHA" 0 "MERGE" "s/^| Head SHA | $HEAD/| Head SHA | \`$HEAD\`/"

# Findings, read from the table's cells
case_ "open introduced major" 2 "DO NOT MERGE" "$F2"'s/fixed@4466eed/open/'
case_ "open blocker" 2 "DO NOT MERGE" "$F1"'s/minor/blocker/'
case_ "bold blocker" 2 "DO NOT MERGE" "$F1"'s/minor/**Blocker**/'
case_ "blocker beats everything" 2 "DO NOT MERGE" "$F1"'s/minor/blocker/; /^| Time box/s/pass/not-run/'
case_ "open major in the claimed class" 2 "DO NOT MERGE" "$F2"'s/introduced/claimed class/; '"$F2"'s/fixed@4466eed/open/'
case_ "open pre-existing major is a follow-up" 0 "MERGE" "$F2"'s/introduced/pre-existing/; '"$F2"'s/fixed@4466eed/open/'
case_ "words in a trigger don't close it" 2 "DO NOT MERGE" "$F1"'s/minor/blocker/; '"$F1"'s/python t.py/python stale_rejected_fixed@4466eed.py/'
case_ "rejected major" 0 "MERGE" "$F2"'s/fixed@4466eed/rejected: not reproduced/'
case_ "stale major" 0 "MERGE" "$F2"'s/fixed@4466eed/stale/'
case_ "fixed on an older head" 1 "NOT YET" "$F2"'s/fixed@4466eed/fixed@b01b69c/'
case_ "unknown severity" 1 "NOT YET" "$F1"'s/minor/high/'
case_ "unknown origin" 1 "NOT YET" "$F1"'s/introduced/new/'
case_ "unknown status" 1 "NOT YET" "$F1"'s/open |$/maybe |/'
case_ "no findings" 0 "MERGE" "$F1"'d; '"$F2"'s/.*/| none | n\/a | n\/a | n\/a | n\/a | n\/a | n\/a | n\/a | n\/a |/; /^| D10 finding/s/pass/n\/a/'
case_ "findings table has no rows" 1 "NOT YET" "$F1"'d; '"$F2"'d'

# Intent, read from the table's last column
case_ "partial intent row" 1 "NOT YET" '/^| 1 | escape/s/done |$/partial |/'
case_ "partial intent row with a note" 1 "NOT YET" '/^| 1 | escape/s/done |$/partial (2 of 3) |/'
case_ "intent row not-run" 1 "NOT YET" '/^| 1 | escape/s/done |$/not-run |/'
case_ "intent ledger has no rows" 1 "NOT YET" '/^| 1 | escape/d'
case_ "promised behaviour marked n/a" 1 "NOT YET" '/^| 1 | escape/s/done |$/n\/a |/'
case_ "no-intent row" 0 "MERGE" 's/^| 1 | escape.*/| 1 | n\/a: PR states no behaviour | n\/a | n\/a | n\/a |/'

# Dimensions, with n/a rules from the template
case_ "dimension not run" 1 "NOT YET" '/^| D4 Break it/s/finding/not-run/'
case_ "dimension row deleted" 1 "NOT YET" '/^| D4 Break it/d'
case_ "D1 can't be n/a" 1 "NOT YET" '/^| D1 Intent/s/pass/n\/a/'
case_ "D9 can't be n/a" 1 "NOT YET" '/^| D9 Tests/s/pass/n\/a/'
case_ "D2 can't be n/a at Standard" 1 "NOT YET" '/^| Depth and why/s/Deep/Standard/; /^| D2 Blast/s/pass/n\/a/'
case_ "Light skips D2 and D10" 0 "MERGE" '/^| Depth and why/s/Deep/Light/; /^| D2 Blast/s/pass/n\/a/; /^| D10 Verif/s/pass/n\/a/; /^| D10 /s/pass/n\/a/'
case_ "D9 can't be n/a at Light" 1 "NOT YET" '/^| Depth and why/s/Deep/Light/; /^| D9 Tests/s/pass/n\/a/'
case_ "D0 can't be n/a at Light" 1 "NOT YET" '/^| Depth and why/s/Deep/Light/; /^| D0 Inputs/s/pass/n\/a/'
# Rows grouped by unit: an n/a on any row counts, not just the last one.
case_ "n/a unit row before a pass row" 1 "NOT YET" 's/^| D1 Intent .*/| D1 Intent (unit A) | n\/a | none | skipped |\
&/'
case_ "n/a unit row with a colon label" 1 "NOT YET" 's/^| D1 Intent .*/| D1: Intent (unit A) | n\/a | none | skipped |\
&/'
case_ "n/a unit row with a bold label" 1 "NOT YET" 's/^| D1 Intent .*/| **D1** Intent (unit A) | n\/a | none | skipped |\
&/'
case_ "unknown dimension row" 1 "NOT YET" 's/^| D1 Intent .*/&\
| D11 Extra | pass | x | n\/a |/'
case_ "bold dimension label" 0 "MERGE" 's/^| D1 Intent /| **D1** Intent /'
case_ "grouped pass rows" 0 "MERGE" 's/^| D1 Intent .*/| D1 Intent (unit A) | pass | 1 of 1 done | n\/a |\
&/'

# Depth
case_ "depth row deleted" 1 "NOT YET" '/^| Depth and why/d; /^| D10 blind/s/pass/n\/a/'
case_ "depth not named first" 1 "NOT YET" '/^| Depth and why/s/Deep: prep.py is Verify/Verify unit, so Deep/'
case_ "blind adversary can't be n/a at Deep" 1 "NOT YET" '/^| D10 blind/s/pass/n\/a/'
case_ "blind adversary n/a at Standard" 0 "MERGE" '/^| Depth and why/s/Deep/Standard/; /^| D10 blind/s/pass/n\/a/'

# Gates
case_ "finding verifier can't be n/a with open findings" 1 "NOT YET" '/^| D10 finding/s/pass/n\/a/'
case_ "first round has no previous head" 0 "MERGE" 's/^| 2 | 4466eed | b01b69c/| 1 | 4466eed | n\/a/; /^| Previous-head/s/pass/n\/a/'
case_ "later round can't skip the differential" 1 "NOT YET" '/^| Previous-head/s/pass/n\/a/'
case_ "round 1 label with a previous head isn't a first round" 1 "NOT YET" 's/^| 2 | 4466eed/| 1 | 4466eed/; /^| Previous-head/s/pass/n\/a/'
case_ "two rows labelled round 1 aren't a first round" 1 "NOT YET" 's/^| 2 | 4466eed | b01b69c/| 1 | b01b69c | n\/a | x | y |\
| 1 | 4466eed | n\/a/; /^| Previous-head/s/pass/n\/a/'
case_ "corpus can't be n/a at Deep" 1 "NOT YET" '/^| Every corpus/s/pass/n\/a/'
case_ "corpus n/a at Standard" 0 "MERGE" '/^| Depth and why/s/Deep/Standard/; /^| D10 blind/s/pass/n\/a/; /^| Every corpus/s/pass/n\/a/'
case_ "last round is behind the head" 1 "NOT YET" 's/^| 2 | 4466eed/| 2 | b01b69c/'
case_ "open decision" 1 "NOT YET" '/^| No open decisions/s/pass/fail/'
case_ "verdict cap" 1 "NOT YET" '/^| No verdict cap/s/pass/fail/'
case_ "gate row deleted" 1 "NOT YET" '/^| Time box/d'
case_ "renamed gate counts as missing" 1 "NOT YET" 's/^| Time box/| Timebox/'
case_ "gate evidence empty" 1 "NOT YET" '/^| D10 finding/s/2 of 2 reproduced//'
case_ "status is case-insensitive" 0 "MERGE" '/^| Time box/s/pass/PASS/'
case_ "backticked status" 0 "MERGE" '/^| Time box/s/pass/`pass`/'
case_ "bold status" 0 "MERGE" '/^| Time box/s/pass/**pass**/'

# Tables and cells
case_ "empty reader cell" 1 "NOT YET" 's/two hours on one day//'
case_ "readers table has no rows" 1 "NOT YET" '/^| labels()/d'
case_ "differences table missing" 1 "NOT YET" '/^## Differences by class/,/^| base/d'
case_ "escaped pipe stays in its cell" 0 "MERGE" 's/two hours on one day/a \\| b/'
case_ "bare pipe breaks the row" 1 "NOT YET" 's/two hours on one day/a | b/'
case_ "dash placeholder row" 1 "NOT YET" 's/^| labels() .*/&\
| - | - | - | - | - |/'
# Dash placeholders, built from bytes so this file has no dash characters of its own.
for d in "$(printf '\342\200\224')" "$(printf '\342\200\223')"; do
  case_ "dash placeholder row ($d)" 1 "NOT YET" "s/^| labels() .*/&\\
| $d | $d | $d | $d | $d |/"
done
case_ "blank row" 1 "NOT YET" 's/^| labels() .*/&\
|  |  |  |  |  |/'
case_ "aligned separator" 0 "MERGE" 's/^| labels() .*/| :- | - | - | - | -: |\
&/; /^| Unit | Reader/{n;d;}'

expect "unfilled template" 1 "NOT YET" "$TEMPLATE"

ledger | sed '/^| Time box/d' > "$WORK/ledger.md"
sh "$GATE" "$WORK/ledger.md" "$HEAD" | grep -q 'gate "Time box" is missing' ||
  { failures=$((failures + 1)); echo "FAIL a deleted gate isn't reported as missing"; }

sh "$GATE" >/dev/null 2>&1; [ $? -eq 64 ] || { failures=$((failures + 1)); echo "FAIL usage: no arguments isn't 64"; }
sh "$GATE" "$WORK/missing.md" "$HEAD" >/dev/null 2>&1
[ $? -eq 64 ] || { failures=$((failures + 1)); echo "FAIL usage: unreadable ledger isn't 64"; }

echo "verdict-gate: $failures failed"
[ "$failures" -eq 0 ]
