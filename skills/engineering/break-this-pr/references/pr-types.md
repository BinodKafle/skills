# PR types

Read the rows that match the PR when building the risk map (SKILL.md §3). A PR often matches several; use every
matching row. What the Verify column names is never below Verify; what the skim column names may be Skim, unless
something promotes it.

| Type | Verify (execute) | Safe to skim | Edge cases to always try |
|---|---|---|---|
| Bug fix | The fix and every sibling with the same pattern (D3) | Unrelated tidy-ups, once shown to be behaviour-free | The reported input, its whole input class, the boundary just past it |
| Feature | Each promised behaviour through the real entry point; anything touching a risk area | Wiring that only passes values through | Empty, one, many; first use with existing data; the feature off |
| Refactor, rename, move | Nothing, if the differential vs base shows no behaviour change. Any difference makes the unit Verify. | The moved code itself | Reflection, string lookups, serialized names, public exports, config keys that still use the old name |
| Dependency bump | Changelog between the versions; the APIs the repo calls; lockfile diff (D7) | Version strings in docs | Changed defaults, removed or deprecated APIs, new transitive packages, install scripts |
| Config or feature flag | New defaults and who gets them | Comments in config | Flag on, off and missing; old config files; per-environment overrides |
| Migration or schema | Up, down, and re-run on a copy of realistic data | None | Existing rows with nulls or old formats, large tables (locks, time), old code on new schema during deploy |
| CI or build | Harness-file diff first (safety.md); what now runs, skips or is cached | Cosmetic job names | Jobs that no longer run, secrets exposure, cache keys, pinned action versions |
| Frontend or UI | Render with the real renderer and look at it (D4); state transitions | Pure styling with no layout change | Empty, loading and error states; long text; narrow screens; keyboard and screen reader |
| API contract | Request and response shapes vs current clients | Doc strings | Missing and extra fields, old clients, error codes, pagination edges, versioning |
| Concurrency or async | Every shared write and await point | None | Two writers at once, retry after partial success, cancellation, timeouts, ordering |
| Infra as code | Plan or diff output, what gets replaced or destroyed | Tags and comments | Resource replacement, open network rules, IAM widening, state drift, region defaults |
| Test-only | The test diff (D9); that new tests fail on the base | Fixture formatting | Weakened assertions, tests that can't fail, mocks over the code under test |
| Docs-only | Every factual claim and command, run as written (D9) | Prose style | Commands that no longer exist, wrong defaults, stale flags |
| Revert | That the revert is complete and matches the original commit inverted | None | Data written by the reverted code while it was live; later commits that depended on it |
| Generated code | The generator change, if any; regenerate and diff | Regenerated output when the generator didn't change | Hand edits inside generated files, version of the generator |
| Prompt or LLM change | The output on real inputs, before and after, scored against a fixed rubric | Whitespace | Injection through user content, output format the parser expects, refusals, length limits |
