# Changelog

## 1.3.0 (2026-10-29)

- **break-this-pr:**
  - **Less waiting, same checks.** A dimension or check the diff can't affect is `n/a`, with the reason from the
    diff, and doesn't cap the verdict. The depth table says which parts of D4 run at Standard and which only at
    Deep. Lenses own the reading, and one base test run and one reader search each serve two dimensions.
  - **Preparation overlaps the checkpoint.** Extracts, the reader search and a smoke run of the base's tests start
    before the question.
  - **Only the tests land in your repo.** The ledger and scratch files go in
    `/tmp/claude-<uid>/break-this-pr/<repo>-<path hash>-<PR>/`, the same path with or without the sandbox, and
    are kept for the next round and for re-running the report's triggers. The ledger's gitignore check is gone.
  - **The guard covers subagents in plugin installs.** It's now also a plugin hook (`hooks/hooks.json`), and
    Claude Code runs plugin hooks inside subagents. Verified in a live session. Like the skill's hook, it fails
    closed (`onFailure: block`).
  - **The guard blocks only the reviewing session.** The marker holds its session id, and subagents share it, so
    other sessions and worktrees in the same repo keep their git.
  - **The guard blocks git flags that run a program:** `grep -O`, `--open-files-in-pager`, `--upload-pack`,
    `ls-remote -u` and `--exec`, including abbreviations git accepts (`--op=`, `--u=`). A command over 50 KB
    that mentions git is blocked, since checking it could outlast the hook's timeout.
  - **The git fingerprint is one script call** (`scripts/fingerprint.sh`), pre-allowed with `allowed-tools`. It
    now also catches changes to the staged state and to untracked files' contents, with one hash per path so a
    change is tied to its file.
  - **The sandbox settings are spelled out** (`strictAllowlist`, `allowUnsandboxedCommands: false`). Head code
    still runs only in the sandbox, for every author, and verifiers re-run it only once a subagent's commands
    are confirmed sandboxed.
  - The ledger's dimension table and findings are in report format, so the report copies them. The verdict waits
    for every verifier. Severity gating lives in one place. A ticket is intent input, not a target.

## 1.2.4 (2026-10-29)

- **break-this-pr:** the git guard no longer hangs. On macOS awk, a command with a string ending in `<` or `>`
  (`"->"`, `'</pre>'`) looped forever while a review marker existed, and each Bash call waited for the 10-minute
  hook timeout. In real reviews this was more than half the run time.
  - The guard skips commands that can't contain git.
  - The hook has a 10-second timeout and fails closed (`onFailure: block`), so a future hang costs seconds
    and never lets git through. Needs Claude Code 2.1.295 or later.
  - Guard tests kill a case after 5 seconds, so a hang fails the test and doesn't freeze it.

## 1.2.3 (2026-10-26)

- **break-this-pr:** the checkpoint labels the time box as a ceiling and gives a size-based time estimate.

## 1.2.2 (2026-10-26)

- **break-this-pr:**
  - D0 says how to fetch PR reviews and comments: one paginated call per endpoint, each saved to its own file, and
    the fetch counts as failed unless every call succeeds. A chained fetch could fail partway and go unnoticed.
  - Run read-only git one command per call. A denial from the project's permission rules is reported at the
    checkpoint, not rephrased around. A broad rule such as `Bash(git merge*)` also denies `git merge-base`.

## 1.2.1 (2026-10-17)

- Shorter docs, references, templates and comments. No rules changed; `SKILL.md` is untouched.
- **break-this-pr:** shorter guard block message.

## 1.2.0 (2026-10-16)

- **break-this-pr:**
  - The git guard is now `scripts/guard-git.sh`, with tests. While a review runs, it allows only read-only git
    from an allowlist. Anything else is blocked, including aliases, `-c` overrides and `GIT_*` variables.
  - The allowlist is strict about forms that write. `git config` must start with a read action. `--output` and
    `git archive -o` are blocked. `git fetch` takes only basic flags. `git remote` and `git reflog` allow only
    their read forms. A branch or tag name with display flags such as `--sort` is a create, not a listing.
  - The guard finds git in more places: after a backslash line continuation, after a leading redirection
    (`2>/dev/null git ...`), and after a wrapper with arguments (`xargs -n 1 git`, `nice -n 10 git`). It no
    longer skips quoted strings past a cap.
  - Fixed: the 1.1.1 guard let through `add`, `apply`, `tag`, `read-tree`, `checkout-index`, `notes`, `config`,
    `gc`, `stash branch`, `bisect`, `submodule update`, `sparse-checkout`, `symbolic-ref`, `update-index` and
    forced fetches. It could also be bypassed with `--git-dir <dir>` or a quoted `-C` path.
  - Fixed: the guard could be silently off. The marker is now created at the repository root (the superproject's
    root inside a submodule), and the review reuses the absolute path it printed. The guard looks for it in the
    project dir, the shell's cwd and every folder above them.
  - If the guard script is missing, the fallback blocks commands that mention git while a marker exists, instead
    of allowing them. The launcher also finds the script in a flat `skills/break-this-pr/` plugin layout.
  - The guard is faster: it runs no git, and with no marker it starts no `find`. Long commands are checked in
    linear time.
  - New git fingerprint, recorded at D0 and checked before the report. It catches changes the guard can't see,
    such as git through a variable or a script, or from a subagent. It covers the working tree, branches,
    stashes, worktrees and local config. It leaves out tags, which a plain fetch can add.
  - CI results are reused only when the workflow and harness files are unchanged between base and head.
  - The README's `--post` row says it never posts from a background run or for an external-contributor PR.
  - The review-profile template no longer says `git merge-base` is blocked, and its examples are generic.
- Repo: `CLAUDE.md` moved to `.claude/CLAUDE.md`, so `claude plugin validate --strict` passes.
- `scripts/check.py` checks more. Every file beside SKILL.md must be named in it. Both READMEs must label each
  skill, and drafts must stay out of the bucket READMEs. The changelog heading must match the version, and the
  version must be above the last `v*` tag (CI fails when there is no tag). It runs on Python 3.9.
- CI runs the guard tests on Linux and macOS, and `claude plugin validate . --strict`. The release workflow fails
  instead of publishing empty notes, can make the first release, and retries a failed release on the next push.

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
