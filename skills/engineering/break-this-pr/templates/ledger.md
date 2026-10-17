# Review ledger: <PR or branch>

Every row is filled, or marked `not-run` with the reason. A verdict without a complete ledger is invalid.

## Scope
| Field | Value |
|---|---|
| Head SHA | |
| Base SHA | |
| Depth and why | |
| Profile | loaded from base / derived (list what was derived) |
| Outside reviews fetched | count, or "local branch, none" |
| Changed units | |
| Removals (unit → what it did → where it lives now) | |
| Not reviewed (and why) | |
| Harness files changed in head | none / list (each is a finding) |

## Dimensions
| Dim | Status (pass / finding / not-run) | Evidence (command → result) | Not-run reason |
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
| # | Promised behaviour (source) | Scenario run | Result | Done / partial / not done |
|---|---|---|---|---|

Undeclared changes (differential differences with no row above):

## Assumption ledger
| # | Decision | Reads (window / position) | Premise | Input: premise false | Input: holds, meaning false | 0 / 1 / 2 | Test |
|---|---|---|---|---|---|---|---|

## Corpus and differential
| Corpus | Axes crossed | Cells | Regressions | Improvements | Both wrong | Cannot produce |
|---|---|---|---|---|---|---|

## Mutation
| Mutants (run / cap) | Killed | Survivors → test written / dead code / equivalent |
|---|---|---|

## Outside reviewers' findings
| Reviewer | Finding | On current head: real / stale / false | Evidence |
|---|---|---|---|

## Findings
`id · severity · file:line · trigger (command) · expected vs observed · introduced / pre-existing · reproduced by ·
status (open / fixed@SHA / rejected: why / stale)`

## Verifier summary
| Verifier (model) | Confirmed | Rejected (why) | New findings |
|---|---|---|---|

## Files this review wrote
`git status --porcelain` plus scratch paths.

## Marker
Absolute path:

## Git fingerprint
Output at D0 and before the report, then each difference and whether this review's files explain it.

```
D0:

Before the report:
```

## Verdict
MERGE / NOT YET / DO NOT MERGE. The deciding gate, and the residual risk.

## Decisions for the user
1.
