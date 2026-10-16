# Changelog

## 1.1.1 (2026-10-16)

- **break-this-pr:**
  - The 22 `if:` hook entries are now one hook that matches state-changing git in the command text. During a
    review the `if:` entries blocked commands they couldn't parse, such as `for` loops and `$(...)`, even with no
    git in them. They also missed `git -C <dir> ...` and git called by full path.
  - The guard now also covers merge, pull, cherry-pick, revert, am, rm, mv, update-ref and branch deletes and
    moves. Fetch and merge-base stay allowed.
  - Subagents (lenses, verifiers, a background review) are told in their prompt not to run state-changing git,
    because the skill's hooks don't run inside subagents. The README says so.
  - README fixes: when the checkpoint is skipped, what Light runs, the example report, and Claude Code-only fields.

## 1.1.0 (2026-10-16)

- **break-this-pr:**
  - Runs inline by default, so you can see each step. `--background` hands it to a background subagent and prints
    the full report when it's done.
  - New flags: `--depth`, `--background`, `--yes`, `--post`, with an argument hint.
  - The git-blocking hooks only act while a review marker (`.claude/review/.active`) exists and is less than 4
    hours old. Before this, running the skill inline would have blocked your own git work for the rest of the
    session.
  - Announces each phase, tracks one task per dimension, and stops at a checkpoint (proceed / lighter / stop)
    after D0 and triage.
  - Ends with the complete report from the new `templates/report.md` (ten sections), never a summary.
  - Warns at D0 when the ledger or the marker isn't gitignored.
  - `--post` drafts a PR comment and posts it only after you confirm.
- Plugin: `homepage` added.
- `scripts/check.py`: checks that files SKILL.md mentions exist, and that the version was bumped when `skills/`
  changed since the last tag.

## 1.0.0 (2026-10-16)

- **break-this-pr** (new): adversarial senior-engineer PR review.
  - Eleven review dimensions; zero-trust verification and an assumption ledger.
  - Value-level differential against the base, structural crossed corpora, mutation of the changed lines.
  - Independent verifiers; a severity-gated verdict.
  - Safety rules for untrusted PRs, and hooks that block state-changing git during a review.
  - A replay-eval loop that turns escaped defects into method changes.
