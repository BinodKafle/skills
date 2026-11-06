# Dimensions D0–D10

A row passes only when its evidence is in the ledger, or it's `n/a` with a reason (SKILL.md §3). Each dimension
runs on a unit at that unit's tier (SKILL.md §3): Verify gets the executed checks below, Check gets at least one,
Skim gets a read.

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
  - re-check every reader of a redefined field or rule under its new meaning. A function whose output gets
    finer, coarser or differently shaped is redefined, even with the same name and signature;
  - give each reader its role, because one output can be right for one role and wrong for another: shown to a
    person; a key for grouping, joining, pivoting or deduping (finer keys mean more groups and different
    aggregates); a row's identity (coarser labels merge rows); parsed by a program (its dialect, delimiters and
    quoting); read by a model (docstrings and generated docs that feed prompts). Run one input per role;
  - a guard added to one sibling is owed by the others;
  - new outputs (notes, log fields, message parameters): who reads each one and how. A list joined with `", "`
    and split again breaks on a name holding `", "`. A note emitted before its action succeeds is false when the
    action fails.

## D3 Root cause (bug fixes; otherwise n/a)
- **Evidence:** a reproduction on the base; a one-sentence cause written before reading the fix; whether the fix
  removes it or hides the symptom; the sibling search.
- **Break it:** symptom fixes look like a new guard, a broad try/except, a special case for the reported input, or a
  threshold tuned to the example. Run the bug's input class on every sibling with the same pattern. From each
member you find, vary every element of its trigger in turn (position, delimiter, quoting, count) to enumerate
the rest of the class.
- A test must fail on the base and pass on the head, for the bug and each covered sibling.

## D4 Break it
- **Assumption ledger,** one row per decision (each branch, condition, threshold and pattern alternative), in
  the ledger's table. A decision reading a fixed position (first N, last N, a sample, a column) gets noise there:
  a footer, a preamble, a stray value inside the window.
  - **Both directions.** Each decision gets an input where it acts and shouldn't, and one where it should act and
    misses. A rule that picks a level (a width, a precision, a granularity, a scope) gets one step coarser and
    one finer. An oracle that bounds one side only ("no less distinct than the base") is half an oracle: a fix
    for one direction often fails the other.
  - **Where it runs out.** State the change's goal as a property of the output (no live formula left; distinct
    values get distinct labels) and check it at the rule's last step, its fallback and its loop end, with two or
    more targets per input, adjacent and overlapping.
- **Hostility:** wrong types, empty, null, NaN, ±infinity, negative zero, precision edges, huge values, Unicode.
  Data that becomes an identifier (column names, keys, paths, expressions) gets pattern characters, empty strings,
  duplicates and collisions.
- **State and time:** time zones, DST changes, leap days, clock skew; ordering and duplicates; retries and
  idempotency; partial failure and rollback; pagination edges; concurrent writers; the permission matrix (each
  role against each action).
- **Properties:** only declared exceptions for any input; parts add up to the whole; permutation, duplication,
  round-trip and head or tail noise leave the result unchanged.
- **Transforms** (anything that rewrites, escapes, sanitizes or encodes): applying it twice changes nothing;
  the goal holds with several targets per input; every format embedded in the output stays valid (JSON inside a
  cell still parses); and the bytes the producer emits, including syntax it adds itself (quotes, delimiters,
  terminators), are read by every consumer dialect.
- **Rendered outputs** (when the change affects one): render with the real renderer, save an image, look at every
  visible element.
- **Deep only:** corpus (`corpus.md`) and mutation (`mutation.md`), with denominators.

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
- **Evidence:** each API the change starts using or uses differently, checked against the official docs for the
  repo's pinned version (deprecations, misuse, pitfalls); repo conventions; new lint, format and type diagnostics
  vs the base, each classified.
- **Supply chain** (n/a without a manifest or lockfile change), per added or bumped dependency: lockfile diff, new
  transitive packages, install scripts, maintainer and licence, pinned version, and why it's needed.

## D8 Operational
- **Messages:** every user-facing message and log line is an output; assert each fact it states.
- **Errors:** no swallowed errors, or log-only or TODO handlers on a failure path. A fallback that returns a
  default, `None` or the raw value is a degraded output: it is logged or reported to the user. A `try` wider than
  the call that can fail hides bugs in the rest.
- **Security:** inputs, injection, auth, secrets, sandbox boundaries.
- **Performance:** measured at realistic sizes, including any new full read or copy; a verdict on every new regex.
  Also the output volume (groups, columns, notes) at realistic sizes, against the base.
- **Environment** (when the change touches concurrency, locale, ordering or platform code): same results across
  thread counts, locale, platform and file order; run at CI's settings.
- **Rollout:** migrations up and down, deploy steps, config defaults, flags, revert, effect on existing users and
  data.

## D9 Tests and words
- **Test diff** (every depth): deleted or skipped tests, removed or loosened assertions, widened tolerances,
  changed expected values, new mocks over the code under test. Each is a finding unless the intent explains it.
- **Tests:** fail on the base, pass on the head, assert values (not shapes) and each arranged failure. Check the
  mutation survivors. A test whose inputs all share one scale or granularity can't catch a change
  between them.
- **Properties:** one that asserts only that a bad output is absent passes a function that garbles everything.
  It also needs its preservation half (the output equals the input except for the declared edits) and a
  negative control (the oracle triggers on unprotected output).
- **Exclusions:** every `assume`, skip, filter, excluded layout or "kept away from" note in the tests under review
  marks an untested region. Attack it directly.
- **Ripple:** after a deletion or redefinition, search code, tests, comments, docs and the PR text for the old name
  or meaning.
- **Words:** every sentence the change adds is a claim, in the PR text, docstrings, comments and documented
  exceptions; check it word by word against measured behaviour. Re-check the PR description every round: claims
  measured on an older head are stale.

## D10 Independent verification
See SKILL.md §7. A verifier agreeing with your reasoning is not evidence.
