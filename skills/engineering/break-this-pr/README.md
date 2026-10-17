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
| **Safe on untrusted PRs** | Rules come from the base tree, harness files are diffed first, head code runs sandboxed without secrets or network. A hook allows only read-only git during a review, and a git fingerprint catches what it misses. The hook is a guard rail, not a security boundary; subagents follow it by instruction only. |
| **Budgeted** | Depth tiers with time boxes, a checkpoint before the expensive part, and a capped verdict when code can't run. |
| **Learns** | Escaped defects change the method, not a checklist. |

It doesn't fix code, and doesn't post to your forge unless you pass `--post` and approve the text. A Deep review
can take two hours; use it when correctness matters. Its verifiers share one model family.

## What it runs and sends

- **Git guard** (`scripts/guard-git.sh`): runs before each Bash command once the skill is used. Reads the hook
  input, runs only `find`, sends nothing.
- **The review:** runs your tests, linters, builds and the code under review locally (sandboxed if enabled). Writes
  tests, a ledger under `.claude/review/`, and scratch files outside the repo.
- **Forge CLI** (`gh`): fetches the PR and its comments; with `--post`, posts one approved comment.
- **Official docs** for libraries the change uses.

It reads no credentials; the forge CLI uses its own login.

## Install

Install the plugin (see the [repo README](../../../README.md)) and run `/binodkafle-skills:break-this-pr`, or copy
this folder to `~/.claude/skills/` and run `/break-this-pr`. It runs only when you invoke it.

**Before reviewing code you didn't write,** enable the Claude Code sandbox with `failIfUnavailable`
([references/safety.md](./references/safety.md)).

## Usage

| Argument | Meaning |
|---|---|
| `<target>` | PR number, ticket, branch or paths. Default: the current branch against its base. |
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
2. Gitignore the review files (the skill warns otherwise):

   ```gitignore
   .claude/review/ledgers/
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
| Sandbox errors | Fix the sandbox, or accept a NOT YET verdict. Don't disable it for untrusted PRs. |
| D0 can't fetch reviews | Check `gh auth status`. |
| No checkpoint in a headless run | Pass `--yes`. |

## Claude Code only

`argument-hint`, `disable-model-invocation` and frontmatter `hooks` aren't in the Agent Skills spec. Without the
git guard, don't run it on a working copy you care about. Tested with Claude Code 2.1.301. If the hook can't find
its script, it blocks every git command while a marker exists.
