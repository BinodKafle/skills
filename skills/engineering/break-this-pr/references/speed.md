# Speed without dropping checks

Cut waiting and repeated work; never drop a check that applies.

- **Skip only what can't apply.** Mark it `n/a` with the reason from the diff (SKILL.md §3). If you're unsure
  whether a check applies, run it.
- **Prepare during the checkpoint.** Extracts, the reader search and a smoke run of the base's tests start as
  background jobs before you ask (SKILL.md, Checkpoint).
- **Parallelize.** Run lenses, base and head sweeps, fuzz runs and environment variants as background jobs, and keep
  reasoning meanwhile.
- **Run each thing once.** Compute the base once per review. One base run of the PR's tests serves D3 and D9; one
  reader search serves D2 and D9's ripple check. Lenses own the reading; execute their leads, don't re-read.
- **Reuse only what's provably unchanged:** same content hashes for every file a sweep exercises, and a
  deterministic run. Say when you reuse. Never reuse for uncommitted files.
- **Cheap checks first.** Assumption-ledger tests find most defects in seconds; heavy sweeps, started in the
  background, measure how widespread they are.
- **Reuse CI only if** workflow and harness files (`safety.md` §3) are identical between base and head, the result
  is for the exact head SHA, and its URL is in the ledger. Still re-run locally any test a finding or pass rests on.
- **Route by task.** A fast model for mechanical steps; the strongest for ledgers, reasoning and verification.
- **Keep the main context clean.** Raw output stays in the scratch folder or subagents; the ledger gets summaries.
- **Write once.** The ledger's dimension table and findings are in report format; the report copies them.
