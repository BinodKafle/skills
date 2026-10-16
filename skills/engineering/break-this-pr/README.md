# break-this-pr

An adversarial, senior-engineer PR review skill for Claude Code. It doesn't comment on a diff; it tries to break
it:
- it verifies every claim by running something;
- it attacks every changed line with real-world edge-case data;
- it returns a merge verdict that is only issued when every review dimension has evidence behind it.

## What it does

| | |
|---|---|
| **Zero trust** | The PR description, comments, docstrings, test names and other reviewers' findings are claims to verify, not evidence. |
| **Eleven dimensions** | Inputs, intent, blast radius, root cause, breaking it, design, simplicity, standards and supply chain, operations, tests and words, independent verification. |
| **Executes** | Value-level differential against the base tree, structural crossed corpora with ground truth, properties, and mutation of changed lines. |
| **Precision** | A finding stands only if a fresh verifier re-runs its trigger and sees the same output. Severity gates the verdict; nits never block. |
| **Safe on untrusted PRs** | PR text is data, rules come from the base tree, harness files are diffed before anything runs, and head code runs sandboxed without secrets or network. While a review runs, a hook blocks state-changing git in your session; subagents are held to it by their instructions. |
| **Budgeted** | Depth tiers with time boxes, a checkpoint before the expensive part, a cannot-execute path that caps the verdict instead of guessing, and per-unit review for large PRs. |
| **Learns** | Escaped defects become precedents and replay-eval rows; the method changes, not a growing checklist. |

## What it doesn't do

- It doesn't fix code. Fixes happen in the main session and are then reviewed again.
- It doesn't post to your forge unless you pass `--post`, and then only after you've read and approved the text.
- It isn't cheap. A Deep review can take up to two hours of agent time. Use your forge's lightweight reviewer for
  routine PRs, and this one when correctness matters.
- Its verifiers share one model family. They reduce self-confirmation; they don't remove it.

## Install

Install the `binodkafle-skills` plugin (see the [repo README](../../../README.md)) and run
`/binodkafle-skills:break-this-pr <target> [flags]`. Or copy this folder to `~/.claude/skills/break-this-pr/` and
run `/break-this-pr`.

The skill never runs on its own (`disable-model-invocation`). It runs inline, so you see every step, unless you
pass `--background`.

**Before reviewing code you didn't write,** enable the Claude Code sandbox with `failIfUnavailable`. See
[references/safety.md](./references/safety.md).

## Usage

| Argument | Meaning |
|---|---|
| `<target>` | A PR number, ticket, branch or paths. Omit it to review the current branch against its base. |
| `--depth light\|standard\|deep` | Override the depth the skill picks. Lighter than it would pick caps the verdict at NOT YET. |
| `--background` | Run in a background subagent, with no checkpoint. Follow it with `/tasks`; the full report prints when it's done. Hooks don't run inside subagents, so the subagent is held back from state-changing git by its instructions only. |
| `--yes` | Skip the checkpoint (after D0 and triage; after D0 alone at Light). |
| `--post` | After the report, draft a PR comment, show it, and post it only if you say yes. |

```text
/binodkafle-skills:break-this-pr 1234
/binodkafle-skills:break-this-pr feature/csv-import --depth deep
/binodkafle-skills:break-this-pr 1234 --background --yes
/binodkafle-skills:break-this-pr src/parser.py tests/test_parser.py --depth light
/binodkafle-skills:break-this-pr 1234 --post
```

### What a run looks like

1. It creates `.claude/review/.active` (the marker that switches on the git-blocking hooks) and prints one line
   per phase. With the task tools enabled, each dimension is a task you can watch.
2. After D0 and triage (D0 alone at Light) it stops at a checkpoint with the depth, time box, plan and estimated cost, and asks
   proceed / lighter / stop. `--yes` and `--background` skip it.
3. It runs the rest of the dimensions its depth calls for, writing failing tests and the ledger as it goes.
4. Its final message is the full report from [templates/report.md](./templates/report.md), and it deletes the
   marker.

### Example report (anonymised, shortened here; real reports have every row and section)

```markdown
## 1. Verdict
**DO NOT MERGE**
- Deciding gate: major F1, introduced by this change.
- Residual risk: D8 performance measured at 50k rows only; production files reach 2M.

## 2. Depth, scope and what isn't covered
| Depth and why | Deep: changes CSV parsing |
| Not covered | The export path (unchanged, no readers of the new field) |

## 3. Dimensions
| D4 Break it | finding | crossed corpus, 3 axes of 4 values = 64 cells → 2 regressions | |
| D6 Simplicity | pass | no dead branches; flag has two readers (rg output) | |

## 4. Findings
F1 · major · src/parser.py:88 · `pytest tests/test_parser.py::test_bom_header -x` · expected
header "id", observed "id" preceded by a byte-order mark · introduced · reproduced by verifier (haiku)
```

## Set up a repo (optional but recommended)

1. Copy [templates/review-profile.md](./templates/review-profile.md) to `.claude/review-profile.md` in your repo,
   and fill in your commands, runner flags, result-changing environment settings and domain traps. Without a
   profile, the skill derives one from your `CLAUDE.md` / `AGENTS.md`, CI and build files, and says what it
   derived.
2. Add these to `.gitignore` (the skill warns if they're missing):

   ```gitignore
   .claude/review/ledgers/
   .claude/review/.active
   ```

3. When a defect escapes a review, log it in `.claude/review/precedents.md`, and add a replay row to
   `.claude/review/evals.md` (formats in `templates/`). Commit these two.

## Troubleshooting

| Problem | Fix |
|---|---|
| Git commands fail with "state-changing git is blocked while a review runs", but no review is running | A review stopped without cleaning up. Run `rm .claude/review/.active`. The marker also expires after 4 hours. |
| A command is blocked during a review although it doesn't change git state | The hook matches command text, so a command that mentions, say, `git reset` in a string is blocked too. Rephrase it, or wait for the review to end. |
| `--background` ran inline, or you can't see the agent | Background subagents depend on your Claude Code version. Check `/tasks`. The skill asks before falling back to inline. |
| Commands fail with a sandbox error | You enabled `failIfUnavailable` and the sandbox can't start. Fix the sandbox, or accept a review capped at NOT YET (cannot execute). Don't turn the sandbox off for untrusted PRs. |
| D0 fails to fetch reviews | The forge CLI (for GitHub, `gh`) is missing or not logged in. Run `gh auth status`. A failed fetch on a real PR blocks the verdict; a local branch has no reviews to fetch. |
| The checkpoint question doesn't appear in a headless run | Headless runs can't answer questions. Pass `--yes`. |

## Claude Code only

`argument-hint`, `disable-model-invocation` and the frontmatter `hooks` are Claude Code features, outside the Agent Skills spec. Other tools
may reject the frontmatter, or load the skill without the git-blocking hooks; in that case, don't run it on a
working copy you care about.

## Measuring it

`templates/evals.md` describes a replay suite built from your own past misses:
- each row is a snapshot before a known fix, replayed 3 times without hints;
- clean PRs act as controls;
- it tracks recall, precision and cost per skill version.

A skill change ships only if none of the three gets worse.

## Layout

```
break-this-pr/
├── SKILL.md            arguments, lifecycle, workflow, principles, verdict gates
├── references/         safety, dimensions, corpus, oracles, mutation, speed, severity
└── templates/          report, ledger, review profile, precedents, evals
```
