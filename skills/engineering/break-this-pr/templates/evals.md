# Replay suite: <repo>

Save as `.claude/review/evals.md`. Run on every skill change, to check the review still catches past misses
without false alarms.

## Rows
| # | PR | Snapshot SHA (before the fix) | Defect that must be reported | Expected dimension | Kind |
|---|---|---|---|---|---|
| 1 | #123 | abc1234 | Footer line flips the delimiter to `;` | D4 | escape |
| 2 | #130 | def5678 | (clean PR: no blocker or major expected) | n/a | control |

## Procedure
1. Extract the snapshot read-only (`git archive <sha>`) into a temp directory.
2. Overlay the current `.claude/review-profile.md`, never the precedents or this file.
3. In a fresh session, review the extract with no hints, **3 times** per row.
4. Score each row:
   - **escape:** the defect is reported in at least 2 of 3 runs;
   - **control:** no blocker or major in at least 2 of 3 runs.

## Metrics, recorded per skill version
| Version | Recall (escapes passed / escapes) | Precision (verifier-confirmed findings / all findings) | Controls passed | Median wall-clock per depth | Median tokens |
|---|---|---|---|---|---|

## Gate for a skill change
Ship only if recall and precision don't drop, every control passes, and median cost rises at most 20%.
