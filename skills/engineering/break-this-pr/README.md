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
| **Safe on untrusted PRs** | PR text is data, rules come from the base tree, harness files are diffed before anything runs, and head code runs sandboxed without secrets or network. State-changing git is blocked by hooks during the review. |
| **Budgeted** | Depth tiers with time boxes; a cannot-execute path caps the verdict instead of guessing; large PRs are reviewed per unit. |
| **Learns** | Escaped defects become precedents and replay-eval rows; the method changes, not a growing checklist. |

## What it doesn't do

- It doesn't fix code. Fixes happen in the main session and are then reviewed again.
- It doesn't post to your forge. You decide what to publish.
- It isn't cheap. A Deep review can take up to two hours of agent time. Use your forge's lightweight reviewer for
  routine PRs, and this one when correctness matters.
- Its verifiers share one model family. They reduce self-confirmation; they don't remove it.

## Install

Install the `binodkafle-skills` plugin (see the [repo README](../../../README.md)) and run
`/binodkafle-skills:break-this-pr <PR number | branch | paths>`. Or copy this folder to
`~/.claude/skills/break-this-pr/` and run `/break-this-pr`.

The skill never runs on its own (`disable-model-invocation`), and it runs in a forked context, so its tool output
stays out of your conversation.

**Before reviewing code you didn't write,** enable the Claude Code sandbox with `failIfUnavailable`. See
[references/safety.md](./references/safety.md).

## Set up a repo (optional but recommended)

1. Copy [templates/review-profile.md](./templates/review-profile.md) to `.claude/review-profile.md` in your repo, and fill in your commands,
   runner flags, result-changing environment settings and domain traps. Without a profile, the skill derives one
   from your `CLAUDE.md` / `AGENTS.md`, CI and build files, and says what it derived.
2. Add `.claude/review/ledgers/` to `.gitignore`. Review ledgers persist there between sessions.
3. When a defect escapes a review, log it in `.claude/review/precedents.md`, and add a replay row to
   `.claude/review/evals.md` (formats in `templates/`).

## Measuring it

`templates/evals.md` describes a replay suite built from your own past misses:
- each row is a snapshot before a known fix, replayed 3 times without hints;
- clean PRs act as controls;
- it tracks recall, precision and cost per skill version.

A skill change ships only if none of the three gets worse.

## Layout

```
break-this-pr/
├── SKILL.md            workflow, principles, verdict gates
├── references/         safety, dimensions, corpus, oracles, mutation, speed, severity
└── templates/          ledger, review profile, precedents, evals
```

