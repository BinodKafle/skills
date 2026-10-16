# Mutation of the changed lines

Mutation answers one question: would the tests notice if the new code were wrong?

## Tooling
Prefer the ecosystem's mutation tool in diff-only mode: mutmut or cosmic-ray (Python), Stryker (JS/TS, C#, Scala),
PIT (Java/Kotlin), go-mutesting or gremlins (Go), cargo-mutants (Rust). Hand-written mutants are the fallback.

## Rules
- **Only the changed lines.** Skip lines no test covers (report them as uncovered instead), and skip logging,
  comments and pure formatting.
- **Never edit the real file.** Each mutant runs in its own temporary copy of the tree. Several can run in
  parallel.
- **Covering tests only, fail fast.** Run only the tests that cover the mutated line, and stop at the first failure:
  "killed" needs only one failing test. Use the runner flags from the review profile.
- **Caps:** at most 3 mutants per line and 60 per review. Above the cap, sample uniformly and state the sample.
- **Bound every run** with a time limit, and count failures over the full output, never a truncated tail.

## Mutation operators
Flip a comparison (`<` / `<=`, `==` / `!=`), negate a condition, drop a guard, off-by-one on a bound, swap `and` /
`or`, remove a set or list member, replace a constant (0, 1, an empty value), delete a call with side effects.

## Each survivor
A survivor is one of three things:
1. **A missing test.** Write it; it must fail on the mutant and pass on the head.
2. **Dead or redundant code.** Report it under D6.
3. **An equivalent mutant.** Show why (no input can tell them apart) and drop it.

Score survivors against ground truth (`oracles.md`), not against your own expectation.
