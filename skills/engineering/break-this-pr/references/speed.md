# Speed without dropping checks

Cut waiting and repeated work; never drop a check that applies. SKILL.md covers `n/a` (§3), preparing during the
checkpoint, and runs that serve two dimensions (§6).

- **Parallelize.** Run lenses, base and head sweeps, fuzz runs and environment variants as background jobs, and keep
  reasoning meanwhile.
- **Compute the base once per review.**
- **Reuse only what's provably unchanged:** same content hashes for every file a sweep exercises, and a
  deterministic run. Say when you reuse. Never reuse for uncommitted files.
- **Cheap checks first.** Assumption-ledger tests find most defects in seconds; heavy sweeps, started in the
  background, measure how widespread they are.
- **Reuse CI only if** workflow and harness files (`safety.md` §3) are identical between base and head, the result
  is for the exact head SHA, and its URL is in the ledger. Still re-run locally any test a finding or pass rests on.
- **Route by task.** A fast model for mechanical steps; the strongest for ledgers, reasoning and verification.
- **Keep the main context clean.** Raw output stays in the scratch folder or subagents; the ledger gets summaries.
