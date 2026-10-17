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

## Ground truth by construction
Generate each input with its correct answer, never from the code under test. Genuinely ambiguous inputs get crash
and consistency checks only, counted separately.

## Enumerate or sample
Up to about 10,000 cells, enumerate the cross product. Above that, sample stratified across every axis and state the
sample size and strata.

## Score against the base
Per cell, record pass or fail on base and head. Report regressions (each a finding), improvements, and cells failing
on both.

## Generator inventory
List what the generator cannot produce. "No regressions over N" covers only what it can; anything else is
uncovered, not safe.
