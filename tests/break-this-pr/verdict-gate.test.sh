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

# A complete ledger, as a review that ran every gate would leave it.
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
| D1 Intent | pass | 3 of 3 done | n/a |
| D2 Blast radius | pass | 4 readers | n/a |
| D3 Root cause | n/a | none | not a bug fix |
| D4 Break it | finding | F1 | n/a |
| D5 Design | pass | read | n/a |
| D6 Simplicity | pass | read | n/a |
| D7 Standards and supply chain | n/a | none | no manifest touched |
| D8 Operational | pass | messages asserted | n/a |
| D9 Tests and words | pass | test diff clean | n/a |
| D10 Verification | pass | 1 of 1 reproduced | n/a |

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
    F1 · minor · prep.py:12 · run · python t.py · note vs none · introduced · verifier
    F2 · major · prep.py:30 · run · python u.py · 'a vs a · introduced · verifier · fixed@4466eed

## Verdict inputs
| Gate | Status | Evidence |
|---|---|---|
| Findings | pass | F1 is minor |
| D1 complete | pass | 3 of 3 done |
| Every corpus current | pass | decision list vs inventory |
| Previous-head differential mapped | pass | 1 class, mapped |
| D10 finding verifier | pass | 1 of 1 reproduced |
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

# case <label> <exit code> <first line> <sed script applied to the complete ledger> [head]
case_() {
  ledger | sed "$4" > "$WORK/ledger.md"
  expect "$1" "$2" "$3" "$WORK/ledger.md" "${5:-$HEAD}"
}

case_ "complete ledger" 0 "MERGE" ''
case_ "abbreviated head" 0 "MERGE" '' 4466eed
case_ "stale head" 1 "NOT YET" '' b01b69c43aaaaaaa
case_ "too short a head" 1 "NOT YET" '' 4466
case_ "findings fail beats everything" 2 "DO NOT MERGE" '/^| Findings/s/pass/fail/; /^| Time box/s/pass/not-run/'
case_ "blind adversary not run" 1 "NOT YET" '/^| D10 blind/s/pass/not-run/'
case_ "blind adversary n/a below Deep" 0 "MERGE" '/^| Depth and why/s/Deep/Standard/; /^| D10 blind/s/pass/n\/a/'
case_ "first round has no previous head" 0 "MERGE" '/^| Previous-head/s/pass/n\/a/'
case_ "findings can't be n/a" 1 "NOT YET" '/^| Findings/s/pass/n\/a/'
case_ "D1 partial" 1 "NOT YET" '/^| D1 complete/s/pass/fail/'
case_ "open decision" 1 "NOT YET" '/^| No open decisions/s/pass/fail/'
case_ "gate row deleted" 1 "NOT YET" '/^| Time box/d'
case_ "renamed gate counts as missing" 1 "NOT YET" 's/^| Time box/| Timebox/'
case_ "gate evidence empty" 1 "NOT YET" '/^| D10 finding/s/1 of 1 reproduced//'
case_ "dimension not run" 1 "NOT YET" '/^| D4 Break it/s/finding/not-run/'
case_ "empty reader cell" 1 "NOT YET" 's/two hours on one day//'
case_ "readers table has no rows" 1 "NOT YET" '/^| labels()/d'
case_ "differences table missing" 1 "NOT YET" '/^## Differences by class/,/^| base/d'
case_ "escaped pipe stays in its cell" 0 "MERGE" 's/two hours on one day/a \\| b/'
case_ "bare pipe breaks the row" 1 "NOT YET" 's/two hours on one day/a | b/'
case_ "status is case-insensitive" 0 "MERGE" '/^| Time box/s/pass/PASS/'
case_ "backticked status" 0 "MERGE" '/^| Time box/s/pass/`pass`/'
case_ "bold status" 0 "MERGE" '/^| Time box/s/pass/**pass**/'
case_ "backticked head SHA" 0 "MERGE" "s/^| Head SHA | $HEAD/| Head SHA | \`$HEAD\`/"
case_ "open introduced major beats a pass gate" 2 "DO NOT MERGE" 's/· major · prep.py:30 · \(.*\) · fixed@4466eed/· major · prep.py:30 · \1/'
case_ "open blocker beats a pass gate" 2 "DO NOT MERGE" 's/· minor · prep.py:12/· blocker · prep.py:12/'
case_ "pre-existing major is a follow-up" 0 "MERGE" 's/ · fixed@4466eed//; s/introduced · verifier$/pre-existing · verifier/'
case_ "rejected major doesn't block" 0 "MERGE" 's/fixed@4466eed/rejected: not reproduced/'
case_ "partial intent row beats a pass gate" 1 "NOT YET" '/^| 1 | escape/s/done |$/partial |/'
case_ "intent ledger has no rows" 1 "NOT YET" '/^| 1 | escape/d'
case_ "dimension row deleted" 1 "NOT YET" '/^| D4 Break it/d'
case_ "D1 can't be n/a" 1 "NOT YET" '/^| D1 Intent/s/pass/n\/a/'
case_ "D9 can't be n/a" 1 "NOT YET" '/^| D9 Tests/s/pass/n\/a/'
case_ "D9 n/a at Light depth" 0 "MERGE" '/^| Depth and why/s/Deep/Light/; /^| D9 Tests/s/pass/n\/a/; /^| D10 blind/s/pass/n\/a/'
case_ "blind adversary can't be n/a at Deep" 1 "NOT YET" '/^| D10 blind/s/pass/n\/a/'
case_ "verdict cap gate fails" 1 "NOT YET" '/^| No verdict cap/s/pass/fail/'

expect "unfilled template" 1 "NOT YET" "$TEMPLATE"

sh "$GATE" >/dev/null 2>&1; [ $? -eq 64 ] || { failures=$((failures + 1)); echo "FAIL usage: no arguments isn't 64"; }
sh "$GATE" "$WORK/missing.md" "$HEAD" >/dev/null 2>&1
[ $? -eq 64 ] || { failures=$((failures + 1)); echo "FAIL usage: unreadable ledger isn't 64"; }

echo "verdict-gate: $failures failed"
[ "$failures" -eq 0 ]
