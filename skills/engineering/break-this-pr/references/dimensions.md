# Dimensions D0–D10

A row passes only when its evidence is in the ledger.

## D0 Inputs
- **Evidence:** head and base SHAs; changed units (functions, types, constants, config keys, prompts, schemas,
  migrations); for each removed unit, what it did and where that lives now (or "dropped"); every outside comment
  marked real, stale or false on the current head.
- **Break it:** for each removal, run an input that depended on it on both trees.

## D1 Intent
- **Evidence:** one row per promised behaviour (ticket, description, commits): done / partial / not done, with
  scenario and result. Every behaviour difference from D2 maps to a row; one that doesn't is an undeclared change.
- **Break it:** run the user's real scenario through the real entry point (API, CLI, UI, upload), not just the unit.

## D2 Blast radius
- **Evidence:** a reader inventory with the search that found it (callers, siblings with the same rule, generated
  docs, prompts, API schemas, stored data and its consumers, scripts, CI); the differential (`oracles.md`); one
  end-to-end run.
- **Break it:**
  - mixed vintage: old data (rows, caches, files, checkpoints) read by new code, and new data by old consumers;
  - re-check every reader of a redefined field or rule under its new meaning;
  - a guard added to one sibling is owed by the others.

## D3 Root cause (bug fixes)
- **Evidence:** a reproduction on the base; a one-sentence cause written before reading the fix; whether the fix
  removes it or hides the symptom; the sibling search.
- **Break it:** symptom fixes look like a new guard, a broad try/except, a special case for the reported input, or a
  threshold tuned to the example. Run the bug's input class on every sibling with the same pattern.
- A test must fail on the base and pass on the head, for the bug and each covered sibling.

## D4 Break it
- **Assumption ledger,** one row per decision:

  | Decides | Reads (window / position) | Premise | Premise false | Holds but meaning false | 0 / 1 / 2 |
  |---|---|---|---|---|---|

  A decision reading a fixed position (first N, last N, a sample, a column) gets noise there: a footer, a
  preamble, a stray value inside the window.
- **Hostility:** wrong types, empty, null, NaN, ±infinity, negative zero, precision edges, huge values, Unicode.
  Data that becomes an identifier (column names, keys, paths, expressions) gets pattern characters, empty strings,
  duplicates and collisions.
- **Properties:** only declared exceptions for any input; parts add up to the whole; permutation, duplication,
  round-trip and head or tail noise leave the result unchanged.
- **Rendered outputs:** render with the real renderer, save an image, look at every visible element.
- **Corpus** (`corpus.md`) and **mutation** (`mutation.md`), with denominators.

## D5 Design
- **Evidence:** right layer and module per the architecture rules; coupling (private access across modules,
  duplicated rules); interface and data-model shape; backward compatibility; revert path.
- **Break it:** prototype a simpler design outside the repo and run the differential against the change. Report the
  difference count and the measured cost.

## D6 Simplicity
- **Evidence:** dead code, unused parameters or flags, guards that undo earlier work, single-use helpers, unneeded
  config; each optimization measured with and without.
- **Break it:** delete it in a prototype. If tests and differential don't change, it's dead.

## D7 Standards and supply chain
- **Evidence:** each API checked against the official docs for the repo's pinned version (deprecations, misuse,
  pitfalls); repo conventions; new lint, format and type diagnostics vs the base, each classified.
- **Supply chain,** per added or bumped dependency: lockfile diff, new transitive packages, install scripts,
  maintainer and licence, pinned version, and why it's needed.

## D8 Operational
- **Messages:** every user-facing message and log line is an output; assert each fact it states.
- **Errors:** no swallowed errors, or log-only or TODO handlers on a failure path.
- **Security:** inputs, injection, auth, secrets, sandbox boundaries.
- **Performance:** measured at realistic sizes, including any new full read or copy; a verdict on every new regex.
- **Environment:** same results across thread counts, locale, platform and file order; run at CI's settings.
- **Rollout:** migrations up and down, deploy steps, config defaults, flags, revert, effect on existing users and
  data.

## D9 Tests and words
- **Tests:** fail on the base, pass on the head, assert values (not shapes) and each arranged failure. Check the
  mutation survivors.
- **Ripple:** after a deletion or redefinition, search code, tests, comments, docs and the PR text for the old name
  or meaning.
- **Words:** every sentence the change adds is a claim; check it word by word against measured behaviour.

## D10 Independent verification
See SKILL.md §7. A verifier agreeing with your reasoning is not evidence.
