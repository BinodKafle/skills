# Working in this repo

Before every commit, run `python3 scripts/check.py`, plus `sh tests/break-this-pr/guard-git.test.sh` if you touched
the guard.

## Layout

- A skill is `skills/<bucket>/<name>/SKILL.md`; the folder name equals the frontmatter `name`.
- Buckets: `engineering/` (promoted) and `in-progress/` (drafts). Add a new bucket to `PROMOTED_BUCKETS` in
  `scripts/check.py`.
- Detail not needed on every run goes in `references/`, `templates/` or `scripts/` beside `SKILL.md`, which names
  each file and when to use it. Keep `SKILL.md` under 500 lines.
- Script tests go in `tests/<name>/`, so they don't ship.
- A skill's own `README.md` is for humans; the agent doesn't load it.

## Shipping

A promoted skill is in `plugin.json`'s `skills`, and is linked (to its `SKILL.md`) and labelled user- or
model-invoked in both the top-level and bucket READMEs. Drafts stay out of all three.

## Invocation

- **User-invoked:** `disable-model-invocation: true`, for anything expensive or side-effectful. The description is
  a one-line summary for humans.
- **Model-invoked:** omit it. The description says when to use the skill, since the model decides from it.

## Published skills are generic

No repo paths, PR numbers, team names or project-specific commands. The skill tells users how to set up
repo-specific config, such as a review profile.

## Releasing

- A change under a promoted bucket or `.claude-plugin/` bumps `version` in `plugin.json` (semver) in the same
  commit, with a matching `CHANGELOG.md` heading.
- The release workflow tags `v*` when a new version reaches `main`; `check.py` compares against that tag. Don't tag
  by hand.
- After touching a manifest, `claude plugin validate . --strict` must pass with no warnings. That's why this file
  is in `.claude/`.

## Style

No em-dashes. Plain words, short sentences; give a rule's reason when it isn't obvious.
