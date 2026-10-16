# Speed without dropping checks

Deep review is slow because of waiting and repeated work, not because of the checks themselves. Remove those costs;
never drop a check to save time.

- **Run independent work at the same time.** Run the lenses, the base and head sweeps, the fuzz runs and the
  environment variants (thread counts, locales) as parallel processes or background jobs, and keep reasoning while
  they run. Spread large corpora across cores.
- **Compute the base once.** The base tree doesn't change between rounds. Cache its outputs, keyed by the base SHA
  and the corpus hash, and reuse them every round; only the head is re-run.
- **Reuse only what's provably unchanged.** Re-run a heavy sweep whenever any file it exercises has changed.
  Compare content hashes of those files between rounds; if they're identical and the run is deterministic (fixed
  seeds, fixed environment), reuse the earlier result and say so. Never reuse results for uncommitted or changed
  files.
- **Cheap checks first, heavy sweeps to measure.** The assumption-ledger tests find most defects in seconds. Start
  the heavy sweeps in the background straight away; they measure how widespread a defect is.
- **Reuse CI, with conditions.** A CI run on the head used the head's own workflow and harness files, which the PR
  may have changed. Read a CI result instead of re-running the suite only when all of these hold:
  - the workflow files and the harness files (`safety.md` §3) are identical between base and head;
  - the result is fetched from the forge for the exact head SHA;
  - the run's URL is recorded in the ledger as the evidence.

  Re-run locally any test a finding or a pass rests on, and whatever CI doesn't cover.
- **Route by task.** A fast model handles mechanical steps (fetching comments, running commands, merging
  duplicates); the strongest model handles ledgers, reasoning and verification.
- **Keep the main context clean.** Raw tool output stays in files or subagents; the ledger gets summaries.
