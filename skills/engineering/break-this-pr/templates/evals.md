# Replay suite: <repo>

Save as `.claude/review/evals.md`. It measures whether the review still catches defects it once missed, without
raising false alarms. Run it whenever the skill changes.

## Rows
| # | PR | Snapshot SHA (before the fix) | Defect that must be reported | Expected dimension | Kind |
|---|---|---|---|---|---|
| 1 | #123 | abc1234 | Footer line flips the delimiter to `;` | D4 | escape |
| 2 | #130 | def5678 | (clean PR: no blocker or major expected) | n/a | control |

## Procedure
1. Extract the snapshot read-only (`git archive <sha>`) into a temp directory.
2. Overlay the **current** review profile (`.claude/review-profile.md`). Never copy the precedents or this file in:
   the run must not be told what to find.
3. In a fresh session, run the review on the extract with no hints. Repeat each row **3 times**.
4. Score each row:
   - **escape:** passes if the defect is reported in at least 2 of the 3 runs;
   - **control:** passes if no blocker or major is reported in at least 2 of the 3 runs.

## Metrics, recorded per skill version
| Version | Recall (escapes passed / escapes) | Precision (verifier-confirmed findings / all findings) | Controls passed | Median wall-clock per depth | Median tokens |
|---|---|---|---|---|---|

## Gate for a skill change
A skill change ships only if all of these hold:
- recall and precision are no lower than the previous version;
- every control passes;
- median cost is within +20% of the previous version.

Otherwise, revert it or change the method.
