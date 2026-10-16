# Where expected values come from

Never from the code under test. Best first:

1. **Ground truth by construction:** inputs generated together with their correct answer (`corpus.md`).
2. **The true base tree:** a read-only extract of the base commit, run on the same inputs. Never "the new code with
   one switch turned off": that hides every other change.
3. **The real engine** the output goes through: the actual renderer or browser, database, library or service.
   Never a hand-written stand-in for it.
4. **An independent implementation:** the standard library or a reference implementation that computes the same
   thing differently.
5. **Metamorphic relations,** when none of the above exists: changes to the input that must not change the output
   (reordering, duplication, round-trips, noise at the head or tail), or must change it in a known way.

## Differential classification
Run the base and head on the same inputs and compare **every output value**, not only shape or counts. Classify
every difference:

| Difference | Verdict |
|---|---|
| New exception where the base didn't raise | worse: crash |
| Fewer rows or results, no user-facing note | worse: silent loss |
| Fewer rows, with a note whose count matches the loss | acceptable; assert the note |
| A value changed with no change in shape | worse: silent mutation |
| Anything else | intentional and mapped to an intent row, or a finding |

Keep the classification as an exhaustive literal table in the test. An undeclared difference fails, and a declared
difference that stops happening also fails.

## Scoring with ground truth
When a mutant survives, or two versions disagree, decide which one is right from the ground truth, not by assuming
the base is right. A difference can be an improvement.
