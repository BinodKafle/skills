# Changelog

## 1.2.0 (2026-10-16)

- **break-this-pr:**
  - The git guard is now `scripts/guard-git.sh`, with tests. While a review runs it allows only read-only git (an
    allowlist), and blocks anything else, including aliases and `-c` overrides.
  - Fixed: the 1.1.1 guard let through `add`, `apply`, `tag`, `read-tree`, `checkout-index`, `notes`, `config`,
    `gc`, `stash branch`, `bisect`, `submodule update`, `sparse-checkout`, `symbolic-ref`, `update-index` and
    forced fetches. It could also be bypassed with `--git-dir <dir>` or a quoted `-C` path.
  - Fixed: the guard could be silently off. The marker is now created at the repository root, and the guard finds
    it from a subfolder or when `CLAUDE_PROJECT_DIR` is unset. If the guard script is missing, git is blocked
    while a marker exists, instead of being allowed.
  - New git fingerprint: recorded at D0 and checked before the report, to catch changes the guard can't see (git
    through a variable or a script, or from a subagent).
  - CI results are reused only when the workflow and harness files are unchanged between base and head.
  - The README's `--post` row says it never posts from a background run or for an external-contributor PR.
  - The review-profile template no longer says `git merge-base` is blocked, and its examples are generic.
- Repo: `CLAUDE.md` moved to `.claude/CLAUDE.md`, so `claude plugin validate --strict` passes.
- `scripts/check.py` now also checks that every file beside SKILL.md is named in it, the invocation labels in
  both READMEs, drafts against the bucket READMEs, the changelog heading, and the version against the last `v*`
  tag (failing in CI when there is no tag). CI runs the guard tests on Linux and macOS, and
  `claude plugin validate . --strict`.

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
