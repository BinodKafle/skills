# Working in this repo

Rules for adding or changing a skill. `python3 scripts/check.py` enforces the mechanical ones; run it, and
`sh tests/break-this-pr/guard-git.test.sh` when you touch the guard, before every commit.

## Layout

- Each skill is a folder `skills/<bucket>/<skill-name>/` containing `SKILL.md`. The folder name equals the
  frontmatter `name`.
- Buckets:
  - `engineering/` (promoted): daily code work;
  - `in-progress/`: drafts, not shipped.

  Add a new bucket only when a skill doesn't fit an existing one, and add it to `PROMOTED_BUCKETS` in
  `scripts/check.py`.
- Detail that isn't needed on every run goes in files beside `SKILL.md` (`references/`, `templates/`, and
  `scripts/` for code the skill runs), each named in `SKILL.md` with a line saying when to read or run it. Keep
  `SKILL.md` under 500 lines.
- Tests for a skill's scripts live in `tests/<skill-name>/`, outside the skill folder, so they don't ship.
- A skill may have a human-facing `README.md` in its folder (what it does, setup, cost). It isn't loaded by the
  agent.

## Shipping a skill

A skill in a promoted bucket must be:
- listed in `.claude-plugin/plugin.json`'s `skills` array;
- listed in the top-level `README.md` and in its bucket's `README.md`, with its name linked to its `SKILL.md`;
- labelled user-invoked or model-invoked in both READMEs.

Skills in `in-progress/` must not be in `plugin.json`, the top-level `README.md` or a promoted bucket's
`README.md`. They may be listed in `skills/in-progress/README.md`.

## Invocation

- **User-invoked:** set `disable-model-invocation: true`. Use it for anything expensive, side-effectful, or that
  should never fire on a casual request. The description is a one-line summary for a human browsing commands.
- **Model-invoked:** omit it. The description says when to use the skill, because the model reads it to decide.

## Published skills are generic

No repo paths, PR numbers, team names or project-specific commands in a published skill. Anything a specific repo
needs belongs in that repo (for example, its own review profile), and the skill tells the user how to set it up.

## Releasing

- Bump `version` in `.claude-plugin/plugin.json` for every change that ships (semver: breaking / feature / fix),
  in the same commit as the change. "Ships" means anything under a promoted bucket or `.claude-plugin/`.
- Add a `CHANGELOG.md` entry whose heading is the new version.
- `check.py` compares against the last `v*` tag. The release workflow creates that tag (and a GitHub release)
  when a new version reaches `main`; don't tag by hand.
- Run `claude plugin validate . --strict` after touching either manifest. It must pass with no warnings, which is
  why this file lives in `.claude/` and not at the plugin root.

## Style

- No em-dashes in prose; rewrite the sentence instead.
- Plain words, short sentences; a rule says why when the reason isn't obvious.
