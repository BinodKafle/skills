# Review profile: <repo>

Save as `.claude/review-profile.md` in the repo. The review reads it from the **base** tree. Fill in what applies;
delete the rest. One example line is given under each heading.

## Commands
- Tests (targeted): `pytest path/to/test_file.py`
- Lint / format / type check: `make lint`, `make format-check`, `make typecheck`
- Full gate (CI only; don't run for a scoped review): `make test`

## Base branch and range
- Default base: `develop`
- How to get head and base: `gh pr view <N> --json headRefOid,baseRefOid`
- Restrictions: the base is always the PR's base ref, never a local branch that may be stale.

## Runner flags
- Serial, fail fast, selected tests: `pytest -n 0 -x -p no:cacheprovider <file>::<test>`
- Count failures: `grep -c '^FAILED' <full output file>`

## Settings that change results
- Thread count: CI runs with 2 workers; run result-sensitive tests with the library's thread variable at 1 and 2.
- Platform: image goldens drift on macOS; render them only in the pinned container.

## Test layout rules
- One test file per source module, at the mirrored path; extend it, never add a second.
- Warnings are errors; scope any suppression to one test.

## Secrets and environment for running code
- Test settings: copy `.env.example` with placeholder values; never load the real `.env`.

## Domain traps
- Data values become column names; the dataframe library expands `*` and `^…$` in name arguments.
- Stored metadata is extracted at upload; changing the extractor needs a re-extract runbook step.
