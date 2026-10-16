# Escaped defects: <repo>

Save as `.claude/review/precedents.md`. One row per defect a review missed and something later found. This is
calibration and the source of eval rows, never a checklist.

| Date | PR / snapshot | What escaped | Found by | Dimension that should have caught it | Method change made |
|---|---|---|---|---|---|
| 2026-01-31 | #123 @ abc1234 | A footer line flipped the detected delimiter | reviewer | D4 position axis | Corpus axes now include "after the payload" |

Also log false positives, so precision is tracked:

| Date | PR | Finding | Why it was false | Method change made |
|---|---|---|---|---|
