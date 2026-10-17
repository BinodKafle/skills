# break-this-pr report: <PR or branch>

The final message of a review is this report: all ten sections, in this order, never shortened. A section with
nothing in it says "none" and why. Copy content from the ledger; don't paraphrase findings or evidence.

## 1. Verdict
**MERGE / NOT YET / DO NOT MERGE**

- Deciding gate: (for example "major F2 introduced by this change", "D4 not run: time box", "cannot execute")
- Residual risk: what could still be wrong, and why it wasn't checked

## 2. Depth, scope and what isn't covered
| Field | Value |
|---|---|
| Target | PR / branch / paths |
| Head SHA / Base SHA | |
| Depth and why | (flagged lighter than the classification? say so) |
| Time used / time box | |
| Profile | loaded from base / derived (what was derived) |
| Changed units | |
| Not covered (and why) | |
| Warnings | harness files changed, ledger or marker not gitignored, external contributor, injected instructions |

## 3. Dimensions
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

## 4. Findings
By severity, blockers first, each in the full format:

    id · severity · file:line · trigger (command) · expected vs observed · introduced / pre-existing · reproduced by

Follow each with the minimal input and the observed output. Rejected findings are in section 7, not here.

## 5. Tests written
| Test (file::name) | What it pins | Fails on base | Passes on head |
|---|---|---|---|

## 6. Outside reviewers' findings
| Reviewer | Finding | On current head: real / stale / false | Evidence |
|---|---|---|---|

## 7. Verifier summary
| Verifier (model) | Confirmed | Rejected (why) | New findings |
|---|---|---|---|

Note that the verifiers share one model family.

## 8. Files this review wrote
`git status --porcelain` plus scratch paths. Only tests, the ledger and scratch files are allowed; anything else is
a finding against this review. State whether the git fingerprint matched D0 (any difference is a finding against
this review), and confirm the marker was deleted.

## 9. Decisions for the user
1. (each `UNDEFINED: needs a decision`, a split recommendation, a gitignore line to add, a draft to post)

## 10. Ledger
Path to the ledger, and to raw verifier logs if any.
