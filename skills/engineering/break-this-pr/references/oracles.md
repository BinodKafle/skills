# Where expected values come from

Never from the code under test. Best first:

1. **Ground truth by construction** (`corpus.md`).
2. **The true base tree:** a read-only extract of the base commit on the same inputs. Never "the new code with one
   switch off", which hides every other change.
3. **The real engine** the output passes through (renderer, browser, database, library, service), never a stand-in.
4. **An independent implementation,** such as the standard library.
5. **Metamorphic relations:** input changes that must leave the output unchanged (reordering, duplication,
   round-trips, head or tail noise), or change it in a known way.

## Differential classification
Run base and head on the same inputs and compare every output value, not just shape or counts:

| Difference | Verdict |
|---|---|
| New exception where the base didn't raise | worse: crash |
| Fewer rows or results, no user-facing note | worse: silent loss |
| Fewer rows, with a note whose count matches the loss | acceptable; assert the note |
| A value changed with no change in shape | worse: silent mutation |
| Anything else | intentional and mapped to an intent row, or a finding |

Encode this as an exhaustive literal table in the test, so an undeclared difference fails and so does a declared one
that stops happening.

When versions disagree, decide from ground truth which is right; the base can be the wrong one.
