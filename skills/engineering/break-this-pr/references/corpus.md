# Building the test corpus

## Real data first
Run the repo's fixtures, samples and real domain exports on both trees first. Generated data adds axes; it never
replaces real files.

## Structural axes
Derive axes from the input's structure, not from past bugs or the PR's theme:

| Axis | Values to cross |
|---|---|
| Position | before the payload (preamble, title, comments), inside it (stray values, blank rows), after it (footers, totals, notes) |
| Field | first, middle, last, missing, extra |
| Layer | every encoding, format, quoting, escaping, line-ending and locale layer the input passes through |
| Size | empty, one, two, typical, large |
| Values | the domain's real value kinds (ids, amounts, dates, codes, free text, lists inside fields) |
| Vintage | data from before the change, and after |

Name each fixture after what it mimics (an ERP export, a spreadsheet save-as).

## Decision-driven axes
The structural axes say what inputs look like; these say which inputs reach the change. List every decision in
the assumption ledger. For each, generate inputs where it triggers, where it just misses, and inputs holding two
or more of its targets. Add as axes:
- **Neighbours:** for rows of fields, field k crossed with field k+1, with 0, 1 or 2 targets in each, so a
  trigger split across two fields is produced.
- **Parameters and channels:** every parameter of the entry point, and every path data takes into the output
  (body, headers, placeholders such as a null value, options that route around the changed code).
- **Readers:** every caller of a changed shared helper, one per reader role (`dimensions.md` D2).
- **Dialects:** the producer's output read by each consumer's dialect. Judge the emitted output, not the input
  values.

## Ground truth by construction
Generate each input with its correct answer, never from the code under test. Genuinely ambiguous inputs get crash
and consistency checks only, counted separately.

## Enumerate or sample
Up to about 10,000 cells, enumerate the cross product. Above that, sample stratified across every axis and state the
sample size and strata.

## Score against the base
Per cell, record pass or fail on base and head. Report regressions (each a finding), improvements, and cells failing
on both. Group every changed cell by class into the ledger's "Differences by class" table, with one example
each. A count is never a verdict: a class with no intent row or fix is a finding.

## Generator inventory
List what the generator cannot produce, including each decision it can't trigger or just miss. "No regressions
over N" covers only what it can; anything else is uncovered, not safe. Re-check this list every round (SKILL.md
§9): a generator built for an earlier version of the rule is stale.
