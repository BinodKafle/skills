# break-this-pr

Adversarial senior-engineer PR review for Claude Code. It doesn't comment on a diff; it tries to break it, and
gives a merge verdict only when every dimension has evidence.

## What it does

| | |
|---|---|
| **Zero trust** | PR text, comments, docstrings, test names and other reviews are claims to verify. |
| **Eleven dimensions** | Inputs, intent, blast radius, root cause, breaking it, design, simplicity, standards and supply chain, operations, tests and words, verification. |
| **Executes** | Value-level differential against the base, crossed corpora with ground truth, properties, mutation of changed lines. |
| **Precision** | A finding stands only if a fresh verifier reproduces it. Nits never block. |
| **Safe on untrusted PRs** | Rules come from the base tree, harness files are diffed first, and head code runs only in the sandbox, without secrets or network. A plugin hook allows only read-only git during a review, and a git fingerprint catches what it misses. The hook is a guard rail, not a security boundary. |
| **Budgeted** | Depth tiers with time boxes, a checkpoint before the expensive part, and a capped verdict when code can't run. |
| **Learns** | Escaped defects change the method, not a checklist. |

It doesn't fix code, and doesn't post to your forge unless you pass `--post` and approve the text. A Deep review
can take two hours; use it when correctness matters. Its verifiers share one model family.

## What it runs and sends

- **Git guard** (`scripts/guard-git.sh`): a plugin hook before each Bash and Monitor command, in every session and
  subagent. It does nothing unless a review marker exists, and sends nothing.
- **The review:** runs your tests, linters, builds and the code under review locally, only in the sandbox. In
  your repo it writes only the tests and a temporary marker; its ledger and scratch files go in
  `/tmp/claude-<uid>/break-this-pr/` and are kept for later rounds.
- **Forge CLI** (`gh`): fetches the PR and its comments; with `--post`, posts one approved comment.
- **Official docs** for libraries the change uses.

It reads no credentials; the forge CLI uses its own login.

## Install

Install the plugin (see the [repo README](../../../README.md)) and run `/binodkafle-skills:break-this-pr`, or copy
this folder to `~/.claude/skills/` and run `/break-this-pr`. It runs only when you invoke it.

**Before reviewing,** enable the Claude Code sandbox with the strict settings in
[references/safety.md](./references/safety.md). Without it, the review doesn't run the PR's code and caps the
verdict at NOT YET.

## Usage

| Argument | Meaning |
|---|---|
| `<target>` | PR number, branch or paths. Default: the current branch against its base. |
| `--depth light\|standard\|deep` | Override the depth. Lighter than the skill's choice caps the verdict at NOT YET. |
| `--background` | Run in a background subagent, no checkpoint. Follow with `/tasks`. |
| `--yes` | Skip the checkpoint. |
| `--post` | Draft a PR comment and post it only on your yes. Never from a background run or for an external contributor. |

```text
/binodkafle-skills:break-this-pr 1234
/binodkafle-skills:break-this-pr feature/csv-import --depth deep
/binodkafle-skills:break-this-pr 1234 --background --yes
```

A run creates the marker `.claude/review/.active` at the repo root (turning on the git guard), prints each phase,
stops at a checkpoint (proceed / lighter / stop), and ends with the full report from
[templates/report.md](./templates/report.md), then deletes the marker.

### Example report (shortened)

```markdown
## 1. Verdict
**DO NOT MERGE**
- Deciding gate: major F1, introduced by this change.
- Residual risk: D8 performance measured at 50k rows only; production files reach 2M.

## 4. Findings
F1 · major · src/parser.py:88 · `pytest tests/test_parser.py::test_bom_header -x` · expected
header "id", observed "id" preceded by a byte-order mark · introduced · reproduced by verifier (haiku)
```

## Repo setup (recommended)

1. Copy [templates/review-profile.md](./templates/review-profile.md) to `.claude/review-profile.md` and fill it in.
   Without it, the skill derives one from `CLAUDE.md`, `AGENTS.md`, CI and build files.
2. Gitignore the review marker (the skill warns otherwise):

   ```gitignore
   .claude/review/.active
   ```

3. Log escaped defects in `.claude/review/precedents.md` and `.claude/review/evals.md` (formats in `templates/`),
   and commit both.

## Troubleshooting

| Problem | Fix |
|---|---|
| Git is blocked but no review is running | Delete the marker the message names. It expires after 4 hours. |
| A command that doesn't change git state is blocked | The hook matches text, so `git reset` inside a string is blocked. Rephrase it. |
| An alias or unusual subcommand is blocked | Only the read-only git in `scripts/guard-git.sh` runs during a review. Use the plain command. |
| The report says it couldn't delete the marker | Auto mode can refuse the delete. Run `! rm <marker path>`. |
| Sandbox errors | Fix the sandbox, or accept a NOT YET verdict. Don't disable it. |
| D0 can't fetch reviews | Check `gh auth status`. |
| No checkpoint in a headless run | Pass `--yes`. |

## Claude Code only

`argument-hint`, `allowed-tools` and `disable-model-invocation` aren't in the Agent Skills spec. Needs Claude Code
2.1.295 or later (the hook fails closed with `onFailure`); tested with 2.1.312. The git guard ships with the
plugin: a folder copied into `~/.claude/skills/` has no guard, so don't run it there on a working copy you care
about.
