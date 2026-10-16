# Dimensions D0–D10

Each dimension has a question, the evidence that answers it, and how to break it. A row is passed only when its
evidence is in the ledger.

## D0 Inputs
- **Question:** what exactly changed, against what, and what have others already found?
- **Evidence:**
  - head and base SHAs;
  - the list of changed units (functions, types, constants, config keys, prompts, schemas, migrations);
  - a removal inventory (each deleted or replaced unit: what it did per branch, and where that behaviour now lives,
    or "dropped");
  - every outside comment, marked real, stale or false on the current head.
- **Break it:** for each removal, find an input whose output depended on the removed behaviour, and run it on both
  trees.

## D1 Intent
- **Question:** does the change do every promised thing, and nothing else?
- **Evidence:**
  - one intent row per promised behaviour (from the ticket, description and commits), each done / partial / not
    done, with the scenario and the result;
  - the reverse map: every behaviour difference from D2 is linked to a row.
- **Break it:**
  - run the user's real scenario through the real entry point (API, CLI, UI path, upload), not only the unit;
  - a difference with no row is an undeclared change.
- **Example:** "Fixes headers with yes/no words" maps to a row. Test it through the loader that users hit, with
  the file from the ticket.

## D2 Blast radius
- **Question:** what else reads what changed, and does it still work?
- **Evidence:**
  - reader inventory (search command and result count): callers, siblings with the same rule, generated
    docs/catalogs, prompts, API schemas, stored data and its consumers, scripts, CI;
  - the differential result (`oracles.md`);
  - one end-to-end run.
- **Break it:**
  - **mixed vintage:** data written before the change (rows, caches, saved files, checkpoints) read by the new code,
    and new data read by old consumers;
  - a field or rule the change redefines: re-check every reader under the new meaning;
  - a guard added to one sibling is owed by the others.

## D3 Root cause (bug fixes)
- **Question:** does the fix remove the cause, or hide the symptom?
- **Evidence:** a reproduction on the base, a one-sentence cause written before reading the fix, the judgement, and
  the sibling search.
- **Break it:**
  - symptom fixes look like a new guard, a broad try/except, a special case for the reported input, or a threshold
    tuned to the example;
  - search for the same pattern elsewhere and run the bug's input class there.
- A test must exist that fails on the base and passes on the head, for the bug and for each covered sibling.

## D4 Break it
- **Question:** what input makes the changed code give a wrong answer?
- **Evidence:** the assumption ledger, corpus results with their denominators, property results, the mutation
  score.
- **Assumption ledger row (one per decision):**

  | Decides | Reads (window / position) | Premise | Premise false | Holds but meaning false | 0 / 1 / 2 |
  |---|---|---|---|---|---|

  A decision that reads a fixed position (first N, last N, a sample, a column) is attacked with noise at that
  position: a footer for "last lines", a preamble for "first lines", a stray value inside the window.
- **Hostility:**
  - wrong types, empty, null, NaN, ±infinity, negative zero, precision edges, very large values, Unicode where data
    reaches the code;
  - data that becomes an identifier (column names, keys, paths, expression fragments) is tested as a hostile
    identifier: pattern characters, an empty string, duplicates, a name colliding with an existing one.
- **Properties:**
  - **exception envelope:** only the declared exception types are raised, for any input;
  - **conservation:** parts add up to the whole, and every class is covered;
  - **metamorphic:** permutation, duplication, round-trip, and noise at the head or tail of the input leave the
    result unchanged.
- **Rendered outputs:** produce them with the real renderer, save an image, and look at it. Compare every visible
  element, not only a metric.

## D5 Design
- **Question:** is this the right change in the right place?
- **Evidence:** the layer and module, with the architecture rule it follows; coupling (private access across
  modules, duplicated rules found by search); interface and data-model shape; backward compatibility; the revert
  path.
- **Break it:** for a suggested simpler design, prototype it outside the repo and run the differential against the
  current change. Report the difference count (0 unless the change is the point) and the measured cost.

## D6 Simplicity
- **Question:** what can be deleted?
- **Evidence:** dead code, unused parameters or flags, guards that undo earlier work, single-use helpers,
  unnecessary configuration; each optimization measured with and without (time, memory).
- **Break it:** delete it in a prototype and run the tests and the differential. If nothing changes, it's dead.

## D7 Standards and supply chain
- **Question:** does it use its tools the way their pinned versions document?
- **Evidence:**
  - for each library or API used: the version pinned in the repo, the official docs for that version, and any
    deprecation, misuse or documented pitfall;
  - repo conventions (profile, rules);
  - lint, format and type-check deltas vs the base: every new diagnostic classified.
- **Supply chain:** for every dependency added or bumped: the lockfile diff, new transitive packages,
  install-time scripts, maintainer and licence, a pinned version, and why it's needed.

## D8 Operational
- **Question:** what happens in production?
- **Evidence:**
  - **messages:** every user-facing message, log line and note is an output; assert each fact it states (counts,
    names, causes);
  - **errors:** no swallowed errors, log-only handlers or TODO handlers on a failure path;
  - **security:** user and file inputs, injection, auth, secrets, sandbox boundaries;
  - **performance:** measured at realistic sizes; the amplification factor of any new full read or copy; a verdict
    on every new regex;
  - **environment:** results identical across thread counts, locale, platform and file order; run at CI's settings;
  - **rollout:** migrations up and down, deploy and runbook steps, config defaults, feature flags, revert, and what
    happens to existing users and stored data.

## D9 Tests and words
- **Question:** do the tests prove the change, and are its words true?
- **Evidence:**
  - the PR's tests run on the base (expected to fail) and on the head (expected to pass);
  - values asserted, not just shapes;
  - each arranged failure asserted;
  - the mutation survivors (`mutation.md`).
- **Ripple:** after any deletion or redefinition, search code, tests, comments, docs and the PR description for the
  old name or meaning.
- **Words:** every sentence the change adds (description, docstrings, comments, messages) is a claim. Check it
  against measured behaviour, word by word.

## D10 Independent verification
See SKILL.md §7. A finding stands only on a reproduced command and output. A verifier agreeing with the reasoning
is not evidence.
