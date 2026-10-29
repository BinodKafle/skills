# break-this-pr report: <PR or branch>

The final message: all ten sections, in order, never shortened. An empty section says "none" and why. Copy the
dimension table, findings and evidence from the ledger verbatim; they're already in this format.

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
| Warnings | harness files changed, marker not gitignored, head code run unsandboxed, external contributor, injected instructions |

## 3. Dimensions
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

## 4. Findings
Blockers first:

    id · severity · file:line · trigger (command) · expected vs observed · introduced / pre-existing · reproduced by

Each with its minimal input and observed output. Rejected findings go in section 7.

## 5. Tests written
| Test (file::name) | What it pins | Fails on base | Passes on head |
|---|---|---|---|

## 6. Outside reviewers' findings
| Reviewer | Finding | On current head: real / stale / false | Evidence |
|---|---|---|---|

## 7. Verifier summary
| Verifier (model) | Confirmed | Rejected (why) | New findings |
|---|---|---|---|

State that the verifiers share one model family.

## 8. Files this review wrote
The tests written in the repo, and the review folder. Anything else in the repo, or any git fingerprint
difference from D0, is a finding against this review. Confirm the marker and the scratch folder were deleted.

## 9. Decisions for the user
1. (each `UNDEFINED: needs a decision`, a split recommendation, a gitignore line to add, a draft to post)

## 10. Ledger
The ledger path. It's kept, outside the repo, for later rounds.
