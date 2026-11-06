# Review ledger: <PR or branch>

Every row is filled, or marked `n/a` or `not-run` with the reason. A table that doesn't apply gets one `n/a`
row saying why. `scripts/verdict-gate.sh` computes the verdict from this file, so keep the section names and the
D0 to D10 rows as they are, even on a large PR (group rows by unit inside each table). Escape a `|` inside a cell
as `\|`. The report copies the dimension table and findings as they are.

## Scope
| Field | Value |
|---|---|
| Head SHA | |
| Base SHA | |
| Depth and why | |
| Profile | loaded from base / derived (list what was derived) |
| Test command and environment that worked | |
| Outside reviews fetched | count, or "local branch, none" |
| Changed units | |
| Removals (unit → what it did → where it lives now) | |
| Not reviewed (and why) | |
| Harness files changed in head | none / list (each is a finding) |
| Review folder | |
| Marker (absolute path) | |

## Rounds
One row per round. Each file changed since the previous reviewed head is reviewed in full this round (SKILL.md §9).

| Round | Head SHA | Previous reviewed SHA | Files changed since (command → count) | Units changed this round, with tier |
|---|---|---|---|---|

## Risk map
| Unit | Intent row | Tier (Verify / Check / Skim) | Why | Promoted by | Checks run |
|---|---|---|---|---|---|

## Dimensions
| Dim | Status (pass / finding / n/a / not-run) | Evidence (command → result) | Reason (n/a or not-run) |
|---|---|---|---|
| D0 Inputs | | | |
| D1 Intent | | | |
| D2 Blast radius | | | |
| D3 Root cause | | | |
| D4 Break it | | | |
| D5 Design | | | |
| D6 Simplicity | | | |
| D7 Standards and supply chain | | | |
| D8 Operational | | | |
| D9 Tests and words | | | |
| D10 Verification | | | |

## Intent ledger
The gate reads the last column: any `partial` or `not done` gives NOT YET.

| # | Promised behaviour (source) | Scenario run | Result | Done / partial / not done |
|---|---|---|---|---|

Undeclared changes (differential differences with no row above):

## Assumption ledger
One row per decision (each branch, condition, threshold and pattern alternative), re-derived every round. Each
cell is an input you ran and its result. Method: `references/dimensions.md` D4.

| Decision (file:line) | Reads (window / position) | Premise | Premise false; premise holds but meaning is wrong | Acts where it shouldn't; misses where it should | 0 / 1 / 2+ targets | At its edges (last step, fallback, loop end) | Corpus triggers and just misses it | Test |
|---|---|---|---|---|---|---|---|---|

## Readers
Every reader of each changed function, rule or output, from a recorded search (one row per hit). Roles are
listed in `references/dimensions.md` D2; for a parser, name its dialect.

Search: `<command>` → <hit count>

| Changed unit or output | Reader (file:line) | Role | Input run | Result |
|---|---|---|---|---|

## Parameters and channels
Every parameter of the changed entry point, and every path data takes into the output (body, headers,
placeholders such as a null value, options that route around the changed code).

| Parameter or channel | Default | Off or alternate | Hostile (including the output format's own syntax) | Result, or "not crossed" (counts against the denominator) |
|---|---|---|---|---|

## Messages and side effects
Every note, log field, error and side effect the change adds or alters.

| Output | Each fact it states | Asserted value | Emitted only after the action succeeds | Who reads it and how they parse it |
|---|---|---|---|---|

## Corpus and differential
| Corpus | Axes crossed | Cells | Regressions | Improvements | Both wrong | Cannot produce (including decisions it can't trigger or just miss) |
|---|---|---|---|---|---|---|

## Differences by class
Every difference from the base and from the previous reviewed head, grouped by class. A count is never a
verdict: each class maps to an intent row or a fix in this round, or it is a finding.

| Compared with (base / previous head) | Class | Count | One example (input → output) | Intent row, fix, or finding id |
|---|---|---|---|---|

## Mutation
| Mutants (run / cap) | Killed | Survivors → test written / dead code / equivalent |
|---|---|---|

## Outside reviewers' findings
| Reviewer | Finding | On current head: real / stale / false | Evidence |
|---|---|---|---|

## Findings
Blockers first, each with its minimal input and observed output. The gate reads these lines: an open
blocker, or an open major marked `introduced`, gives DO NOT MERGE. Mark a pre-existing major in the class the
change claims to fix as `introduced`.

    id · severity · file:line · run | read · trigger (command) · expected vs observed · introduced / pre-existing · reproduced by

Status per finding, appended to its line: open (no mark) / fixed@SHA / rejected: why / stale.

## Verifier summary
| Verifier (model) | Confirmed | Rejected (why) | New findings |
|---|---|---|---|

## Git fingerprint
`fingerprint.sh` output at D0 and before the report, then each difference and whether this review's files explain
it.

```
D0:

Before the report:
```

## Verdict inputs
Status is pass or fail. Only the corpus, previous-head, finding-verifier and blind-adversary gates may be
n/a (no corpus, first round, no findings, below Deep). Anything else, not-run included, gives NOT YET.

- **Findings:** `fail` on any blocker, or a major introduced or in the class the change claims to fix.
- **D1 complete:** no intent row is partial or not done.
- **Every corpus current:** each generator triggers and just misses every decision in the assumption ledger.
- **Previous-head differential mapped:** every class in "Differences by class" maps to a fix or a finding.
- **No open decisions:** including any decided only in the PR text.
- **No verdict cap:** `fail` if the code couldn't execute, the depth was lowered (`--depth` or **lighter**), a
  review fetch failed, or an external PR ran outside the strict sandbox.

| Gate | Status | Evidence |
|---|---|---|
| Findings | | |
| D1 complete | | |
| Every corpus current | | |
| Previous-head differential mapped | | |
| D10 finding verifier | | |
| D10 blind adversary | | |
| No open decisions | | |
| Time box | | |
| No verdict cap | | |

## Verdict
The output of `verdict-gate.sh <this ledger> <head SHA from the forge>`, pasted as is, then the residual risk. Never
override it, and never attach a condition to a MERGE.

## Decisions for the user
1.
