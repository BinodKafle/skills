# Working in this repo

Rules for adding or changing a skill. `scripts/check.sh` enforces the mechanical ones; run it before every commit.

## Layout

- Each skill is a folder `skills/<bucket>/<skill-name>/` containing `SKILL.md`. The folder name equals the
  frontmatter `name`.
- Buckets:
  - `engineering/` (promoted): daily code work;
  - `in-progress/`: drafts, not shipped.

  Add a new bucket only when a skill doesn't fit an existing one, and add it to `PROMOTED_BUCKETS` in
  `scripts/check.sh`.
- Detail that isn't needed on every run goes in files beside `SKILL.md` (`references/`, `templates/`), referenced
  from `SKILL.md` with a line saying when to read each. Keep `SKILL.md` under 500 lines.
- A skill may have a human-facing `README.md` in its folder (what it does, setup, cost). It isn't loaded by the
  agent.

## Shipping a skill

A skill in a promoted bucket must be:
- listed in `.claude-plugin/plugin.json`'s `skills` array;
- listed in the top-level `README.md` and in its bucket's `README.md`, with its name linked to its `SKILL.md`;
- labelled user-invoked or model-invoked in both READMEs.

Skills in `in-progress/` must appear in none of these.

## Invocation

- **User-invoked:** set `disable-model-invocation: true`. Use it for anything expensive, side-effectful, or that
  should never fire on a casual request. The description is a one-line summary for a human browsing commands.
- **Model-invoked:** omit it. The description says when to use the skill, because the model reads it to decide.

## Published skills are generic

No repo paths, PR numbers, team names or project-specific commands in a published skill. Anything a specific repo
needs belongs in that repo (for example, its own review profile), and the skill tells the user how to set it up.

## Releasing

- Bump `version` in `.claude-plugin/plugin.json` for every change that ships (semver: breaking / feature / fix).
- Add an entry to `CHANGELOG.md`.
- Run `claude plugin validate .` after touching either manifest. Its one expected warning is that this
  `CLAUDE.md` isn't loaded for plugin users: it's for people editing the repo, not shipped context.

## Style

- No em-dashes in prose; rewrite the sentence instead.
- Plain words, short sentences; a rule says why when the reason isn't obvious.
