# Speed without dropping checks

Cut waiting and repeated work; never drop a check.

- **Parallelize.** Run lenses, base and head sweeps, fuzz runs and environment variants as background jobs, and keep
  reasoning meanwhile.
- **Compute the base once.** Cache its outputs by base SHA and corpus hash; later rounds re-run only the head.
- **Reuse only what's provably unchanged:** same content hashes for every file a sweep exercises, and a
  deterministic run. Say when you reuse. Never reuse for uncommitted files.
- **Cheap checks first.** Assumption-ledger tests find most defects in seconds; heavy sweeps, started in the
  background, measure how widespread they are.
- **Reuse CI only if** workflow and harness files (`safety.md` §3) are identical between base and head, the result
  is for the exact head SHA, and its URL is in the ledger. Still re-run locally any test a finding or pass rests on.
- **Route by task.** A fast model for mechanical steps; the strongest for ledgers, reasoning and verification.
- **Keep the main context clean.** Raw output stays in files or subagents; the ledger gets summaries.
