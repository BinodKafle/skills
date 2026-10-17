# Mutation of the changed lines

Would the tests notice if the new code were wrong?

## Tooling
The ecosystem's tool in diff-only mode: mutmut or cosmic-ray (Python), Stryker (JS/TS, C#, Scala), PIT
(Java/Kotlin), go-mutesting or gremlins (Go), cargo-mutants (Rust). Else hand-written mutants.

## Rules
- Changed lines only. Report uncovered lines as uncovered; skip logging, comments and formatting.
- Never edit the real file: each mutant runs in its own temporary copy, in parallel if possible.
- Run only covering tests and stop at the first failure, with the profile's runner flags.
- Cap at 3 mutants per line and 60 per review; above that, sample uniformly and say so.
- Time-limit every run. Count failures over the full output, never a truncated tail.

## Operators
Flip a comparison (`<` / `<=`, `==` / `!=`), negate a condition, drop a guard, shift a bound by one, swap `and` /
`or`, remove a set or list member, replace a constant (0, 1, empty), delete a call with side effects.

## Each survivor is
1. **A missing test:** write it (fails on the mutant, passes on the head).
2. **Dead code:** report under D6.
3. **Equivalent:** show no input tells them apart, and drop it.

Judge survivors against ground truth (`oracles.md`), not your own expectation.
